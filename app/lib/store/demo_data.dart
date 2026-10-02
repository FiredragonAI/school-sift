// 演示数据:两个孩子、一对家长、几条典型通知(已处理 + 待处理)、成绩与学习记录。
// 日期相对今天生成,所以任何时候打开都"像在学期中"。界面是英文时给一套美国小学的英文数据
//(首批用户在加州,通知以英文为主);中文界面也混一条英文 ParentSquare 通知,双语家庭就是这样。

import 'package:flutter/material.dart';

import '../models/models.dart';
import 'app_state.dart';

class DemoData {
  static void fill(AppState s) {
    final t = Day.today();
    final en = s.language == 'en';
    String z(String zh, String e) => en ? e : zh;

    final mom = Member(id: 'm_mom', name: z('妈妈', 'Mom'));
    final dad = Member(id: 'm_dad', name: z('爸爸', 'Dad'));
    final a = Child(id: 'c_a', name: z('小雨', 'Mia'), school: z('实验小学', 'Lincoln Elementary'), grade: z('三(2)班', 'Grade 4 · Rm 12'), color: 0xFF3F8CFF);
    final b = Child(id: 'c_b', name: z('小航', 'Leo'), school: z('实验小学', 'Lincoln Elementary'), grade: z('一(5)班', 'Grade 1 · Rm 3'), color: 0xFFFF8A3D);
    s.members = [mom, dad];
    s.children = [a, b];

    final now = DateTime.now();
    final n1 = Notice(
      id: 'n1',
      childId: a.id,
      title: z('三年级家长会通知', 'Parent-Teacher Conferences'),
      source: 'demo',
      receivedAt: now.subtract(const Duration(days: 2, hours: 3)),
      processed: true,
      extractor: 'rules',
      body: en
          ? 'Dear Grade 4 Families, Parent-Teacher Conferences will be held on ${_en(t.add(9))} from 2:30 to 6:00 PM in Room 12. Please sign and return the conference request form by ${_en(t.add(5))}. The optional after-school program fee of \$300 is due by ${_en(t.add(4))}.'
          : '各位家长:\n学校定于${_md(t.add(9))}(${_wk(t.add(9))})下午2:30在三楼多功能厅召开三年级家长会,请家长准时参加。\n随信附回执一份,请家长签字后于${_md(t.add(5))}前交回班主任。\n本学期课后服务费用300元,请于${_md(t.add(4))}前通过缴费平台缴纳。',
    );
    final n2 = Notice(
      id: 'n2',
      childId: b.id,
      title: z('秋游改期', 'Field trip rescheduled'),
      source: 'demo',
      receivedAt: now.subtract(const Duration(hours: 5)),
      body: en
          ? 'Weather update: the Grade 1 field trip originally scheduled for ${_en(t.add(3))} has been moved to ${_en(t.add(8))}. Buses leave at 8:00 AM from the front office. Please pack a lunch and a water bottle, and wear the school t-shirt.'
          : '温馨提示:原定${_md(t.add(3))}的秋游因天气原因改到${_md(t.add(8))}上午8:00出发,地点:市植物园。请自备午餐和水壶,穿校服。',
    );
    final n3 = Notice(
      id: 'n3',
      childId: a.id,
      title: z('期中考试安排', 'Midterm assessment schedule'),
      source: 'demo',
      receivedAt: now.subtract(const Duration(days: 1)),
      processed: true,
      extractor: 'rules',
      body: en
          ? 'Midterm assessments: ${_en(t.add(20))} Reading and Math; ${_en(t.add(21))} Science. Please make sure students get a good night’s sleep.'
          : '期中考试时间:${_md(t.add(20))}上午语文、下午数学;${_md(t.add(21))}上午英语。请家长督促孩子复习。',
    );
    final n4 = Notice(
      id: 'n4',
      childId: b.id,
      title: z('视力筛查知情同意书', 'Vision screening consent'),
      source: 'demo',
      receivedAt: now.subtract(const Duration(hours: 26)),
      body: en
          ? 'The district nurse will conduct vision screening on ${_en(t.add(6))}. A consent form is attached; please sign and return it by ${_en(t.add(2))}.'
          : '学校将于${_md(t.add(6))}开展视力筛查,随发《知情同意书》一份,请家长阅读后签字,${_md(t.add(2))}前交回。',
    );
    // 中文界面也放一条真实风格的 ParentSquare 英文通知
    final n5 = Notice(
      id: 'n5',
      childId: a.id,
      title: 'Picture Day & Book Fair',
      source: 'demo',
      receivedAt: now.subtract(const Duration(hours: 50)),
      body: 'Hi Lincoln families! Picture Day is ${_en(t.add(12))}. Order forms went home today; online orders are due by ${_en(t.add(11))}. '
          'The Scholastic Book Fair runs ${_en(t.add(14))}-${_en(t.add(16))} in the library, open 8-9 AM and after school. Volunteers needed — sign up by ${_en(t.add(10))}.',
    );
    s.notices = [n2, n4, n5, n3, n1];

    s.events = [
      Event(id: 'e1', childId: a.id, title: z('三年级家长会', 'Parent-Teacher Conference'), day: t.add(9), start: const TimeOfDay(hour: 14, minute: 30), location: z('三楼多功能厅', 'Room 12'), assigneeId: dad.id, noticeId: n1.id),
      Event(id: 'e2', childId: b.id, title: z('秋游', 'Field trip'), day: t.add(3), start: const TimeOfDay(hour: 8, minute: 0), location: z('市植物园', 'Front office'), assigneeId: mom.id, note: z('原定日期,通知说改期——待处理', 'Original date — a reschedule notice is waiting')),
      Event(id: 'e3', childId: a.id, title: z('期中考试(语文/数学)', 'Midterm: Reading & Math'), day: t.add(20), start: const TimeOfDay(hour: 8, minute: 30), noticeId: n3.id),
      Event(id: 'e4', childId: a.id, title: z('期中考试(英语)', 'Midterm: Science'), day: t.add(21), start: const TimeOfDay(hour: 8, minute: 30), noticeId: n3.id),
      Event(id: 'e5', childId: a.id, title: z('钢琴课', 'Piano lesson'), day: t, start: const TimeOfDay(hour: 18, minute: 0), end: const TimeOfDay(hour: 19, minute: 0), location: z('琴行', 'Music studio'), assigneeId: mom.id),
      Event(id: 'e6', childId: b.id, title: z('足球训练', 'Soccer practice'), day: t.add(1), start: const TimeOfDay(hour: 16, minute: 30), location: z('学校操场', 'School field'), assigneeId: dad.id),
      Event(id: 'e7', childId: '', title: z('国庆假期返校', 'Back to school after break'), day: t.add(7), note: z('两个孩子都要带作业本', 'Both kids: bring homework folders')),
    ];

    s.tasks = [
      Task(id: 't1', childId: a.id, kind: TaskKind.sign, title: z('签字:家长会回执', 'Sign: conference request form'), due: t.add(5), assigneeId: mom.id, noticeId: n1.id, createdAt: now),
      Task(id: 't2', childId: a.id, kind: TaskKind.pay, title: z('缴费:课后服务费', 'Pay: after-school program fee'), due: t.add(4), amount: 300, assigneeId: dad.id, noticeId: n1.id, createdAt: now),
      Task(id: 't3', childId: b.id, kind: TaskKind.sign, title: z('签字:校服订购单', 'Sign: spirit wear order form'), due: t.add(-1), assigneeId: mom.id, createdAt: now.subtract(const Duration(days: 4))),
      Task(id: 't4', childId: a.id, kind: TaskKind.bring, title: z('带:美术课水彩笔', 'Bring: markers for art'), due: t.add(1), createdAt: now),
      Task(id: 't5', childId: b.id, kind: TaskKind.sign, title: z('签字:上周听写本', 'Sign: last week’s spelling test'), due: t.add(-6), status: TaskStatus.submitted, createdAt: now.subtract(const Duration(days: 9))),
      Task(id: 't6', childId: a.id, kind: TaskKind.pay, title: z('缴费:秋季校服', 'Pay: yearbook'), due: t.add(-12), amount: en ? 35 : 260, status: TaskStatus.done, createdAt: now.subtract(const Duration(days: 20))),
    ];

    final subj = en ? ['Reading', 'Math', 'Spelling'] : ['语文', '数学', '英语'];
    s.grades = [
      for (final g in [
        (0, z('第一单元测', 'Unit 1'), -40, 88.0, 86.0),
        (0, z('第二单元测', 'Unit 2'), -26, 92.0, 87.0),
        (0, z('第三单元测', 'Unit 3'), -12, 85.0, 84.5),
        (0, z('第四单元测', 'Unit 4'), -3, 94.0, 88.0),
        (1, z('第一单元测', 'Unit 1'), -38, 95.0, 90.0),
        (1, z('第二单元测', 'Unit 2'), -24, 90.0, 89.0),
        (1, z('第三单元测', 'Unit 3'), -10, 98.0, 91.0),
        (1, z('口算竞赛', 'Math facts sprint'), -2, 100.0, 93.0),
        (2, z('听写1', 'Week 3'), -30, 80.0, 85.0),
        (2, z('听写2', 'Week 5'), -16, 86.0, 86.0),
        (2, z('听写3', 'Week 7'), -5, 90.0, 87.0),
      ])
        Grade(id: 'g${g.$1}${g.$3}', childId: a.id, subject: subj[g.$1], name: g.$2, day: t.add(g.$3), score: g.$4, classAvg: g.$5),
      for (final g in [
        (0, z('拼音测验', 'Sight words'), -20, 96.0),
        (0, z('生字听写', 'Letter sounds'), -8, 90.0),
        (1, z('10以内加减', 'Add within 10'), -15, 100.0),
        (1, z('20以内加减', 'Add within 20'), -4, 92.0),
      ])
        Grade(id: 'gb${g.$1}${g.$3}', childId: b.id, subject: subj[g.$1], name: g.$2, day: t.add(g.$3), score: g.$4),
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
          note: i == 1 ? z('数学作业做得快,语文背诵卡了一会', 'Math was quick; reading log took a while') : '',
          teacherNote: i == 2 ? z('课堂发言积极,作业字迹要再工整', 'Great participation; please work on handwriting') : '',
        ),
      for (var i = 1; i <= 6; i++)
        StudyLog(id: 'lb$i', childId: b.id, day: t.add(-i), homeworkDone: true, readingMinutes: 10 + (i * 5) % 15, focus: 3 + i % 3),
    ];
  }

  static String _md(Day d) => '${d.m}月${d.d}日';
  static String _wk(Day d) => '周${'一二三四五六日'[d.weekday - 1]}';
  static String _en(Day d) =>
      '${['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][d.weekday - 1]}, ${['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][d.m - 1]} ${d.d}';
}
