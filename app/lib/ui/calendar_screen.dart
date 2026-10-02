// 日程页:月历 + 当日列表 / 待办清单(两个视图切换)。
// 日程可导出 .ics 或一键加到 Google 日历——不另造日历,家长还用自己的。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ics.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../platform/export.dart';
import '../store/app_state.dart';
import 'widgets.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  int view = 0; // 0 日历 1 待办
  Day selected = Day.today();
  late Day monthAnchor = Day(selected.y, selected.m, 1);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 0, label: Text(s.viewCalendar), icon: const Icon(Icons.calendar_month_outlined)),
            ButtonSegment(value: 1, label: Text('${s.viewTasks} ${st.openTasks.isEmpty ? '' : '(${st.openTasks.length})'}'), icon: const Icon(Icons.checklist)),
          ],
          selected: {view},
          onSelectionChanged: (v) => setState(() => view = v.first),
          showSelectedIcon: false,
        ),
        actions: [
          if (view == 0)
            IconButton(
              tooltip: s.exportIcs,
              icon: const Icon(Icons.ios_share),
              onPressed: () {
                final evs = st.events.where((e) => e.day.compareTo(Day.today().add(-7)) >= 0).toList();
                exportText('schoolsift.ics', 'text/calendar', buildIcs(evs, childName: (id) => st.child(id)?.name ?? ''));
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "fab_calendar",
        onPressed: () => view == 0 ? showEventEditor(context, day: selected) : showTaskEditor(context),
        child: const Icon(Icons.add),
      ),
      body: Column(children: [
        const ChildFilterBar(),
        Expanded(child: view == 0 ? _calendar(context, s, st) : _tasks(context, s, st)),
      ]),
    );
  }

  Widget _calendar(BuildContext context, S s, AppState st) {
    final first = monthAnchor;
    final daysInMonth = DateTime(first.y, first.m + 1, 0).day;
    final lead = first.weekday - 1; // 周一开头
    final cells = <Day?>[for (var i = 0; i < lead; i++) null, for (var d = 1; d <= daysInMonth; d++) Day(first.y, first.m, d)];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final dayEvents = st.eventsOn(selected);
    final upcoming = st.eventsBetween(selected.add(1), selected.add(30)).take(8).toList();
    final today = Day.today();

    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: [
      Row(children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => monthAnchor = Day(first.m == 1 ? first.y - 1 : first.y, first.m == 1 ? 12 : first.m - 1, 1))),
        Expanded(child: Text(s.zh ? '${first.y}年${first.m}月' : '${s.monthName(first.m)} ${first.y}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => monthAnchor = Day(first.m == 12 ? first.y + 1 : first.y, first.m == 12 ? 1 : first.m + 1, 1))),
        TextButton(onPressed: () => setState(() { selected = today; monthAnchor = Day(today.y, today.m, 1); }), child: Text(s.today)),
      ]),
      Row(children: [for (var i = 1; i <= 7; i++) Expanded(child: Center(child: Text(s.weekday(i).replaceAll('周', ''), style: Theme.of(context).textTheme.labelSmall)))]),
      const SizedBox(height: 4),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.95,
        children: [
          for (final d in cells)
            d == null
                ? const SizedBox()
                : InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => selected = d),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: d == selected ? Theme.of(context).colorScheme.primary : (d == today ? Theme.of(context).colorScheme.primaryContainer : null),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('${d.d}', style: TextStyle(color: d == selected ? Colors.white : null, fontWeight: d == today ? FontWeight.w700 : null)),
                        const SizedBox(height: 3),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          for (final e in st.eventsOn(d).take(3)) Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: ChildDot(e.childId, size: 5)),
                          for (final t in st.openTasks.where((t) => t.due == d).take(2)) Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: Icon(Icons.circle, size: 5, color: kindColor(t.kind))),
                        ]),
                      ]),
                    ),
                  ),
        ],
      ),
      const SizedBox(height: 8),
      SectionTitle(s.mdw(selected)),
      Card(
        child: dayEvents.isEmpty && st.openTasks.where((t) => t.due == selected).isEmpty
            ? ListTile(title: Text(s.calendarEmpty, style: TextStyle(color: Theme.of(context).colorScheme.outline)))
            : Column(children: [
                for (final e in dayEvents) Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: EventRow(e)),
                for (final t in st.openTasks.where((t) => t.due == selected)) TaskTile(t, compact: true),
              ]),
      ),
      if (upcoming.isNotEmpty) ...[
        SectionTitle(s.upcoming),
        Card(
          child: Column(children: [
            for (final e in upcoming)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(children: [
                  SizedBox(width: 78, child: Text(s.relative(e.day), style: Theme.of(context).textTheme.labelMedium)),
                  Expanded(child: EventRow(e)),
                ]),
              ),
          ]),
        ),
      ],
    ]);
  }

  Widget _tasks(BuildContext context, S s, AppState st) {
    final open = st.openTasks;
    final closed = st.closedTasks;
    final today = Day.today();
    List<Task> g(bool Function(Task) f) => open.where(f).toList();
    final overdue = g((t) => t.overdue);
    final td = g((t) => t.due == today);
    final week = g((t) => t.due != null && t.due!.compareTo(today) > 0 && t.due!.diff(today) <= 7);
    final later = g((t) => t.due == null || t.due!.diff(today) > 7);
    Widget group(String label, List<Task> list, {Color? color}) => list.isEmpty
        ? const SizedBox.shrink()
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 6), child: Text('$label · ${list.length}', style: TextStyle(fontWeight: FontWeight.w700, color: color))),
            Card(child: Column(children: [for (final t in list) TaskTile(t)])),
          ]);
    if (open.isEmpty && closed.isEmpty) {
      return EmptyState(icon: Icons.checklist, text: s.allClear);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
      group(s.overdue, overdue, color: const Color(0xFFE6563F)),
      group(s.today, td),
      group(s.thisWeek, week),
      group(s.later, later),
      if (closed.isNotEmpty)
        ExpansionTile(
          title: Text('${s.done} · ${closed.length}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          children: [for (final t in closed.reversed.take(30)) TaskTile(t)],
        ),
    ]);
  }
}

/// 一行日程:时间 · 标题 · 地点 · 孩子色点 · 谁去
class EventRow extends StatelessWidget {
  final Event e;
  const EventRow(this.e, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.read<AppState>();
    final who = st.member(e.assigneeId)?.name;
    return InkWell(
      onTap: () => showEventEditor(context, event: e),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 5), child: ChildDot(e.childId)),
          const SizedBox(width: 8),
          SizedBox(width: 44, child: Text(e.start == null ? s.t('全天', 'All day') : s.tod(e.start), style: Theme.of(context).textTheme.labelMedium)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(e.title, style: TextStyle(fontWeight: FontWeight.w600, decoration: e.done ? TextDecoration.lineThrough : null), overflow: TextOverflow.ellipsis)),
                if (e.rescheduled) ...[
                  const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(6)), child: Text(s.rescheduledTag, style: const TextStyle(fontSize: 10, color: Color(0xFF7A4B00)))),
                ],
              ]),
              if (e.location.isNotEmpty || who != null)
                Text([if (e.location.isNotEmpty) e.location, if (who != null) '👤 $who'].join(' · '), style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// 一行待办:类型图标 · 标题 · 截止 · 勾选
class TaskTile extends StatelessWidget {
  final Task t;
  final bool compact;
  const TaskTile(this.t, {super.key, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.read<AppState>();
    final who = st.member(t.assigneeId)?.name;
    final dueText = t.due == null ? s.noDue : s.dueIn(t.due!);
    final sub = [
      dueText,
      if (t.amount != null) '¥${t.amount!.toStringAsFixed(t.amount! % 1 == 0 ? 0 : 2)}',
      if (who != null) '👤 $who',
      if (!t.isOpen) s.status(t.status),
    ].join(' · ');
    return ListTile(
      dense: compact,
      leading: Icon(kindIcon(t.kind), color: kindColor(t.kind)),
      title: Text(t.title, style: TextStyle(decoration: t.isOpen ? null : TextDecoration.lineThrough, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(sub, style: TextStyle(color: t.overdue ? const Color(0xFFE6563F) : null), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (t.imageB64 != null) GestureDetector(onTap: () => showFullImage(context, t.imageB64!), child: SizedBox(width: 32, height: 32, child: b64Image(t.imageB64!))),
        if (!compact) ...[const SizedBox(width: 6), ChildTag(t.childId)],
        Checkbox(
          value: !t.isOpen,
          onChanged: (v) => st.upsertTask(t.copyWith(status: v == true ? (t.kind == TaskKind.sign ? TaskStatus.submitted : TaskStatus.done) : TaskStatus.open)),
        ),
      ]),
      onTap: () => showTaskEditor(context, task: t),
    );
  }
}

// ---------- 日程编辑 ----------

Future<void> showEventEditor(BuildContext context, {Event? event, Day? day}) async {
  final s = S.read(context);
  final st = context.read<AppState>();
  final title = TextEditingController(text: event?.title ?? '');
  final loc = TextEditingController(text: event?.location ?? '');
  final note = TextEditingController(text: event?.note ?? '');
  var childId = event?.childId ?? (st.filterChildId.isNotEmpty ? st.filterChildId : (st.children.length == 1 ? st.children.first.id : ''));
  var d = event?.day ?? day ?? Day.today();
  var start = event?.start;
  var end = event?.end;
  var who = event?.assigneeId ?? '';
  var done = event?.done ?? false;
  await showEditorSheet(
    context,
    title: event == null ? s.newEvent : s.event,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: title, decoration: InputDecoration(labelText: s.title), autofocus: event == null),
        const SizedBox(height: 12),
        ChildPicker(value: childId, onChanged: (v) => setS(() => childId = v)),
        const SizedBox(height: 12),
        DayField(label: s.date, value: d, onChanged: (v) => setS(() => d = v ?? d)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TimeField(label: s.time, value: start, onChanged: (v) => setS(() => start = v))),
          const SizedBox(width: 8),
          Expanded(child: TimeField(label: s.endTime, value: end, onChanged: (v) => setS(() => end = v))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: loc, decoration: InputDecoration(labelText: s.location)),
        const SizedBox(height: 12),
        MemberPicker(value: who, onChanged: (v) => setS(() => who = v)),
        const SizedBox(height: 12),
        TextField(controller: note, decoration: InputDecoration(labelText: s.note), maxLines: 3),
        if (event != null) SwitchListTile(value: done, onChanged: (v) => setS(() => done = v), title: Text(s.done), contentPadding: EdgeInsets.zero),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            if (title.text.trim().isEmpty) return;
            final e = Event(
              id: event?.id ?? newId(),
              childId: childId,
              title: title.text.trim(),
              day: d,
              start: start,
              end: end,
              location: loc.text.trim(),
              note: note.text.trim(),
              assigneeId: who,
              noticeId: event?.noticeId ?? '',
              done: done,
              rescheduled: event?.rescheduled ?? false,
            );
            st.upsertEvent(e);
            Navigator.pop(c);
          },
          child: Text(s.save),
        ),
        if (event != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => openUrl(googleCalendarUrl(event, who: st.child(event.childId)?.name ?? '')),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(s.addToGoogle),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => exportText('event.ics', 'text/calendar', buildIcs([event], childName: (id) => st.child(id)?.name ?? '')),
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('.ics'),
            ),
          ]),
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Theme.of(c).colorScheme.error),
            onPressed: () async {
              if (await confirmDialog(c, '${s.delete}?')) {
                st.removeEvent(event.id);
                if (c.mounted) Navigator.pop(c);
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: Text(s.delete),
          ),
        ],
      ]),
    ),
  );
}

// ---------- 待办编辑 ----------

Future<void> showTaskEditor(BuildContext context, {Task? task, TaskKind? kind, String? imageB64}) async {
  final s = S.read(context);
  final st = context.read<AppState>();
  final title = TextEditingController(text: task?.title ?? '');
  final amount = TextEditingController(text: task?.amount == null ? '' : task!.amount!.toStringAsFixed(task.amount! % 1 == 0 ? 0 : 2));
  var childId = task?.childId ?? (st.filterChildId.isNotEmpty ? st.filterChildId : (st.children.isNotEmpty ? st.children.first.id : ''));
  var k = task?.kind ?? kind ?? TaskKind.sign;
  Day? due = task?.due ?? Day.today().add(2);
  var who = task?.assigneeId ?? '';
  var status = task?.status ?? TaskStatus.open;
  String? img = task?.imageB64 ?? imageB64;
  await showEditorSheet(
    context,
    title: task == null ? s.newTask : s.viewTasks,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedButton<TaskKind>(
          segments: [for (final x in TaskKind.values) ButtonSegment(value: x, label: Text(s.kind(x)), icon: Icon(kindIcon(x)))],
          selected: {k},
          onSelectionChanged: (v) => setS(() => k = v.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 12),
        TextField(controller: title, decoration: InputDecoration(labelText: s.title), autofocus: task == null),
        const SizedBox(height: 12),
        ChildPicker(value: childId, onChanged: (v) => setS(() => childId = v), allowFamily: false),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: DayField(label: s.dueDate, value: due, clearable: true, onChanged: (v) => setS(() => due = v))),
          if (k == TaskKind.pay) ...[
            const SizedBox(width: 8),
            SizedBox(width: 110, child: TextField(controller: amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: s.amount))),
          ],
        ]),
        const SizedBox(height: 12),
        MemberPicker(value: who, onChanged: (v) => setS(() => who = v)),
        const SizedBox(height: 12),
        if (img != null) ...[
          GestureDetector(onTap: () => showFullImage(c, img!), child: b64Image(img!, height: 160)),
          const SizedBox(height: 8),
        ],
        Row(children: [
          OutlinedButton.icon(onPressed: () async { final b = await pickImageB64(c, camera: true); if (b != null) setS(() => img = b); }, icon: const Icon(Icons.photo_camera_outlined), label: Text(s.takePhoto)),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: () async { final b = await pickImageB64(c); if (b != null) setS(() => img = b); }, icon: const Icon(Icons.photo_library_outlined), label: Text(s.pickPhoto)),
        ]),
        if (task != null) ...[
          const SizedBox(height: 12),
          SegmentedButton<TaskStatus>(
            segments: [
              ButtonSegment(value: TaskStatus.open, label: Text(s.status(TaskStatus.open))),
              ButtonSegment(value: TaskStatus.done, label: Text(k == TaskKind.sign ? s.markSigned : s.status(TaskStatus.done))),
              if (k == TaskKind.sign) ButtonSegment(value: TaskStatus.submitted, label: Text(s.status(TaskStatus.submitted))),
            ],
            selected: {status},
            onSelectionChanged: (v) => setS(() => status = v.first),
            showSelectedIcon: false,
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            if (title.text.trim().isEmpty || childId.isEmpty) return;
            st.upsertTask(Task(
              id: task?.id ?? newId(),
              childId: childId,
              kind: k,
              title: title.text.trim(),
              due: due,
              amount: double.tryParse(amount.text),
              assigneeId: who,
              noticeId: task?.noticeId ?? '',
              imageB64: img,
              status: status,
              createdAt: task?.createdAt ?? DateTime.now(),
            ));
            Navigator.pop(c);
          },
          child: Text(s.save),
        ),
        if (task != null)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Theme.of(c).colorScheme.error),
            onPressed: () async {
              if (await confirmDialog(c, '${s.delete}?')) {
                st.removeTask(task.id);
                if (c.mounted) Navigator.pop(c);
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: Text(s.delete),
          ),
      ]),
    ),
  );
}
