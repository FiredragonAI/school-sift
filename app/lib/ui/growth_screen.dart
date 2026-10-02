// 成长页:成绩(按科目折线 + 班均对比)/ 学习记录(每日打卡)/ 签字袋(纸质单据追踪)。

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../store/app_state.dart';
import 'calendar_screen.dart';
import 'widgets.dart';

class GrowthScreen extends StatefulWidget {
  const GrowthScreen({super.key});
  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen> with SingleTickerProviderStateMixin {
  late final TabController tab = TabController(length: 3, vsync: this);
  String? childId;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    if (st.children.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(s.tabGrowth)),
        body: EmptyState(icon: Icons.child_care, text: s.pleaseAddChild, action: FilledButton(onPressed: () => showChildEditor(context), child: Text(s.startFresh))),
      );
    }
    final cid = (childId != null && st.child(childId!) != null)
        ? childId!
        : (st.filterChildId.isNotEmpty ? st.filterChildId : st.children.first.id);
    final child = st.child(cid)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.tabGrowth),
        actions: [
          if (st.children.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: DropdownButton<String>(
                value: cid,
                underline: const SizedBox(),
                items: [for (final c in st.children) DropdownMenuItem(value: c.id, child: Row(mainAxisSize: MainAxisSize.min, children: [ChildDot(c.id), const SizedBox(width: 6), Text(c.name)]))],
                onChanged: (v) => setState(() => childId = v),
              ),
            ),
        ],
        bottom: TabBar(controller: tab, tabs: [Tab(text: s.grades), Tab(text: s.studyLog), Tab(text: s.papers)]),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: tab,
        builder: (_, __) => FloatingActionButton(
          heroTag: "fab_growth",
          onPressed: () {
            switch (tab.index) {
              case 0:
                showGradeEditor(context, childId: cid);
              case 1:
                showStudyLogEditor(context, childId: cid);
              default:
                showTaskEditor(context, kind: TaskKind.sign);
            }
          },
          child: Icon(tab.index == 2 ? Icons.add_a_photo_outlined : Icons.add),
        ),
      ),
      body: TabBarView(controller: tab, children: [
        _GradesTab(child: child),
        _StudyTab(child: child),
        _PapersTab(child: child),
      ]),
    );
  }
}

// ---------- 成绩 ----------

class _GradesTab extends StatelessWidget {
  final Child child;
  const _GradesTab({required this.child});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    final all = st.gradesOf(child.id);
    if (all.isEmpty) return EmptyState(icon: Icons.grade_outlined, text: s.noGrades);
    final subjects = all.map((g) => g.subject).toSet().toList();
    final colors = [const Color(0xFF2E6BE6), const Color(0xFFE6563F), const Color(0xFF2DA36A), const Color(0xFFB45CFF), const Color(0xFFE09A1B), const Color(0xFF12A5B8)];
    final recent = all.reversed.take(10).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
      // 概览卡
      Row(children: [
        for (var i = 0; i < subjects.length && i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _SubjectCard(subject: subjects[i], grades: all.where((g) => g.subject == subjects[i]).toList(), color: colors[i % colors.length])),
        ],
      ]),
      SectionTitle(s.trend),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: SizedBox(height: 220, child: _TrendChart(all: all, subjects: subjects, colors: colors)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(spacing: 12, children: [
          for (var i = 0; i < subjects.length; i++)
            Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)), const SizedBox(width: 4), Text(subjects[i], style: Theme.of(context).textTheme.labelMedium)]),
        ]),
      ),
      SectionTitle(s.recent),
      Card(
        child: Column(children: [
          for (final g in recent)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: colors[subjects.indexOf(g.subject) % colors.length].withValues(alpha: 0.15),
                child: Text(g.subject.characters.first, style: TextStyle(color: colors[subjects.indexOf(g.subject) % colors.length], fontWeight: FontWeight.w700)),
              ),
              title: Text('${g.subject} · ${g.name}'),
              subtitle: Text('${s.md(g.day)}${g.classAvg != null ? ' · ${s.classAvg} ${_n(g.classAvg!)}' : ''}${g.note.isNotEmpty ? ' · ${g.note}' : ''}'),
              trailing: Text(g.full == 100 ? _n(g.score) : '${_n(g.score)}/${_n(g.full)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: g.pct >= 90 ? const Color(0xFF2DA36A) : g.pct < 70 ? const Color(0xFFE6563F) : null)),
              onTap: () => showGradeEditor(context, childId: child.id, grade: g),
            ),
        ]),
      ),
    ]);
  }
}

String _n(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

class _SubjectCard extends StatelessWidget {
  final String subject;
  final List<Grade> grades;
  final Color color;
  const _SubjectCard({required this.subject, required this.grades, required this.color});
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final avg = grades.map((g) => g.pct).reduce((a, b) => a + b) / grades.length;
    final last = grades.last;
    final prev = grades.length >= 2 ? grades[grades.length - 2] : null;
    final delta = prev == null ? null : last.pct - prev.pct;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(subject, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(_n(last.pct), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          Text(
            '${s.avg} ${_n(avg)}${delta == null ? '' : '  ${delta >= 0 ? '▲' : '▼'}${_n(delta.abs())}'}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: delta == null ? null : (delta >= 0 ? const Color(0xFF2DA36A) : const Color(0xFFE6563F))),
          ),
        ]),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<Grade> all;
  final List<String> subjects;
  final List<Color> colors;
  const _TrendChart({required this.all, required this.subjects, required this.colors});
  @override
  Widget build(BuildContext context) {
    final first = all.first.day;
    final span = (all.last.day.diff(first)).clamp(1, 100000).toDouble();
    final avgPoints = all.where((g) => g.classAvg != null).toList();
    return LineChart(LineChartData(
      minY: 50,
      maxY: 100,
      minX: 0,
      maxX: span,
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 10, getDrawingHorizontalLine: (_) => FlLine(color: Theme.of(context).dividerColor.withValues(alpha: 0.4), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 10, getTitlesWidget: (v, _) => v == v.roundToDouble() ? Text(v.toInt().toString(), style: Theme.of(context).textTheme.labelSmall) : const SizedBox())),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: span / 3 < 1 ? 1 : span / 3,
            getTitlesWidget: (v, _) {
              final d = first.add(v.round());
              return Padding(padding: const EdgeInsets.only(top: 4), child: Text('${d.m}/${d.d}', style: Theme.of(context).textTheme.labelSmall));
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipItems: (spots) => [for (final sp in spots) LineTooltipItem(_n(sp.y), TextStyle(color: sp.bar.color, fontWeight: FontWeight.w700))])),
      lineBarsData: [
        for (var i = 0; i < subjects.length; i++)
          LineChartBarData(
            spots: [for (final g in all.where((g) => g.subject == subjects[i])) FlSpot(g.day.diff(first).toDouble(), g.pct)],
            color: colors[i % colors.length],
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
          ),
        if (avgPoints.length >= 2)
          LineChartBarData(
            spots: [for (final g in avgPoints) FlSpot(g.day.diff(first).toDouble(), g.classAvg! / g.full * 100)],
            color: Colors.grey,
            dashArray: [6, 4],
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
          ),
      ],
    ));
  }
}

Future<void> showGradeEditor(BuildContext context, {String? childId, Grade? grade}) async {
  final s = S.read(context);
  final st = context.read<AppState>();
  if (st.children.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.pleaseAddChild)));
    return;
  }
  var cid = grade?.childId ?? childId ?? (st.filterChildId.isNotEmpty ? st.filterChildId : st.children.first.id);
  final subject = TextEditingController(text: grade?.subject ?? '');
  final name = TextEditingController(text: grade?.name ?? '');
  final score = TextEditingController(text: grade == null ? '' : _n(grade.score));
  final full = TextEditingController(text: grade == null ? '100' : _n(grade.full));
  final avg = TextEditingController(text: grade?.classAvg == null ? '' : _n(grade!.classAvg!));
  final note = TextEditingController(text: grade?.note ?? '');
  var day = grade?.day ?? Day.today();
  final subjectsUsed = st.grades.map((g) => g.subject).toSet().toList();
  final defaults = s.zh ? ['语文', '数学', '英语', '科学'] : ['Math', 'English', 'Science', 'Reading'];
  final chips = {...subjectsUsed, ...defaults}.toList();
  await showEditorSheet(
    context,
    title: grade == null ? '${s.add} ${s.grades}' : s.grades,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ChildPicker(value: cid, onChanged: (v) => setS(() => cid = v), allowFamily: false),
        const SizedBox(height: 12),
        TextField(controller: subject, decoration: InputDecoration(labelText: s.subject)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, children: [for (final x in chips) ActionChip(label: Text(x), visualDensity: VisualDensity.compact, onPressed: () => setS(() => subject.text = x))]),
        const SizedBox(height: 12),
        TextField(controller: name, decoration: InputDecoration(labelText: s.testName, hintText: s.t('第三单元测 / 听写 / 月考', 'Unit 3 quiz / spelling / midterm'))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: score, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: s.score), autofocus: grade == null)),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: full, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: s.fullScore))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: avg, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: s.classAvg))),
        ]),
        const SizedBox(height: 12),
        DayField(label: s.date, value: day, onChanged: (v) => setS(() => day = v ?? day)),
        const SizedBox(height: 12),
        TextField(controller: note, decoration: InputDecoration(labelText: s.note)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            final sc = double.tryParse(score.text);
            if (sc == null || subject.text.trim().isEmpty) return;
            st.upsertGrade(Grade(
              id: grade?.id ?? newId(),
              childId: cid,
              subject: subject.text.trim(),
              name: name.text.trim().isEmpty ? s.t('测验', 'Test') : name.text.trim(),
              day: day,
              score: sc,
              full: double.tryParse(full.text) ?? 100,
              classAvg: double.tryParse(avg.text),
              note: note.text.trim(),
            ));
            Navigator.pop(c);
          },
          child: Text(s.save),
        ),
        if (grade != null)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Theme.of(c).colorScheme.error),
            onPressed: () async {
              if (await confirmDialog(c, '${s.delete}?')) {
                st.removeGrade(grade.id);
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

// ---------- 学习记录 ----------

class _StudyTab extends StatelessWidget {
  final Child child;
  const _StudyTab({required this.child});
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    final logs = st.logsOf(child.id);
    final today = Day.today();
    final todayLog = st.logOn(child.id, today);
    final last14 = [for (var i = 13; i >= 0; i--) today.add(-i)];
    final recent = logs.where((l) => l.day.diff(today) >= -13).toList();
    final hwRate = recent.isEmpty ? 0 : recent.where((l) => l.homeworkDone).length * 100 ~/ recent.length;
    final readAvg = recent.isEmpty ? 0 : recent.map((l) => l.readingMinutes).reduce((a, b) => a + b) ~/ recent.length;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
      Card(
        color: todayLog == null ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5) : null,
        child: ListTile(
          leading: Icon(todayLog == null ? Icons.edit_note : Icons.check_circle, color: todayLog == null ? null : const Color(0xFF2DA36A)),
          title: Text(todayLog == null ? s.t('今天还没记录', 'No log for today yet') : s.t('今天已记录', 'Today logged')),
          subtitle: Text('${s.streak} ${st.streak(child.id)} ${s.days}'),
          trailing: FilledButton.tonal(onPressed: () => showStudyLogEditor(context, childId: child.id), child: Text(todayLog == null ? s.qaLog : s.edit)),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _Stat(label: s.homeworkDone, value: '$hwRate%', color: const Color(0xFF2E6BE6))),
        const SizedBox(width: 8),
        Expanded(child: _Stat(label: s.readingMin, value: '$readAvg', color: const Color(0xFF2DA36A))),
        const SizedBox(width: 8),
        Expanded(child: _Stat(label: s.streak, value: '${st.streak(child.id)}', color: const Color(0xFFE09A1B))),
      ]),
      SectionTitle(s.last14),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              for (final d in last14)
                Expanded(
                  child: Builder(builder: (_) {
                    final l = st.logOn(child.id, d);
                    final h = l == null ? 4.0 : (8 + (l.readingMinutes.clamp(0, 60)) * 1.2);
                    return GestureDetector(
                      onTap: () => showStudyLogEditor(context, childId: child.id, day: d),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Container(
                          height: h,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: l == null ? Theme.of(context).dividerColor : (l.homeworkDone ? const Color(0xFF2DA36A) : const Color(0xFFE09A1B)),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('${d.d}', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9)),
                      ]),
                    );
                  }),
                ),
            ]),
            const SizedBox(height: 6),
            Text(s.t('柱高 = 阅读分钟;绿 = 作业完成,黄 = 未完成', 'Bar = reading minutes; green = homework done, amber = not'), style: Theme.of(context).textTheme.labelSmall),
          ]),
        ),
      ),
      SectionTitle(s.recent),
      Card(
        child: Column(children: [
          for (final l in logs.reversed.take(14))
            ListTile(
              dense: true,
              leading: Text('⭐' * l.focus, style: const TextStyle(fontSize: 10)),
              title: Text('${s.relative(l.day)} · ${l.homeworkDone ? '✓ ' : '✗ '}${s.homeworkDone} · ${l.readingMinutes} min'),
              subtitle: l.note.isEmpty ? null : Text(l.note),
              onTap: () => showStudyLogEditor(context, childId: child.id, day: l.day),
            ),
        ]),
      ),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: color)),
          Text(label, style: Theme.of(context).textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

Future<void> showStudyLogEditor(BuildContext context, {String? childId, Day? day}) async {
  final s = S.read(context);
  final st = context.read<AppState>();
  if (st.children.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.pleaseAddChild)));
    return;
  }
  var cid = childId ?? (st.filterChildId.isNotEmpty ? st.filterChildId : st.children.first.id);
  final d = day ?? Day.today();
  final existing = st.logOn(cid, d);
  var hw = existing?.homeworkDone ?? true;
  var minutes = existing?.readingMinutes ?? 20;
  var focus = existing?.focus ?? 3;
  final note = TextEditingController(text: existing?.note ?? '');
  await showEditorSheet(
    context,
    title: '${s.studyLog} · ${s.relative(d)}',
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ChildPicker(value: cid, onChanged: (v) => setS(() => cid = v), allowFamily: false),
        const SizedBox(height: 8),
        SwitchListTile(value: hw, onChanged: (v) => setS(() => hw = v), title: Text(s.homeworkDone), contentPadding: EdgeInsets.zero),
        Text('${s.readingMin}: $minutes'),
        Slider(value: minutes.toDouble(), min: 0, max: 120, divisions: 24, label: '$minutes', onChanged: (v) => setS(() => minutes = v.round())),
        Text(s.focus),
        Row(children: [
          for (var i = 1; i <= 5; i++)
            IconButton(onPressed: () => setS(() => focus = i), icon: Icon(i <= focus ? Icons.star : Icons.star_border, color: const Color(0xFFE09A1B))),
        ]),
        TextField(controller: note, decoration: InputDecoration(labelText: s.logNote), maxLines: 2),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            st.upsertLog(StudyLog(id: existing?.id ?? newId(), childId: cid, day: d, homeworkDone: hw, readingMinutes: minutes, focus: focus, note: note.text.trim()));
            Navigator.pop(c);
          },
          child: Text(s.save),
        ),
      ]),
    ),
  );
}

// ---------- 签字袋 ----------

class _PapersTab extends StatelessWidget {
  final Child child;
  const _PapersTab({required this.child});
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    final list = st.tasks.where((t) => t.kind == TaskKind.sign && t.childId == child.id).toList()
      ..sort((a, b) {
        if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
        return (a.due?.key ?? '9999').compareTo(b.due?.key ?? '9999');
      });
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.draw_outlined,
        text: s.papersEmpty,
        action: FilledButton.icon(
          onPressed: () async {
            final b = await pickImageB64(context, camera: true);
            if (context.mounted) showTaskEditor(context, kind: TaskKind.sign, imageB64: b);
          },
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(s.qaPhoto),
        ),
      );
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
      Text(s.t('流程:待签 → 已签字 → 已交回学校。勾选 = 已交回。', 'Flow: to sign → signed → returned. Checkbox = returned.'), style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      Card(child: Column(children: [for (final t in list) TaskTile(t)])),
    ]);
  }
}
