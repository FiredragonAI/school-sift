// 数据模型。全部是不可变的小对象 + toJson/fromJson,
// 由 AppState 统一持久化成一份 JSON(见 store/app_state.dart)。

import 'package:flutter/material.dart';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(DateTime.now().millisecond * 7919 % 1296).toRadixString(36)}';

/// 只有年月日,不带时区烦恼。
class Day implements Comparable<Day> {
  final int y, m, d;
  const Day(this.y, this.m, this.d);
  factory Day.of(DateTime t) => Day(t.year, t.month, t.day);
  factory Day.today() => Day.of(DateTime.now());
  factory Day.parse(String s) {
    final p = s.split('-').map(int.parse).toList();
    return Day(p[0], p[1], p[2]);
  }
  DateTime get date => DateTime(y, m, d);
  Day add(int n) => Day.of(date.add(Duration(days: n)));
  int get weekday => date.weekday;
  int diff(Day o) => date.difference(o.date).inDays;
  String get key =>
      '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
  @override
  int compareTo(Day o) => key.compareTo(o.key);
  @override
  bool operator ==(Object other) => other is Day && other.key == key;
  @override
  int get hashCode => key.hashCode;
  @override
  String toString() => key;
}

/// 孩子。颜色用于日程 / 成绩里的区分。
class Child {
  final String id;
  final String name;
  final String school;
  final String grade; // 年级/班级,自由文本
  final int color; // ARGB
  const Child({
    required this.id,
    required this.name,
    this.school = '',
    this.grade = '',
    this.color = 0xFF3F8CFF,
  });
  Child copyWith({String? name, String? school, String? grade, int? color}) =>
      Child(
        id: id,
        name: name ?? this.name,
        school: school ?? this.school,
        grade: grade ?? this.grade,
        color: color ?? this.color,
      );
  Color get c => Color(color);
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'school': school, 'grade': grade, 'color': color};
  factory Child.fromJson(Map<String, dynamic> j) => Child(
        id: j['id'],
        name: j['name'] ?? '',
        school: j['school'] ?? '',
        grade: j['grade'] ?? '',
        color: j['color'] ?? 0xFF3F8CFF,
      );
}

/// 家庭成员(谁去办)。
class Member {
  final String id;
  final String name;
  const Member({required this.id, required this.name});
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory Member.fromJson(Map<String, dynamic> j) =>
      Member(id: j['id'], name: j['name'] ?? '');
}

/// 收到的原始通知:文字 + 可选照片。提取结果落到 events/tasks 上,
/// 用 noticeId 回链,原文永远保留可搜。
class Notice {
  final String id;
  final String childId; // 可为空字符串 = 全家
  final String title;
  final String body;
  final String source; // 粘贴 / 拍照 / 演示
  final DateTime receivedAt;
  final List<String> imageIds; // 附图(照片/截图/PDF 页)在图片库里的 id
  final bool processed; // 已确认提取
  final String extractor; // 最后一次识别用的是 rules 还是 ai
  const Notice({
    required this.id,
    required this.childId,
    required this.title,
    required this.body,
    required this.source,
    required this.receivedAt,
    this.imageIds = const [],
    this.processed = false,
    this.extractor = '',
  });
  Notice copyWith({bool? processed, String? title, String? childId, String? body, List<String>? imageIds, String? extractor}) => Notice(
        id: id,
        childId: childId ?? this.childId,
        title: title ?? this.title,
        body: body ?? this.body,
        source: source,
        receivedAt: receivedAt,
        imageIds: imageIds ?? this.imageIds,
        processed: processed ?? this.processed,
        extractor: extractor ?? this.extractor,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'childId': childId,
        'title': title,
        'body': body,
        'source': source,
        'receivedAt': receivedAt.toIso8601String(),
        'imageIds': imageIds,
        'processed': processed,
        'extractor': extractor,
      };
  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
        id: j['id'],
        childId: j['childId'] ?? '',
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        source: j['source'] ?? '',
        receivedAt: DateTime.parse(j['receivedAt']),
        imageIds: ((j['imageIds'] as List?) ?? const []).cast<String>(),
        processed: j['processed'] ?? false,
        extractor: j['extractor'] ?? '',
      );
}

/// 日程(有日期的事:活动、考试、放假、家长会)。
class Event {
  final String id;
  final String childId;
  final String title;
  final Day day;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final String location;
  final String note;
  final String assigneeId; // 谁去
  final String noticeId;
  final bool done;
  final bool rescheduled; // 由"改期"类通知更新过
  const Event({
    required this.id,
    required this.childId,
    required this.title,
    required this.day,
    this.start,
    this.end,
    this.location = '',
    this.note = '',
    this.assigneeId = '',
    this.noticeId = '',
    this.done = false,
    this.rescheduled = false,
  });
  Event copyWith({
    String? childId,
    String? title,
    Day? day,
    TimeOfDay? start,
    TimeOfDay? end,
    bool clearTime = false,
    String? location,
    String? note,
    String? assigneeId,
    bool? done,
    bool? rescheduled,
  }) =>
      Event(
        id: id,
        childId: childId ?? this.childId,
        title: title ?? this.title,
        day: day ?? this.day,
        start: clearTime ? null : (start ?? this.start),
        end: clearTime ? null : (end ?? this.end),
        location: location ?? this.location,
        note: note ?? this.note,
        assigneeId: assigneeId ?? this.assigneeId,
        noticeId: noticeId,
        done: done ?? this.done,
        rescheduled: rescheduled ?? this.rescheduled,
      );
  DateTime get startDateTime =>
      DateTime(day.y, day.m, day.d, start?.hour ?? 0, start?.minute ?? 0);
  Map<String, dynamic> toJson() => {
        'id': id,
        'childId': childId,
        'title': title,
        'day': day.key,
        'start': _tod(start),
        'end': _tod(end),
        'location': location,
        'note': note,
        'assigneeId': assigneeId,
        'noticeId': noticeId,
        'done': done,
        'rescheduled': rescheduled,
      };
  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'],
        childId: j['childId'] ?? '',
        title: j['title'] ?? '',
        day: Day.parse(j['day']),
        start: _parseTod(j['start']),
        end: _parseTod(j['end']),
        location: j['location'] ?? '',
        note: j['note'] ?? '',
        assigneeId: j['assigneeId'] ?? '',
        noticeId: j['noticeId'] ?? '',
        done: j['done'] ?? false,
        rescheduled: j['rescheduled'] ?? false,
      );
}

String? _tod(TimeOfDay? t) => t == null
    ? null
    : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
TimeOfDay? _parseTod(String? s) {
  if (s == null || s.isEmpty) return null;
  final p = s.split(':');
  return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
}

/// 待办的类型:签字回执、缴费、带东西、其他。
enum TaskKind { sign, pay, bring, other }

enum TaskStatus { open, done, submitted } // submitted 只对 sign 有意义:已签且已交回

/// 家长要做的事(有截止日期、可指派、可追踪到"已交回")。
class Task {
  final String id;
  final String childId;
  final TaskKind kind;
  final String title;
  final Day? due;
  final double? amount;
  final String? currency; // 金额的货币 USD / CNY;null = 没记,按美元显示(core/money.dart)
  final String assigneeId;
  final String noticeId;
  final String? imageId; // 纸质单据照片(图片库 id)
  final TaskStatus status;
  final DateTime createdAt;
  const Task({
    required this.id,
    required this.childId,
    required this.kind,
    required this.title,
    this.due,
    this.amount,
    this.currency,
    this.assigneeId = '',
    this.noticeId = '',
    this.imageId,
    this.status = TaskStatus.open,
    required this.createdAt,
  });
  Task copyWith({
    String? childId,
    TaskKind? kind,
    String? title,
    Day? due,
    bool clearDue = false,
    double? amount,
    String? currency,
    String? assigneeId,
    TaskStatus? status,
    String? imageId,
  }) =>
      Task(
        id: id,
        childId: childId ?? this.childId,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        due: clearDue ? null : (due ?? this.due),
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        assigneeId: assigneeId ?? this.assigneeId,
        noticeId: noticeId,
        imageId: imageId ?? this.imageId,
        status: status ?? this.status,
        createdAt: createdAt,
      );
  bool get isOpen => status == TaskStatus.open;
  bool get overdue =>
      isOpen && due != null && due!.compareTo(Day.today()) < 0;
  Map<String, dynamic> toJson() => {
        'id': id,
        'childId': childId,
        'kind': kind.name,
        'title': title,
        'due': due?.key,
        'amount': amount,
        'currency': currency,
        'assigneeId': assigneeId,
        'noticeId': noticeId,
        'imageId': imageId,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };
  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'],
        childId: j['childId'] ?? '',
        kind: TaskKind.values.byName(j['kind'] ?? 'other'),
        title: j['title'] ?? '',
        due: j['due'] == null ? null : Day.parse(j['due']),
        amount: (j['amount'] as num?)?.toDouble(),
        currency: j['currency'], // 0.2 及以前的数据没有这个键
        assigneeId: j['assigneeId'] ?? '',
        noticeId: j['noticeId'] ?? '',
        imageId: j['imageId'],
        status: TaskStatus.values.byName(j['status'] ?? 'open'),
        createdAt: DateTime.parse(j['createdAt']),
      );
}

/// 一次测验/考试成绩。
class Grade {
  final String id;
  final String childId;
  final String subject;
  final String name; // 单元测 / 月考 / 听写
  final Day day;
  final double score;
  final double full; // 满分
  final double? classAvg;
  final String note;
  const Grade({
    required this.id,
    required this.childId,
    required this.subject,
    required this.name,
    required this.day,
    required this.score,
    this.full = 100,
    this.classAvg,
    this.note = '',
  });
  double get pct => full == 0 ? 0 : score / full * 100;
  Map<String, dynamic> toJson() => {
        'id': id,
        'childId': childId,
        'subject': subject,
        'name': name,
        'day': day.key,
        'score': score,
        'full': full,
        'classAvg': classAvg,
        'note': note,
      };
  factory Grade.fromJson(Map<String, dynamic> j) => Grade(
        id: j['id'],
        childId: j['childId'] ?? '',
        subject: j['subject'] ?? '',
        name: j['name'] ?? '',
        day: Day.parse(j['day']),
        score: (j['score'] as num).toDouble(),
        full: (j['full'] as num?)?.toDouble() ?? 100,
        classAvg: (j['classAvg'] as num?)?.toDouble(),
        note: j['note'] ?? '',
      );
}

/// 每日学习记录:作业完成、阅读分钟、专注度、一句话。
class StudyLog {
  final String id;
  final String childId;
  final Day day;
  final bool homeworkDone;
  final int readingMinutes;
  final int focus; // 1-5
  final String note;
  final String teacherNote; // 老师反馈(联系册/口头/App 里抄来的)
  const StudyLog({
    required this.id,
    required this.childId,
    required this.day,
    this.homeworkDone = false,
    this.readingMinutes = 0,
    this.focus = 3,
    this.note = '',
    this.teacherNote = '',
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'childId': childId,
        'day': day.key,
        'homeworkDone': homeworkDone,
        'readingMinutes': readingMinutes,
        'focus': focus,
        'note': note,
        'teacherNote': teacherNote,
      };
  factory StudyLog.fromJson(Map<String, dynamic> j) => StudyLog(
        id: j['id'],
        childId: j['childId'] ?? '',
        day: Day.parse(j['day']),
        homeworkDone: j['homeworkDone'] ?? false,
        readingMinutes: j['readingMinutes'] ?? 0,
        focus: j['focus'] ?? 3,
        note: j['note'] ?? '',
        teacherNote: j['teacherNote'] ?? '',
      );
}

// ---------- 用英文回复 ----------

/// 写给谁 / 什么语气 / 邮件还是短信。枚举名直接写进 prompt 和存储。
enum ReplyRecipient { teacher, office, nurse, coach, parent }

enum ReplyTone { polite, firm, apology, followUp, thanks }

enum ReplyFormat { email, text }

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.where((e) => e.name == name).firstOrNull ?? fallback;

/// 克制模式下的一处纠错:原文 → 改成,附原因。
class ReplyChange {
  final String before;
  final String after;
  final String reason;
  const ReplyChange({required this.before, required this.after, this.reason = ''});
  Map<String, dynamic> toJson() => {'before': before, 'after': after, 'reason': reason};
  factory ReplyChange.fromJson(Map<String, dynamic> j) =>
      ReplyChange(before: j['before'] ?? '', after: j['after'] ?? '', reason: j['reason'] ?? '');
}

/// AI 写好的一封英文:主题(短信为空)、正文、中文回译、纠错清单、发送前要留意的地方。
/// 署名占位 [Your name] 原样保存,显示时才填(见 ReplyWriter.applySignature)。
class ReplyDraft {
  final String subject;
  final String english;
  final String backTranslation;
  final List<ReplyChange> changes;
  final List<String> notes;
  const ReplyDraft({
    this.subject = '',
    required this.english,
    this.backTranslation = '',
    this.changes = const [],
    this.notes = const [],
  });
  Map<String, dynamic> toJson() => {
        'subject': subject,
        'english': english,
        'backTranslation': backTranslation,
        'changes': changes.map((e) => e.toJson()).toList(),
        'notes': notes,
      };
  factory ReplyDraft.fromJson(Map<String, dynamic> j) => ReplyDraft(
        subject: j['subject'] ?? '',
        english: j['english'] ?? '',
        backTranslation: j['backTranslation'] ?? '',
        changes: ((j['changes'] as List?) ?? const [])
            .map((e) => ReplyChange.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        notes: ((j['notes'] as List?) ?? const []).cast<String>(),
      );
}

/// 一封英文回信的记录:家长写了什么、选了什么、AI 回了什么。只存本机,随备份导出。
class ReplyRecord {
  final String id;
  final DateTime createdAt;
  final String noticeId; // 回的是哪条通知;'' = 从「更多」写的空白回信
  final String noticeTitle; // 标题快照:通知删了也看得出回的是什么
  final ReplyRecipient recipient;
  final ReplyTone tone;
  final ReplyFormat format;
  final bool restrained; // 克制模式:家长自己写英文,只纠错
  final String input; // 中文要点;克制模式下是英文草稿
  final ReplyDraft draft;
  const ReplyRecord({
    required this.id,
    required this.createdAt,
    this.noticeId = '',
    this.noticeTitle = '',
    this.recipient = ReplyRecipient.teacher,
    this.tone = ReplyTone.polite,
    this.format = ReplyFormat.email,
    this.restrained = false,
    required this.input,
    required this.draft,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'noticeId': noticeId,
        'noticeTitle': noticeTitle,
        'recipient': recipient.name,
        'tone': tone.name,
        'format': format.name,
        'restrained': restrained,
        'input': input,
        'draft': draft.toJson(),
      };
  factory ReplyRecord.fromJson(Map<String, dynamic> j) => ReplyRecord(
        id: j['id'],
        createdAt: DateTime.parse(j['createdAt']),
        noticeId: j['noticeId'] ?? '',
        noticeTitle: j['noticeTitle'] ?? '',
        recipient: _byName(ReplyRecipient.values, j['recipient'], ReplyRecipient.teacher),
        tone: _byName(ReplyTone.values, j['tone'], ReplyTone.polite),
        format: _byName(ReplyFormat.values, j['format'], ReplyFormat.email),
        restrained: j['restrained'] ?? false,
        input: j['input'] ?? '',
        draft: ReplyDraft.fromJson(Map<String, dynamic>.from((j['draft'] as Map?) ?? const {})),
      );
}
