import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_sift/core/notice_parser.dart';
import 'package:school_sift/models/models.dart';

void main() {
  final p = NoticeParser(today: const Day(2026, 10, 1)); // 周四

  test('中文:家长会 + 签字回执 + 缴费', () {
    final r = p.parse('''各位家长:
学校定于10月15日(周四)下午2:30在三楼多功能厅召开三年级家长会,请家长准时参加。
随信附回执一份,请家长签字后于10月12日前交回班主任。
本学期课后服务费用300元,请于10月10日前通过缴费平台缴纳。''');
    final ev = r.items.where((e) => e.type == ItemType.event).toList();
    expect(ev.length, 1);
    expect(ev.first.day, const Day(2026, 10, 15));
    expect(ev.first.start, const TimeOfDay(hour: 14, minute: 30));
    expect(ev.first.location, '三楼多功能厅');
    expect(ev.first.title, contains('家长会'));
    final sign = r.items.firstWhere((e) => e.type == ItemType.sign);
    expect(sign.day, const Day(2026, 10, 12));
    final pay = r.items.firstWhere((e) => e.type == ItemType.pay);
    expect(pay.day, const Day(2026, 10, 10));
    expect(pay.amount, 300);
    expect(r.reschedule, isFalse);
  });

  test('中文:改期 + 相对日期 + 带东西', () {
    final r = p.parse('温馨提示:原定明天的秋游因天气原因改到下周三上午8点出发,请自备午餐和水壶。');
    expect(r.reschedule, isTrue);
    final ev = r.items.where((e) => e.type == ItemType.event || e.type == ItemType.bring);
    expect(ev.any((e) => e.day == const Day(2026, 10, 7)), isTrue,
        reason: '下周三 = 10/7');
    expect(r.items.any((e) => e.type == ItemType.bring && e.title.contains('午餐')), isTrue);
  });

  test('中文:无年份跨年', () {
    final r = p.parse('元旦联欢会定于1月5日举行。');
    expect(r.items.first.day, const Day(2027, 1, 5));
  });

  test('英文:field trip 日期 时间 费用 签字', () {
    final r = p.parse('''Dear Parents,
Our 4th grade field trip to the Science Museum is on Friday, October 24 from 9:00 am to 2:00 pm.
Please sign and return the permission slip by Oct 17. The cost is \$12 per student.
Students should bring a packed lunch.''');
    final ev = r.items.firstWhere((e) => e.type == ItemType.event);
    expect(ev.day, const Day(2026, 10, 24));
    expect(ev.start, const TimeOfDay(hour: 9, minute: 0));
    expect(ev.end, const TimeOfDay(hour: 14, minute: 0));
    final sign = r.items.firstWhere((e) => e.type == ItemType.sign);
    expect(sign.day, const Day(2026, 10, 17));
    expect(r.items.any((e) => e.type == ItemType.pay && e.amount == 12), isTrue);
    expect(r.items.any((e) => e.type == ItemType.bring), isTrue);
  });

  test('英文:next Monday 3pm', () {
    final r = p.parse('Picture day is next Monday at 3pm in the Main Gym.');
    final ev = r.items.first;
    expect(ev.day, const Day(2026, 10, 5));
    expect(ev.start, const TimeOfDay(hour: 15, minute: 0));
    expect(ev.location.toLowerCase(), contains('gym'));
  });

  test('无日期也不崩', () {
    final r = p.parse('请家长注意安全。');
    expect(r.items, isEmpty);
    expect(r.summary, isNotEmpty);
  });
}
