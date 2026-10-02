// 提醒计划:从当前数据算出"什么时候、提醒什么"。纯函数,方便测试;
// 真正发通知的是 platform/reminders.dart。
//
// 规则(F03:工具要主动催、追踪到做完):
//   待办  截止前一天 19:00、截止当天 08:00;逾期后每天 08:00 再催,最多 7 天
//   日程  前一天 19:00;有开始时间的,开始前 1 小时
//   简报  每天早上(可设)一条"今天和明天",只在有内容时发;一次排未来 7 天
// 每次数据变动都整体重排(先全部取消再排),所以已完成的事自然不再响。

import '../models/models.dart';
import '../store/app_state.dart';

class PlannedReminder {
  final String key; // 稳定标识,用来去重/生成通知 id
  final DateTime at;
  final String title;
  final String body;
  const PlannedReminder({required this.key, required this.at, required this.title, required this.body});
}

class ReminderPlanner {
  final AppState st;
  final DateTime now;
  ReminderPlanner(this.st, {DateTime? now}) : now = now ?? DateTime.now();

  bool get zh => st.language == 'zh';
  String _t(String a, String b) => zh ? a : b;

  String _who(String childId, String assigneeId) {
    final c = st.child(childId)?.name;
    final m = st.member(assigneeId)?.name;
    return [if (c != null) c, if (m != null) '👤 $m'].join(' · ');
  }

  List<PlannedReminder> plan({int cap = 300}) {
    if (!st.settings.remindersEnabled) return const [];
    final out = <PlannedReminder>[];
    final today = Day.of(now);

    for (final t in st.tasks.where((t) => t.isOpen && t.due != null)) {
      final due = t.due!;
      final who = _who(t.childId, t.assigneeId);
      final tail = who.isEmpty ? '' : ' · $who';
      _add(out, 't:${t.id}:eve', DateTime(due.y, due.m, due.d - 1, 19), _t('明天截止', 'Due tomorrow'), '${t.title}$tail');
      _add(out, 't:${t.id}:day', DateTime(due.y, due.m, due.d, 8), _t('今天截止', 'Due today'), '${t.title}$tail');
      for (var i = 1; i <= 7; i++) {
        _add(out, 't:${t.id}:late$i', DateTime(due.y, due.m, due.d + i, 8),
            _t('已逾期 $i 天', 'Overdue by $i day${i > 1 ? 's' : ''}'), '${t.title}$tail');
      }
    }

    for (final e in st.events.where((e) => !e.done)) {
      final who = _who(e.childId, e.assigneeId);
      final tail = who.isEmpty ? '' : ' · $who';
      final loc = e.location.isEmpty ? '' : ' @${e.location}';
      final timeStr = e.start == null ? '' : ' ${_hm(e.start!.hour, e.start!.minute)}';
      _add(out, 'e:${e.id}:eve', DateTime(e.day.y, e.day.m, e.day.d - 1, 19), _t('明天', 'Tomorrow'), '${e.title}$timeStr$loc$tail');
      if (e.start != null) {
        _add(out, 'e:${e.id}:1h', e.startDateTime.subtract(const Duration(hours: 1)), _t('1 小时后', 'In 1 hour'), '${e.title}$loc$tail');
      }
    }

    if (st.settings.briefEnabled) {
      for (var i = 0; i < 7; i++) {
        final d = today.add(i);
        final at = DateTime(d.y, d.m, d.d, st.settings.briefHour, st.settings.briefMinute);
        final body = briefText(d, maxLines: 4);
        if (body.isEmpty) continue;
        _add(out, 'brief:${d.key}', at, _t('今天和明天', 'Today & tomorrow'), body);
      }
    }

    out.sort((a, b) => a.at.compareTo(b.at));
    return out.length > cap ? out.sublist(0, cap) : out;
  }

  /// 某一天的简报正文(也给"分享简报"用)。
  String briefText(Day d, {int maxLines = 12}) {
    final lines = <String>[];
    void evs(String label, Day day) {
      final es = st.events.where((e) => e.day == day && !e.done).toList();
      for (final e in es) {
        final c = st.child(e.childId)?.name;
        lines.add('$label ${e.start == null ? '' : '${_hm(e.start!.hour, e.start!.minute)} '}${e.title}${c == null ? '' : ' ($c)'}');
      }
    }
    evs(_t('今天', 'Today'), d);
    evs(_t('明天', 'Tomorrow'), d.add(1));
    final due = st.tasks.where((t) => t.isOpen && t.due != null && t.due!.compareTo(d.add(1)) <= 0).toList();
    for (final t in due) {
      final late = t.due!.compareTo(d) < 0;
      lines.add('${late ? _t('⚠ 逾期', '⚠ Overdue') : _t('待办', 'To do')} ${t.title}');
    }
    return lines.take(maxLines).join('\n');
  }

  void _add(List<PlannedReminder> out, String key, DateTime at, String title, String body) {
    if (at.isBefore(now)) return;
    if (at.difference(now).inDays > 60) return;
    out.add(PlannedReminder(key: key, at: at, title: title, body: body));
  }

  static String _hm(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}
