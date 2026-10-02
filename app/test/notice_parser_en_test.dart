// 美国公立小学常见的英文通知(ParentSquare / 邮件风格)——首批用户在加州,通知以英文为主。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_sift/core/notice_parser.dart';
import 'package:school_sift/models/models.dart';

void main() {
  final p = NoticeParser(today: const Day(2026, 10, 1)); // Thursday

  test('one-paragraph field trip email splits into event + sign + pay + bring', () {
    final r = p.parse(
        'Dear Lincoln Families, our 4th grade field trip to the Exploratorium is on Friday, October 24 from 9:00 to 1:30 PM. '
        'Please sign and return the permission slip by Oct 17. The cost is \$12 per student (checks payable to Lincoln PTA). '
        'Students should wear their school t-shirt and bring a packed lunch. Thank you!');
    final ev = r.items.firstWhere((e) => e.type == ItemType.event);
    expect(ev.day, const Day(2026, 10, 24));
    expect(ev.start, const TimeOfDay(hour: 9, minute: 0), reason: '9:00 inherits the PM? no — 9:00 to 1:30 PM means 9 am');
    expect(ev.end, const TimeOfDay(hour: 13, minute: 30));
    expect(ev.title.toLowerCase(), contains('field trip'));
    expect(ev.title, contains('Exploratorium'));
    final sign = r.items.firstWhere((e) => e.type == ItemType.sign);
    expect(sign.day, const Day(2026, 10, 17));
    expect(sign.title, startsWith('Sign:'));
    expect(r.items.any((e) => e.type == ItemType.pay && e.amount == 12), isTrue);
    expect(r.items.any((e) => e.type == ItemType.bring && e.title.startsWith('Bring:')), isTrue);
    expect(r.summary.first, contains('event'));
  });

  test('US numeric date, minimum day, early dismissal time', () {
    final r = p.parse('Reminder: 10/15/2026 is a Minimum Day. Dismissal is at 12:30 PM for all grades.');
    final ev = r.items.firstWhere((e) => e.type == ItemType.event);
    expect(ev.day, const Day(2026, 10, 15));
    expect(ev.title.toLowerCase(), contains('minimum day'));
  });

  test('reschedule in English', () {
    final r = p.parse('Picture Day has been moved from Tuesday, Oct 7 to Thursday, Oct 16. Please have students wear their uniforms.');
    expect(r.reschedule, isTrue);
    final ev = r.items.firstWhere((e) => e.type == ItemType.event);
    expect(ev.day, const Day(2026, 10, 16), reason: 'new date is the last one in a reschedule sentence');
    expect(ev.title.toLowerCase(), contains('picture day'));
  });

  test('RSVP deadline + evening event with am/pm shared on the range', () {
    final r = p.parse('Back to School Night is Thursday, October 9 from 6:00-7:30 PM in the MPR. RSVP by October 6.');
    final ev = r.items.firstWhere((e) => e.type == ItemType.event);
    expect(ev.start, const TimeOfDay(hour: 18, minute: 0));
    expect(ev.end, const TimeOfDay(hour: 19, minute: 30));
    expect(ev.location.toUpperCase(), contains('MPR'));
    final dl = r.items.firstWhere((e) => e.type == ItemType.deadline);
    expect(dl.day, const Day(2026, 10, 6));
    expect(dl.title, startsWith('Due:'));
  });

  test('no school holiday, English summary', () {
    final r = p.parse('There is no school on Monday, November 11 in observance of Veterans Day.');
    expect(r.items.single.day, const Day(2026, 11, 11));
    expect(NoticeParser.isEnglish('There is no school'), isTrue);
    expect(NoticeParser.isEnglish('明天不上学'), isFalse);
  });
}
