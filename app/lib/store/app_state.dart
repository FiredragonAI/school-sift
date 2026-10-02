// 全局状态 + 持久化。整个 App 的数据是一份 JSON,存 shared_preferences
// (Android = 本机文件,Web = localStorage)。本机优先:不注册、不上传。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'demo_data.dart';

class AppState extends ChangeNotifier {
  static const _key = 'school_sift_v1';

  String language = 'zh'; // zh / en
  List<Child> children = [];
  List<Member> members = [];
  List<Notice> notices = [];
  List<Event> events = [];
  List<Task> tasks = [];
  List<Grade> grades = [];
  List<StudyLog> logs = [];
  bool loaded = false;
  bool demoLoaded = false;

  /// 当前筛选的孩子('' = 全部)
  String filterChildId = '';

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        importJson(raw, notify: false);
      } catch (e) {
        debugPrint('load failed: $e');
      }
    }
    loaded = true;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'language': language,
        'demoLoaded': demoLoaded,
        'children': children.map((e) => e.toJson()).toList(),
        'members': members.map((e) => e.toJson()).toList(),
        'notices': notices.map((e) => e.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'grades': grades.map((e) => e.toJson()).toList(),
        'logs': logs.map((e) => e.toJson()).toList(),
      };

  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  void importJson(String raw, {bool notify = true}) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    List<T> l<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? []).map((e) => f(e as Map<String, dynamic>)).toList();
    language = j['language'] ?? 'zh';
    demoLoaded = j['demoLoaded'] ?? false;
    children = l('children', Child.fromJson);
    members = l('members', Member.fromJson);
    notices = l('notices', Notice.fromJson);
    events = l('events', Event.fromJson);
    tasks = l('tasks', Task.fromJson);
    grades = l('grades', Grade.fromJson);
    logs = l('logs', StudyLog.fromJson);
    if (notify) _save();
  }

  void _save() {
    notifyListeners();
    _prefs?.setString(_key, jsonEncode(toJson()));
  }

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
    tasks.removeWhere((e) => e.childId == id);
    grades.removeWhere((e) => e.childId == id);
    logs.removeWhere((e) => e.childId == id);
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
    notices.removeWhere((e) => e.id == id);
    _save();
  }

  List<Notice> get visibleNotices => notices.where((n) => _vis(n.childId)).toList();

  /// 确认提取结果:批量写入日程/待办,并标记通知已处理。
  /// 改期检测:同一孩子、标题相同、日期不同的旧日程 → 标为 rescheduled 并更新日期。
  void commitExtraction(Notice n, List<Event> evs, List<Task> ts, {bool reschedule = false}) {
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
    updateNotice(n.copyWith(processed: true));
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

  List<Event> eventsOn(Day d) => events.where((e) => e.day == d && _vis(e.childId)).toList()
    ..sort(_byTime);

  List<Event> eventsBetween(Day a, Day b) => events
      .where((e) => e.day.compareTo(a) >= 0 && e.day.compareTo(b) <= 0 && _vis(e.childId))
      .toList()
    ..sort(_byTime);

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
    tasks.removeWhere((e) => e.id == id);
    _save();
  }

  List<Task> get openTasks => tasks.where((t) => t.isOpen && _vis(t.childId)).toList()..sort(_byDue);
  List<Task> get closedTasks => tasks.where((t) => !t.isOpen && _vis(t.childId)).toList()..sort(_byDue);
  List<Task> get paperTasks => tasks.where((t) => t.kind == TaskKind.sign && _vis(t.childId)).toList()..sort(_byDue);

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

  // ---------- 演示 / 清空 ----------
  void loadDemo() {
    DemoData.fill(this);
    demoLoaded = true;
    _save();
  }

  void clearAll() {
    children = [];
    members = [];
    notices = [];
    events = [];
    tasks = [];
    grades = [];
    logs = [];
    demoLoaded = false;
    filterChildId = '';
    _save();
  }
}
