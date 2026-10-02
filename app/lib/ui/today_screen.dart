// 今日页:一眼看完"今天和明天 + 要家长办的事 + 待确认的通知"。
// 这是对研究里"47 条通知只有一个人在管"的回答:信息已经被压成行动清单。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../store/app_state.dart';
import 'calendar_screen.dart';
import 'growth_screen.dart';
import 'inbox_screen.dart';
import 'widgets.dart';

class TodayScreen extends StatelessWidget {
  final ValueChanged<int> onGo;
  const TodayScreen({super.key, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    final today = Day.today();
    final todayEvents = st.eventsOn(today);
    final tomorrowEvents = st.eventsOn(today.add(1));
    final open = st.openTasks;
    final overdue = open.where((t) => t.overdue).length;
    final pendingNotices = st.visibleNotices.where((n) => !n.processed).toList();
    final hour = DateTime.now().hour;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const AppLogo(size: 30),
          const SizedBox(width: 10),
          Text(s.appName),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(s.mdw(today), style: Theme.of(context).textTheme.bodyMedium)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              '${s.greeting(hour)}${overdue > 0 ? s.t(',有 $overdue 件事逾期了', ', $overdue item${overdue > 1 ? 's' : ''} overdue') : ''}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const ChildFilterBar(),

          // 快捷入口
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              _Quick(icon: Icons.content_paste_go, label: s.qaPaste, color: const Color(0xFF2E6BE6), onTap: () => showNoticeEditor(context)),
              const SizedBox(width: 8),
              _Quick(icon: Icons.photo_camera_outlined, label: s.qaPhoto, color: const Color(0xFFE6563F), onTap: () => showNoticeEditor(context, camera: true)),
              const SizedBox(width: 8),
              _Quick(icon: Icons.grade_outlined, label: s.qaGrade, color: const Color(0xFF2DA36A), onTap: () => showGradeEditor(context)),
              const SizedBox(width: 8),
              _Quick(icon: Icons.edit_note, label: s.qaLog, color: const Color(0xFFE09A1B), onTap: () => showStudyLogEditor(context)),
            ]),
          ),

          if (pendingNotices.isNotEmpty) ...[
            SectionTitle(s.unprocessed, trailing: TextButton(onPressed: () => onGo(1), child: Text(s.tabInbox))),
            for (final n in pendingNotices.take(3))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Card(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                  child: ListTile(
                    leading: const Icon(Icons.mark_email_unread_outlined),
                    title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(n.body.replaceAll('\n', ' '), maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: ChildTag(n.childId),
                    onTap: () => openNotice(context, n),
                  ),
                ),
              ),
          ],

          SectionTitle(s.briefTitle, trailing: TextButton(onPressed: () => onGo(2), child: Text(s.tabCalendar))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(children: [
                  _DayBlock(label: s.today, events: todayEvents),
                  const Divider(height: 16, indent: 16, endIndent: 16),
                  _DayBlock(label: s.tomorrow, events: tomorrowEvents),
                ]),
              ),
            ),
          ),

          SectionTitle(s.needsYou, trailing: TextButton(onPressed: () => onGo(2), child: Text(s.viewTasks))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: open.isEmpty
                  ? ListTile(leading: const Icon(Icons.check_circle, color: Color(0xFF2DA36A)), title: Text(s.allClear))
                  : Column(children: [
                      for (final t in open.take(6)) TaskTile(t, compact: true),
                      if (open.length > 6)
                        TextButton(onPressed: () => onGo(2), child: Text(s.t('还有 ${open.length - 6} 项', '${open.length - 6} more'))),
                    ]),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Quick({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

class _DayBlock extends StatelessWidget {
  final String label;
  final List<Event> events;
  const _DayBlock({required this.label, required this.events});
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 56, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(
          child: events.isEmpty
              ? Text(s.nothingScheduled, style: TextStyle(color: Theme.of(context).colorScheme.outline))
              : Column(children: [for (final e in events) EventRow(e)]),
        ),
      ]),
    );
  }
}
