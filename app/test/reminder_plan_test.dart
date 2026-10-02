import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_sift/core/reminder_plan.dart';
import 'package:school_sift/models/models.dart';
import 'package:school_sift/store/app_state.dart';

void main() {
  test('待办:截止前一天、当天、逾期每天;已完成不提醒;简报有内容才发', () {
    final st = AppState();
    st.children = [const Child(id: 'c', name: '小雨')];
    st.members = [const Member(id: 'm', name: '妈妈')];
    final now = DateTime(2026, 10, 1, 12);
    st.tasks = [
      Task(id: 't1', childId: 'c', kind: TaskKind.sign, title: '签字:回执', due: const Day(2026, 10, 3), assigneeId: 'm', createdAt: now),
      Task(id: 't2', childId: 'c', kind: TaskKind.pay, title: '缴费', due: const Day(2026, 10, 3), status: TaskStatus.done, createdAt: now),
    ];
    st.events = [
      const Event(id: 'e1', childId: 'c', title: '家长会', day: Day(2026, 10, 5), start: TimeOfDay(hour: 14, minute: 30), assigneeId: 'm'),
    ];
    final plan = ReminderPlanner(st, now: now).plan();
    final keys = plan.map((p) => p.key).toList();
    expect(keys, contains('t:t1:eve'));
    expect(keys, contains('t:t1:day'));
    expect(keys, contains('t:t1:late1'));
    expect(keys, contains('t:t1:late7'));
    expect(keys.where((k) => k.startsWith('t:t2')), isEmpty, reason: '已完成的不催');
    expect(keys, contains('e:e1:eve'));
    expect(keys, contains('e:e1:1h'));
    final oneHour = plan.firstWhere((p) => p.key == 'e:e1:1h');
    expect(oneHour.at, DateTime(2026, 10, 5, 13, 30));
    expect(oneHour.body, contains('妈妈'));
    // 10/3 的简报里有截止的待办;10/7 之后没有任何内容 → 不排
    expect(keys, contains('brief:2026-10-03'));
    expect(plan.firstWhere((p) => p.key == 'brief:2026-10-07').body, contains('逾期'), reason: '逾期的待办一直出现在简报里');
    // 全部在未来
    expect(plan.every((p) => p.at.isAfter(now)), isTrue);
  });

  test('关掉提醒就什么都不排', () {
    final st = AppState();
    st.settings.remindersEnabled = false;
    st.tasks = [Task(id: 't', childId: 'c', kind: TaskKind.sign, title: 'x', due: Day.today().add(2), createdAt: DateTime.now())];
    expect(ReminderPlanner(st).plan(), isEmpty);
  });
}
