// 日程导出:.ics(Apple/Outlook/Google 都能导入)与 Google 日历"添加事件"链接。
// 不另造一个日历,家长的日程还是在他们自己的日历 App 里。

import '../models/models.dart';

String _p(int n) => n.toString().padLeft(2, '0');

String _stamp(DateTime t) =>
    '${t.year}${_p(t.month)}${_p(t.day)}T${_p(t.hour)}${_p(t.minute)}00';

String _esc(String s) => s.replaceAll('\\', '\\\\').replaceAll(',', '\\,').replaceAll(';', '\\;').replaceAll('\n', '\\n');

String buildIcs(List<Event> events, {String Function(String childId)? childName}) {
  final b = StringBuffer()
    ..writeln('BEGIN:VCALENDAR')
    ..writeln('VERSION:2.0')
    ..writeln('PRODID:-//SchoolSift//ZH//CN')
    ..writeln('CALSCALE:GREGORIAN');
  final now = _stamp(DateTime.now().toUtc());
  for (final e in events) {
    final who = childName?.call(e.childId) ?? '';
    final summary = who.isEmpty ? e.title : '[$who] ${e.title}';
    b.writeln('BEGIN:VEVENT');
    b.writeln('UID:schoolsift-${e.id}@schoolsift');
    b.writeln('DTSTAMP:${now}Z');
    if (e.start == null) {
      b.writeln('DTSTART;VALUE=DATE:${e.day.y}${_p(e.day.m)}${_p(e.day.d)}');
      final nd = e.day.add(1);
      b.writeln('DTEND;VALUE=DATE:${nd.y}${_p(nd.m)}${_p(nd.d)}');
    } else {
      final st = e.startDateTime;
      final en = e.end == null
          ? st.add(const Duration(hours: 1))
          : DateTime(e.day.y, e.day.m, e.day.d, e.end!.hour, e.end!.minute);
      b.writeln('DTSTART:${_stamp(st)}');
      b.writeln('DTEND:${_stamp(en)}');
    }
    b.writeln('SUMMARY:${_esc(summary)}');
    if (e.location.isNotEmpty) b.writeln('LOCATION:${_esc(e.location)}');
    if (e.note.isNotEmpty) b.writeln('DESCRIPTION:${_esc(e.note)}');
    b.writeln('BEGIN:VALARM');
    b.writeln('TRIGGER:-PT18H');
    b.writeln('ACTION:DISPLAY');
    b.writeln('DESCRIPTION:${_esc(summary)}');
    b.writeln('END:VALARM');
    b.writeln('END:VEVENT');
  }
  b.writeln('END:VCALENDAR');
  return b.toString().replaceAll('\n', '\r\n');
}

String googleCalendarUrl(Event e, {String who = ''}) {
  final title = who.isEmpty ? e.title : '[$who] ${e.title}';
  String dates;
  if (e.start == null) {
    final nd = e.day.add(1);
    dates = '${e.day.y}${_p(e.day.m)}${_p(e.day.d)}/${nd.y}${_p(nd.m)}${_p(nd.d)}';
  } else {
    final st = e.startDateTime;
    final en = e.end == null
        ? st.add(const Duration(hours: 1))
        : DateTime(e.day.y, e.day.m, e.day.d, e.end!.hour, e.end!.minute);
    dates = '${_stamp(st)}/${_stamp(en)}';
  }
  final q = {
    'action': 'TEMPLATE',
    'text': title,
    'dates': dates,
    if (e.location.isNotEmpty) 'location': e.location,
    if (e.note.isNotEmpty) 'details': e.note,
  };
  return Uri.https('calendar.google.com', '/calendar/render', q).toString();
}
