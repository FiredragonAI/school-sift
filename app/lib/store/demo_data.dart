// 演示数据:两个孩子、一对家长、几条典型通知(已处理 + 待处理)、
// 成绩与学习记录。日期相对今天生成,所以任何时候打开都"像在学期中"。

import 'package:flutter/material.dart';

import '../models/models.dart';
import 'app_state.dart';

class DemoData {
  static void fill(AppState s) {
    final t = Day.today();
    const mom = Member(id: 'm_mom', name: '妈妈');
    const dad = Member(id: 'm_dad', name: '爸爸');
    const a = Child(id: 'c_a', name: '小雨', school: '实验小学', grade: '三(2)班', color: 0xFF3F8CFF);
    const b = Child(id: 'c_b', name: '小航', school: '实验小学', grade: '一(5)班', color: 0xFFFF8A3D);
    s.members = [mom, dad];
    s.children = [a, b];

    final n1 = Notice(
      id: 'n1',
      childId: a.id,
      title: '三年级家长会通知',
      source: 'demo',
      receivedAt: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
      processed: true,
      body: '各位家长:\n学校定于${_md(t.add(9))}(${_wk(t.add(9))})下午2:30在三楼多功能厅召开三年级家长会,请家长准时参加。\n随信附回执一份,请家长签字后于${_md(t.add(5))}前交回班主任。\n本学期课后服务费用300元,请于${_md(t.add(4))}前通过缴费平台缴纳。',
    );
    final n2 = Notice(
      id: 'n2',
      childId: b.id,
      title: '秋游改期',
      source: 'demo',
      receivedAt: DateTime.now().subtract(const Duration(hours: 5)),
      processed: false,
      body: '温馨提示:原定${_md(t.add(3))}的秋游因天气原因改到${_md(t.add(8))}上午8:00出发,地点:市植物园。请自备午餐和水壶,穿校服。',
    );
    final n3 = Notice(
      id: 'n3',
      childId: a.id,
      title: '期中考试安排',
      source: 'demo',
      receivedAt: DateTime.now().subtract(const Duration(days: 1)),
      processed: true,
      body: '期中考试时间:${_md(t.add(20))}上午语文、下午数学;${_md(t.add(21))}上午英语。请家长督促孩子复习。',
    );
    final n4 = Notice(
      id: 'n4',
      childId: b.id,
      title: '视力筛查知情同意书',
      source: 'demo',
      receivedAt: DateTime.now().subtract(const Duration(hours: 26)),
      processed: false,
      body: '学校将于${_md(t.add(6))}开展视力筛查,随发《知情同意书》一份,请家长阅读后签字,${_md(t.add(2))}前交回。',
    );
    s.notices = [n2, n4, n3, n1];

    s.events = [
      Event(id: 'e1', childId: a.id, title: '三年级家长会', day: t.add(9), start: const TimeOfDay(hour: 14, minute: 30), location: '三楼多功能厅', assigneeId: dad.id, noticeId: n1.id),
      Event(id: 'e2', childId: b.id, title: '秋游', day: t.add(3), start: const TimeOfDay(hour: 8, minute: 0), location: '市植物园', assigneeId: mom.id, note: '原定日期,通知说改期——待处理'),
      Event(id: 'e3', childId: a.id, title: '期中考试(语文/数学)', day: t.add(20), start: const TimeOfDay(hour: 8, minute: 30), noticeId: n3.id),
      Event(id: 'e4', childId: a.id, title: '期中考试(英语)', day: t.add(21), start: const TimeOfDay(hour: 8, minute: 30), noticeId: n3.id),
      Event(id: 'e5', childId: a.id, title: '钢琴课', day: t, start: const TimeOfDay(hour: 18, minute: 0), end: const TimeOfDay(hour: 19, minute: 0), location: '琴行', assigneeId: mom.id),
      Event(id: 'e6', childId: b.id, title: '足球训练', day: t.add(1), start: const TimeOfDay(hour: 16, minute: 30), location: '学校操场', assigneeId: dad.id),
      Event(id: 'e7', childId: '', title: '国庆假期返校', day: t.add(7), note: '两个孩子都要带作业本'),
    ];

    final now = DateTime.now();
    s.tasks = [
      Task(id: 't1', childId: a.id, kind: TaskKind.sign, title: '签字:家长会回执', due: t.add(5), assigneeId: mom.id, noticeId: n1.id, createdAt: now),
      Task(id: 't2', childId: a.id, kind: TaskKind.pay, title: '缴费:课后服务费', due: t.add(4), amount: 300, assigneeId: dad.id, noticeId: n1.id, createdAt: now),
      Task(id: 't3', childId: b.id, kind: TaskKind.sign, title: '签字:校服订购单', due: t.add(-1), assigneeId: mom.id, createdAt: now.subtract(const Duration(days: 4))),
      Task(id: 't4', childId: a.id, kind: TaskKind.bring, title: '带:美术课水彩笔', due: t.add(1), createdAt: now),
      Task(id: 't5', childId: b.id, kind: TaskKind.sign, title: '签字:上周听写本', due: t.add(-6), status: TaskStatus.submitted, createdAt: now.subtract(const Duration(days: 9))),
      Task(id: 't6', childId: a.id, kind: TaskKind.pay, title: '缴费:秋季校服', due: t.add(-12), amount: 260, status: TaskStatus.done, createdAt: now.subtract(const Duration(days: 20))),
    ];

    s.grades = [
      for (final g in [
        ('语文', '第一单元测', -40, 88.0, 86.0),
        ('语文', '第二单元测', -26, 92.0, 87.0),
        ('语文', '第三单元测', -12, 85.0, 84.5),
        ('语文', '第四单元测', -3, 94.0, 88.0),
        ('数学', '第一单元测', -38, 95.0, 90.0),
        ('数学', '第二单元测', -24, 90.0, 89.0),
        ('数学', '第三单元测', -10, 98.0, 91.0),
        ('数学', '口算竞赛', -2, 100.0, 93.0),
        ('英语', '听写1', -30, 80.0, 85.0),
        ('英语', '听写2', -16, 86.0, 86.0),
        ('英语', '听写3', -5, 90.0, 87.0),
      ])
        Grade(id: 'g${g.$1}${g.$3}', childId: a.id, subject: g.$1, name: g.$2, day: t.add(g.$3), score: g.$4, classAvg: g.$5),
      for (final g in [
        ('语文', '拼音测验', -20, 96.0),
        ('语文', '生字听写', -8, 90.0),
        ('数学', '10以内加减', -15, 100.0),
        ('数学', '20以内加减', -4, 92.0),
      ])
        Grade(id: 'gb${g.$1}${g.$3}', childId: b.id, subject: g.$1, name: g.$2, day: t.add(g.$3), score: g.$4),
    ];

    s.logs = [
      for (var i = 1; i <= 12; i++)
        StudyLog(
          id: 'la$i',
          childId: a.id,
          day: t.add(-i),
          homeworkDone: i % 5 != 0,
          readingMinutes: 15 + (i * 7) % 25,
          focus: 2 + (i * 3) % 4,
          note: i == 1 ? '数学作业做得快,语文背诵卡了一会' : '',
        ),
      for (var i = 1; i <= 6; i++)
        StudyLog(id: 'lb$i', childId: b.id, day: t.add(-i), homeworkDone: true, readingMinutes: 10 + (i * 5) % 15, focus: 3 + i % 3),
    ];
  }

  static String _md(Day d) => '${d.m}月${d.d}日';
  static String _wk(Day d) => '周${'一二三四五六日'[d.weekday - 1]}';
}
