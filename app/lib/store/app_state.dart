// 全局状态 + 持久化。本机优先:不注册、不上传。
//
// 存储用 Hive CE:Web 端落在 IndexedDB(不受 localStorage 5 MB 限制),Android 端是应用私有目录里的文件。
//   - box `state`   :key 'state' 一份业务 JSON(不含图片),key 'settings' 设置
//   - box `images`  :图片 id → JPEG base64。图片单独存,改一条待办不用重写几 MB 的大 JSON
// 0.1 版的数据在 shared_preferences(localStorage)里,首次启动自动迁移。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cloud/sync_merge.dart';
import '../core/money.dart';
import '../models/models.dart';
import 'demo_data.dart';
import 'settings.dart';

/// 家庭同步的挂钩(实现在 cloud/family_sync.dart)。AppState 不认识 Firebase,只在保存和存取图片时通知它。
abstract class StateSync {
  /// 本机改了数据并保存了(内部自己合并多次调用)
  void onLocalSave();
  void onImagePut(String id, String b64);
  void onImageRemoved(String id);
}

class AppState extends ChangeNotifier {
  static const _legacyPrefsKey = 'school_sift_v1';
  static const stateBoxName = 'school_sift_state';
  static const imageBoxName = 'school_sift_images';

  String language = 'zh'; // zh / en
  List<Child> children = [];
  List<Member> members = [];
  List<Notice> notices = [];
  List<Event> events = [];
  List<Task> tasks = [];
  List<Grade> grades = [];
  List<StudyLog> logs = [];
  List<ReplyRecord> replies = []; // 「用英文回复」的历史,新的在前
  Settings settings = Settings();
  bool loaded = false;
  bool demoLoaded = false;

  /// 当前筛选的孩子('' = 全部)
  String filterChildId = '';

  Box<String>? _box;
  Box<String>? _images;
  /// 没有 Hive 时(widget 测试的 inMemory 模式)图片放这里
  final Map<String, String> _memImages = {};

  /// 开了家庭同步时不为空;应用云端改动时不回推
  StateSync? sync;
  bool _applyingRemote = false;
  bool get synced => sync != null;

  /// [hivePath] 只在测试里给(跳过 path_provider);[inMemory] 完全不碰 Hive(widget 测试用,FakeAsync 里做不了真实 IO)。
  Future<void> load({String? hivePath, bool inMemory = false}) async {
    if (inMemory) {
      loaded = true;
      notifyListeners();
      return;
    }
    try {
      if (hivePath != null) {
        Hive.init(hivePath);
      } else {
        await Hive.initFlutter();
      }
      _box = await Hive.openBox<String>(stateBoxName);
      _images = await Hive.openBox<String>(imageBoxName);
    } catch (e) {
      debugPrint('hive init failed: $e');
    }
    final raw = _box?.get('state');
    if (raw != null) {
      try {
        importJson(raw, notify: false, persist: false);
      } catch (e) {
        debugPrint('load failed: $e');
      }
    } else {
      await _migrateFromPrefs();
    }
    final s = _box?.get('settings');
    if (s != null) {
      try {
        settings = Settings.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {}
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _migrateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_legacyPrefsKey);
      if (raw == null) return;
      importJson(raw, notify: false); // 旧格式里的 imageB64 会在导入时搬进图片库
      await prefs.remove(_legacyPrefsKey);
    } catch (e) {
      debugPrint('migrate failed: $e');
    }
  }

  // ---------- 序列化 ----------

  Map<String, dynamic> toJson({bool withImages = false}) {
    final j = <String, dynamic>{
      'version': 2,
      'language': language,
      'demoLoaded': demoLoaded,
      'children': children.map((e) => e.toJson()).toList(),
      'members': members.map((e) => e.toJson()).toList(),
      'notices': notices.map((e) => e.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
      'tasks': tasks.map((e) => e.toJson()).toList(),
      'grades': grades.map((e) => e.toJson()).toList(),
      'logs': logs.map((e) => e.toJson()).toList(),
      'replies': replies.map((e) => e.toJson()).toList(),
    };
    if (withImages) {
      final ids = <String>{
        for (final n in notices) ...n.imageIds,
        for (final t in tasks)
          if (t.imageId != null) t.imageId!,
      };
      j['images'] = {for (final id in ids) if (image(id) != null) id: image(id)};
    }
    return j;
  }

  /// 备份用:带图片,可以完整恢复。
  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson(withImages: true));

  void importJson(String raw, {bool notify = true, bool persist = true}) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    List<Map<String, dynamic>> rows(String k) =>
        ((j[k] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    // 备份里内嵌的图片先入库(开着同步时也推上去)
    final imgs = j['images'];
    if (imgs is Map) {
      for (final e in imgs.entries) {
        _storeImage(e.key as String, e.value as String);
        sync?.onImagePut(e.key as String, e.value as String);
      }
    }
    // 0.1 版:图片以 imageB64 内嵌在通知/待办里 → 搬进图片库
    final noticeRows = rows('notices').map((n) {
      final legacy = n.remove('imageB64');
      if (legacy is String && legacy.isNotEmpty) {
        n['imageIds'] = [putImage(legacy)];
      }
      return n;
    }).toList();
    final taskRows = rows('tasks').map((t) {
      final legacy = t.remove('imageB64');
      if (legacy is String && legacy.isNotEmpty) t['imageId'] = putImage(legacy);
      return t;
    }).toList();

    language = j['language'] ?? 'zh';
    demoLoaded = j['demoLoaded'] ?? false;
    children = rows('children').map(Child.fromJson).toList();
    members = rows('members').map(Member.fromJson).toList();
    notices = noticeRows.map(Notice.fromJson).toList();
    events = rows('events').map(Event.fromJson).toList();
    tasks = taskRows.map(Task.fromJson).toList();
    grades = rows('grades').map(Grade.fromJson).toList();
    logs = rows('logs').map(StudyLog.fromJson).toList();
    replies = rows('replies').map(ReplyRecord.fromJson).toList();
    if (persist) _save(notify: notify);
  }

  void _save({bool notify = true}) {
    if (notify) notifyListeners();
    _box?.put('state', jsonEncode(toJson()));
    if (sync != null && !_applyingRemote) sync!.onLocalSave();
  }

  void saveSettings() {
    _box?.put('settings', jsonEncode(settings.toJson()));
    notifyListeners();
  }

  // ---------- 图片库 ----------

  String putImage(String b64) {
    final id = newId();
    _storeImage(id, b64);
    sync?.onImagePut(id, b64);
    return id;
  }

  void _storeImage(String id, String b64) {
    if (_images != null) {
      _images!.put(id, b64);
    } else {
      _memImages[id] = b64;
    }
  }

  String? image(String? id) => id == null ? null : (_images?.get(id) ?? _memImages[id]);

  void removeImage(String? id) {
    if (id == null) return;
    _images?.delete(id);
    _memImages.remove(id);
    sync?.onImageRemoved(id);
  }

  // ---------- 家庭同步(cloud/family_sync.dart 调用) ----------

  /// 每条记录一份 JSON。语言、筛选、设置不同步(每台设备自己的)。[t] 先给列表里的位置,同步层会换成真正的排序键。
  Map<String, SyncRecord> syncRecords() {
    final out = <String, SyncRecord>{};
    void add(String kind, List<dynamic> list, String Function(dynamic) idOf, Map<String, dynamic> Function(dynamic) toJson) {
      for (var i = 0; i < list.length; i++) {
        final r = SyncRecord(kind: kind, id: idOf(list[i]), json: jsonEncode(toJson(list[i])), t: i);
        out[r.docId] = r;
      }
    }

    add('child', children, (e) => e.id, (e) => e.toJson());
    add('member', members, (e) => e.id, (e) => e.toJson());
    add('notice', notices, (e) => e.id, (e) => e.toJson());
    add('event', events, (e) => e.id, (e) => e.toJson());
    add('task', tasks, (e) => e.id, (e) => e.toJson());
    add('grade', grades, (e) => e.id, (e) => e.toJson());
    add('log', logs, (e) => e.id, (e) => e.toJson());
    add('reply', replies, (e) => e.id, (e) => e.toJson());
    return out;
  }

  /// 用同步合并后的结果整体替换本机数据(不回推)。解析失败的单条跳过,不影响其余。
  void applySyncRecords(Iterable<SyncRecord> records) {
    final byKind = <String, List<SyncRecord>>{};
    for (final r in records) {
      byKind.putIfAbsent(r.kind, () => []).add(r);
    }
    List<T> decode<T>(String kind, T Function(Map<String, dynamic>) f) {
      final rs = [...?byKind[kind]]..sort((a, b) => a.t != b.t ? a.t.compareTo(b.t) : a.id.compareTo(b.id));
      final out = <T>[];
      for (final r in rs) {
        try {
          out.add(f(Map<String, dynamic>.from(jsonDecode(r.json) as Map)));
        } catch (e) {
          debugPrint('sync: skip bad ${r.docId}: $e');
        }
      }
      return out;
    }

    children = decode('child', Child.fromJson);
    members = decode('member', Member.fromJson);
    notices = decode('notice', Notice.fromJson)..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    events = decode('event', Event.fromJson);
    tasks = decode('task', Task.fromJson);
    grades = decode('grade', Grade.fromJson);
    logs = decode('log', StudyLog.fromJson);
    replies = decode('reply', ReplyRecord.fromJson)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (filterChildId.isNotEmpty && child(filterChildId) == null) filterChildId = '';
    _applyingRemote = true;
    try {
      _save();
    } finally {
      _applyingRemote = false;
    }
  }

  /// 云端来的图片:只存本机,不回推
  void cacheImage(String id, String b64) {
    if (image(id) == b64) return;
    _storeImage(id, b64);
    notifyListeners();
  }

  void dropImage(String id) {
    _images?.delete(id);
    _memImages.remove(id);
    notifyListeners();
  }

  /// 记录里引用到的全部图片 id
  Set<String> referencedImageIds() => {
        for (final n in notices) ...n.imageIds,
        for (final t in tasks)
          if (t.imageId != null) t.imageId!,
      };

  /// 上次同步时双方一致的样子(三方合并的 base),存在本机,重启后接着用
  Map<String, SyncRecord> loadSyncBase(String familyId) {
    final raw = _box?.get('sync_base_$familyId') ?? _memSyncBase[familyId];
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in m.entries) e.key: SyncRecord.fromJson(Map<String, dynamic>.from(e.value as Map))};
    } catch (_) {
      return {};
    }
  }

  void saveSyncBase(String familyId, Map<String, SyncRecord> base) {
    final raw = jsonEncode({for (final e in base.entries) e.key: e.value.toJson()});
    if (_box != null) {
      _box!.put('sync_base_$familyId', raw);
    } else {
      _memSyncBase[familyId] = raw;
    }
  }

  void clearSyncBase(String familyId) {
    _box?.delete('sync_base_$familyId');
    _memSyncBase.remove(familyId);
  }

  final Map<String, String> _memSyncBase = {};

  // ---------- 通用 ----------
  void setLanguage(String l) {
    language = l;
    _save();
  }

  void setFilter(String childId) {
    filterChildId = childId;
    notifyListeners();
  }

  Child? child(String id) {
    for (final c in children) {
      if (c.id == id) return c;
    }
    return null;
  }

  Member? member(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  bool _vis(String childId) => filterChildId.isEmpty || childId.isEmpty || childId == filterChildId;

  // ---------- 孩子 / 成员 ----------
  void upsertChild(Child c) {
    final i = children.indexWhere((e) => e.id == c.id);
    if (i < 0) {
      children.add(c);
    } else {
      children[i] = c;
    }
    _save();
  }

  void removeChild(String id) {
    children.removeWhere((e) => e.id == id);
    events.removeWhere((e) => e.childId == id);
    for (final t in tasks.where((e) => e.childId == id)) {
      removeImage(t.imageId);
    }
    tasks.removeWhere((e) => e.childId == id);
    grades.removeWhere((e) => e.childId == id);
    logs.removeWhere((e) => e.childId == id);
    for (final n in notices.where((e) => e.childId == id)) {
      n.imageIds.forEach(removeImage);
    }
    // 回这个孩子的通知写的英文信也一起删(信里可能有孩子的事);空白回信不属于哪个孩子,留着
    replies.removeWhere((r) => notices.any((n) => n.id == r.noticeId && n.childId == id));
    notices.removeWhere((e) => e.childId == id);
    if (filterChildId == id) filterChildId = '';
    _save();
  }

  void upsertMember(Member m) {
    final i = members.indexWhere((e) => e.id == m.id);
    if (i < 0) {
      members.add(m);
    } else {
      members[i] = m;
    }
    _save();
  }

  void removeMember(String id) {
    members.removeWhere((e) => e.id == id);
    _save();
  }

  // ---------- 通知 ----------
  void addNotice(Notice n) {
    notices.insert(0, n);
    _save();
  }

  void updateNotice(Notice n) {
    final i = notices.indexWhere((e) => e.id == n.id);
    if (i >= 0) notices[i] = n;
    _save();
  }

  void removeNotice(String id) {
    final n = notices.where((e) => e.id == id).firstOrNull;
    n?.imageIds.forEach(removeImage);
    notices.removeWhere((e) => e.id == id);
    _save();
  }

  List<Notice> get visibleNotices => notices.where((n) => _vis(n.childId)).toList();

  /// 确认提取结果:批量写入日程/待办,并标记通知已处理。
  /// 改期检测:同一孩子、标题相同、日期不同的旧日程 → 标为 rescheduled 并更新日期。
  void commitExtraction(Notice n, List<Event> evs, List<Task> ts, {bool reschedule = false, String extractor = ''}) {
    for (final e in evs) {
      Event? old;
      if (reschedule) {
        for (final x in events) {
          if (x.childId == e.childId && x.title == e.title && x.day != e.day && !x.done) {
            old = x;
            break;
          }
        }
      }
      if (old != null) {
        final i = events.indexOf(old);
        events[i] = old.copyWith(
          day: e.day,
          start: e.start,
          end: e.end,
          location: e.location.isNotEmpty ? e.location : old.location,
          rescheduled: true,
          note: '${old.note}\n[改期] 原 ${old.day.key} → ${e.day.key}'.trim(),
        );
      } else {
        events.add(e);
      }
    }
    tasks.addAll(ts);
    updateNotice(n.copyWith(processed: true, extractor: extractor.isEmpty ? n.extractor : extractor));
  }

  // ---------- 日程 ----------
  void upsertEvent(Event e) {
    final i = events.indexWhere((x) => x.id == e.id);
    if (i < 0) {
      events.add(e);
    } else {
      events[i] = e;
    }
    _save();
  }

  void removeEvent(String id) {
    events.removeWhere((e) => e.id == id);
    _save();
  }

  List<Event> eventsOn(Day d) => events.where((e) => e.day == d && _vis(e.childId)).toList()..sort(_byTime);

  List<Event> eventsBetween(Day a, Day b) =>
      events.where((e) => e.day.compareTo(a) >= 0 && e.day.compareTo(b) <= 0 && _vis(e.childId)).toList()..sort(_byTime);

  int _byTime(Event a, Event b) {
    final c = a.day.compareTo(b.day);
    if (c != 0) return c;
    final ta = a.start == null ? -1 : a.start!.hour * 60 + a.start!.minute;
    final tb = b.start == null ? -1 : b.start!.hour * 60 + b.start!.minute;
    return ta.compareTo(tb);
  }

  // ---------- 待办 ----------
  void upsertTask(Task t) {
    final i = tasks.indexWhere((x) => x.id == t.id);
    if (i < 0) {
      tasks.add(t);
    } else {
      tasks[i] = t;
    }
    _save();
  }

  void removeTask(String id) {
    final t = tasks.where((e) => e.id == id).firstOrNull;
    removeImage(t?.imageId);
    tasks.removeWhere((e) => e.id == id);
    _save();
  }

  List<Task> get openTasks => tasks.where((t) => t.isOpen && _vis(t.childId)).toList()..sort(_byDue);
  List<Task> get closedTasks => tasks.where((t) => !t.isOpen && _vis(t.childId)).toList()..sort(_byDue);

  int _byDue(Task a, Task b) {
    final da = a.due?.key ?? '9999', db = b.due?.key ?? '9999';
    return da.compareTo(db);
  }

  // ---------- 成绩 ----------
  void upsertGrade(Grade g) {
    final i = grades.indexWhere((x) => x.id == g.id);
    if (i < 0) {
      grades.add(g);
    } else {
      grades[i] = g;
    }
    _save();
  }

  void removeGrade(String id) {
    grades.removeWhere((e) => e.id == id);
    _save();
  }

  List<Grade> gradesOf(String childId) =>
      grades.where((g) => g.childId == childId).toList()..sort((a, b) => a.day.compareTo(b.day));

  // ---------- 学习记录 ----------
  StudyLog? logOn(String childId, Day d) {
    for (final l in logs) {
      if (l.childId == childId && l.day == d) return l;
    }
    return null;
  }

  void upsertLog(StudyLog l) {
    final i = logs.indexWhere((x) => x.childId == l.childId && x.day == l.day);
    if (i < 0) {
      logs.add(l);
    } else {
      logs[i] = l;
    }
    _save();
  }

  List<StudyLog> logsOf(String childId) =>
      logs.where((l) => l.childId == childId).toList()..sort((a, b) => a.day.compareTo(b.day));

  /// 连续打卡天数(到今天为止,有记录即算)
  int streak(String childId) {
    var d = Day.today();
    var n = 0;
    if (logOn(childId, d) == null) d = d.add(-1); // 今天还没记不算断
    while (logOn(childId, d) != null) {
      n++;
      d = d.add(-1);
    }
    return n;
  }

  // ---------- 用英文回复 ----------
  void addReply(ReplyRecord r) {
    replies.insert(0, r);
    _save();
  }

  void removeReply(String id) {
    replies.removeWhere((e) => e.id == id);
    _save();
  }

  List<ReplyRecord> repliesTo(String noticeId) => replies.where((r) => r.noticeId == noticeId).toList();

  // ---------- CSV 导出(F04:数据随时可带走) ----------

  String exportCsv(String kind) {
    String name(String id) => child(id)?.name ?? '';
    String who(String id) => member(id)?.name ?? '';
    List<List<Object?>> rows;
    switch (kind) {
      case 'grades':
        rows = [
          ['child', 'date', 'subject', 'test', 'score', 'full', 'class_avg', 'note'],
          for (final g in grades..sort((a, b) => a.day.compareTo(b.day)))
            [name(g.childId), g.day.key, g.subject, g.name, g.score, g.full, g.classAvg, g.note],
        ];
      case 'logs':
        rows = [
          ['child', 'date', 'homework_done', 'reading_minutes', 'focus', 'note', 'teacher_note'],
          for (final l in logs..sort((a, b) => a.day.compareTo(b.day)))
            [name(l.childId), l.day.key, l.homeworkDone, l.readingMinutes, l.focus, l.note, l.teacherNote],
        ];
      case 'events':
        rows = [
          ['child', 'date', 'start', 'end', 'title', 'location', 'assignee', 'done', 'rescheduled', 'note'],
          for (final e in events..sort(_byTime))
            [name(e.childId), e.day.key, _t(e.start), _t(e.end), e.title, e.location, who(e.assigneeId), e.done, e.rescheduled, e.note],
        ];
      default:
        rows = [
          ['child', 'kind', 'title', 'due', 'amount', 'currency', 'assignee', 'status', 'created'],
          for (final t in tasks..sort(_byDue))
            [name(t.childId), t.kind.name, t.title, t.due?.key, t.amount, t.amount == null ? null : t.currency ?? defaultCurrency, who(t.assigneeId), t.status.name, t.createdAt.toIso8601String()],
        ];
    }
    return '﻿${rows.map((r) => r.map(_csvCell).join(',')).join('\r\n')}'; // BOM 让 Excel 认 UTF-8
  }

  static String _t(dynamic tod) => tod == null
      ? ''
      : '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';

  static String _csvCell(Object? v) {
    final s = v == null ? '' : v.toString();
    return RegExp(r'[",\r\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  // ---------- 演示 / 清空 ----------
  void loadDemo() {
    DemoData.fill(this);
    demoLoaded = true;
    _save();
  }

  Future<void> clearAll() async {
    children = [];
    members = [];
    notices = [];
    events = [];
    tasks = [];
    grades = [];
    logs = [];
    replies = [];
    demoLoaded = false;
    filterChildId = '';
    _memImages.clear();
    _save();
    await _images?.clear();
    notifyListeners();
  }
}
