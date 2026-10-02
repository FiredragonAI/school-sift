// 通知收件箱:原文永远可搜(ParentSquare 被骂最多的一点),
// 每条通知 → 识别 → 家长核对 → 写入日程/待办。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/notice_parser.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../store/app_state.dart';
import 'widgets.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    final list = st.visibleNotices.where((n) {
      if (q.isEmpty) return true;
      final k = q.toLowerCase();
      return n.title.toLowerCase().contains(k) || n.body.toLowerCase().contains(k);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text(s.tabInbox)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "fab_inbox",
        onPressed: () => showNoticeEditor(context),
        icon: const Icon(Icons.add),
        label: Text(s.newNotice),
      ),
      body: Column(children: [
        const ChildFilterBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: s.search, filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
            onChanged: (v) => setState(() => q = v.trim()),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? EmptyState(icon: Icons.inbox_outlined, text: s.inboxEmpty)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: list.length,
                  itemBuilder: (c, i) {
                    final n = list[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: n.imageB64 != null
                              ? SizedBox(width: 44, height: 44, child: b64Image(n.imageB64!))
                              : CircleAvatar(
                                  backgroundColor: n.processed ? Theme.of(c).colorScheme.surfaceContainerHighest : Theme.of(c).colorScheme.primaryContainer,
                                  child: Icon(n.processed ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined, size: 20),
                                ),
                          title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: n.processed ? FontWeight.normal : FontWeight.w700)),
                          subtitle: Text(n.body.replaceAll('\n', ' '), maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                            ChildTag(n.childId),
                            const SizedBox(height: 4),
                            Text(_ago(s, n.receivedAt), style: Theme.of(c).textTheme.labelSmall),
                          ]),
                          onTap: () => openNotice(context, n),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  String _ago(S s, DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return s.t('${d.inMinutes} 分钟前', '${d.inMinutes}m ago');
    if (d.inHours < 24) return s.t('${d.inHours} 小时前', '${d.inHours}h ago');
    return s.t('${d.inDays} 天前', '${d.inDays}d ago');
  }
}

// ---------- 新建通知 ----------

Future<void> showNoticeEditor(BuildContext context, {bool camera = false}) async {
  final s = S.read(context);
  final st = context.read<AppState>();
  if (st.children.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.pleaseAddChild)));
    return;
  }
  String? img;
  if (camera) {
    img = await pickImageB64(context, camera: true);
    if (!context.mounted) return;
  }
  final title = TextEditingController();
  final body = TextEditingController();
  var childId = st.filterChildId.isNotEmpty ? st.filterChildId : st.children.first.id;
  await showEditorSheet(
    context,
    title: s.newNotice,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ChildPicker(value: childId, onChanged: (v) => setS(() => childId = v)),
        const SizedBox(height: 12),
        TextField(controller: title, decoration: InputDecoration(labelText: s.title)),
        const SizedBox(height: 12),
        TextField(
          controller: body,
          minLines: 6,
          maxLines: 14,
          decoration: InputDecoration(labelText: s.noticeBody, hintText: s.noticeHint, alignLabelWithHint: true),
        ),
        const SizedBox(height: 12),
        if (img != null) ...[
          GestureDetector(onTap: () => showFullImage(c, img!), child: b64Image(img!, height: 160)),
          const SizedBox(height: 6),
          Text(s.ocrNote, style: Theme.of(c).textTheme.bodySmall),
          const SizedBox(height: 8),
        ],
        Row(children: [
          OutlinedButton.icon(
            onPressed: () async {
              final b = await pickImageB64(c, camera: true);
              if (b != null) setS(() => img = b);
            },
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(s.takePhoto),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final b = await pickImageB64(c);
              if (b != null) setS(() => img = b);
            },
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(s.pickPhoto),
          ),
        ]),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () {
            if (body.text.trim().isEmpty && img == null) return;
            final n = Notice(
              id: newId(),
              childId: childId,
              title: title.text.trim().isEmpty ? NoticeParser().parse(body.text, titleHint: null).title : title.text.trim(),
              body: body.text.trim(),
              source: img != null ? 'photo' : 'paste',
              receivedAt: DateTime.now(),
              imageB64: img,
            );
            st.addNotice(n);
            Navigator.pop(c);
            openNotice(context, n, review: n.body.isNotEmpty);
          },
          icon: const Icon(Icons.auto_awesome),
          label: Text(s.extract),
        ),
      ]),
    ),
  );
}

// ---------- 通知详情 / 识别核对 ----------

void openNotice(BuildContext context, Notice n, {bool review = false}) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => NoticeDetailPage(noticeId: n.id, startReview: review || !n.processed)));
}

class NoticeDetailPage extends StatefulWidget {
  final String noticeId;
  final bool startReview;
  const NoticeDetailPage({super.key, required this.noticeId, this.startReview = false});
  @override
  State<NoticeDetailPage> createState() => _NoticeDetailPageState();
}

class _NoticeDetailPageState extends State<NoticeDetailPage> {
  Extraction? ex;
  Map<ExtractedItem, String> assignee = {};

  @override
  void initState() {
    super.initState();
    if (widget.startReview) WidgetsBinding.instance.addPostFrameCallback((_) => _extract());
  }

  void _extract() {
    final st = context.read<AppState>();
    final n = st.notices.firstWhere((e) => e.id == widget.noticeId);
    if (n.body.trim().isEmpty) return;
    setState(() => ex = NoticeParser().parse(n.body, titleHint: n.title));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    final n = st.notices.where((e) => e.id == widget.noticeId).firstOrNull;
    if (n == null) return const Scaffold(body: SizedBox());
    final linkedEvents = st.events.where((e) => e.noticeId == n.id).toList();
    final linkedTasks = st.tasks.where((e) => e.noticeId == n.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirmDialog(context, '${s.delete}?')) {
                st.removeNotice(n.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        Row(children: [
          ChildTag(n.childId),
          const SizedBox(width: 8),
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(n.processed ? s.processed : s.pending),
            backgroundColor: n.processed ? null : Theme.of(context).colorScheme.primaryContainer,
          ),
          const Spacer(),
          Text('${s.source}: ${n.source == 'photo' ? s.sourcePhoto : n.source == 'demo' ? s.sourceDemo : s.sourcePaste}', style: Theme.of(context).textTheme.bodySmall),
        ]),
        const SizedBox(height: 12),
        if (n.imageB64 != null) ...[
          GestureDetector(onTap: () => showFullImage(context, n.imageB64!), child: b64Image(n.imageB64!, height: 200)),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.original, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              SelectableText(n.body.isEmpty ? '—' : n.body, style: const TextStyle(height: 1.5)),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        if (ex == null) ...[
          if (linkedEvents.isNotEmpty || linkedTasks.isNotEmpty) ...[
            Text(s.t('已生成', 'Created'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            for (final e in linkedEvents)
              ListTile(dense: true, leading: const Icon(Icons.event), title: Text(e.title), subtitle: Text('${s.mdw(e.day)} ${s.tod(e.start)}')),
            for (final t in linkedTasks)
              ListTile(dense: true, leading: Icon(kindIcon(t.kind), color: kindColor(t.kind)), title: Text(t.title), subtitle: Text(t.due == null ? s.noDue : s.dueIn(t.due!))),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(onPressed: n.body.isEmpty ? null : _extract, icon: const Icon(Icons.auto_awesome), label: Text(n.processed ? s.reExtract : s.extract)),
        ] else
          _ReviewPanel(
            notice: n,
            ex: ex!,
            onCancel: () => setState(() => ex = null),
            onCommit: (evs, ts) {
              st.commitExtraction(n, evs, ts, reschedule: ex!.reschedule);
              setState(() => ex = null);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('已写入 ${evs.length} 条日程、${ts.length} 项待办', 'Added ${evs.length} events, ${ts.length} tasks'))));
            },
          ),
      ]),
    );
  }
}

class _ReviewPanel extends StatefulWidget {
  final Notice notice;
  final Extraction ex;
  final VoidCallback onCancel;
  final void Function(List<Event>, List<Task>) onCommit;
  const _ReviewPanel({required this.notice, required this.ex, required this.onCancel, required this.onCommit});
  @override
  State<_ReviewPanel> createState() => _ReviewPanelState();
}

class _ReviewPanelState extends State<_ReviewPanel> {
  late List<ExtractedItem> items = List.of(widget.ex.items);
  final Map<ExtractedItem, String> who = {};

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.extractTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      if (widget.ex.reschedule)
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.warning_amber, color: Color(0xFFE09A1B)),
            const SizedBox(width: 8),
            Expanded(child: Text(s.rescheduleWarn, style: const TextStyle(color: Color(0xFF7A4B00), fontSize: 13))),
          ]),
        ),
      if (items.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(s.extractEmpty)),
      for (final it in items) _ItemCard(it, who: who[it] ?? '', onWho: (v) => setState(() => who[it] = v), onChanged: () => setState(() {}), onDelete: () => setState(() => items.remove(it))),
      TextButton.icon(
        onPressed: () => setState(() => items.add(ExtractedItem(type: ItemType.event, title: widget.notice.title, day: Day.today().add(1), confidence: 1, evidence: ''))),
        icon: const Icon(Icons.add),
        label: Text(s.addItem),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: widget.onCancel, child: Text(s.saveRaw))),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: () {
              final evs = <Event>[];
              final ts = <Task>[];
              for (final it in items.where((e) => e.keep)) {
                if (it.type == ItemType.event) {
                  if (it.day == null) continue;
                  evs.add(Event(id: newId(), childId: widget.notice.childId, title: it.title, day: it.day!, start: it.start, end: it.end, location: it.location, assigneeId: who[it] ?? '', noticeId: widget.notice.id));
                } else {
                  final kind = it.type == ItemType.sign ? TaskKind.sign : it.type == ItemType.pay ? TaskKind.pay : it.type == ItemType.bring ? TaskKind.bring : TaskKind.other;
                  ts.add(Task(id: newId(), childId: widget.notice.childId, kind: kind, title: it.title, due: it.day, amount: it.amount, assigneeId: who[it] ?? '', noticeId: widget.notice.id, imageB64: kind == TaskKind.sign ? widget.notice.imageB64 : null, createdAt: DateTime.now()));
                }
              }
              widget.onCommit(evs, ts);
            },
            icon: const Icon(Icons.check),
            label: Text(s.commit),
          ),
        ),
      ]),
      if (st.members.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(s.t('提示:在「更多 → 家庭成员」添加爸爸/妈妈后,可以把事情指派出去。', 'Tip: add family members under More to assign items.'), style: Theme.of(context).textTheme.bodySmall),
        ),
    ]);
  }
}

class _ItemCard extends StatelessWidget {
  final ExtractedItem it;
  final String who;
  final ValueChanged<String> onWho;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  const _ItemCard(this.it, {required this.who, required this.onWho, required this.onChanged, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    final isEvent = it.type == ItemType.event;
    final color = isEvent ? const Color(0xFF2E6BE6) : kindColor(_kind(it.type));
    final conf = (it.confidence * 100).round();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(isEvent ? Icons.event : kindIcon(_kind(it.type)), color: color, size: 20),
            const SizedBox(width: 8),
            DropdownButton<ItemType>(
              value: it.type,
              isDense: true,
              underline: const SizedBox(),
              items: [
                for (final t in ItemType.values) DropdownMenuItem(value: t, child: Text(_typeName(s, t), style: TextStyle(color: color, fontWeight: FontWeight.w700))),
              ],
              onChanged: (v) {
                it.type = v!;
                onChanged();
              },
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: conf >= 80 ? const Color(0xFFE3F5EA) : conf >= 60 ? const Color(0xFFFFF3E0) : const Color(0xFFFDE7E4), borderRadius: BorderRadius.circular(10)),
              child: Text('${s.confidence} $conf%', style: const TextStyle(fontSize: 11)),
            ),
            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onDelete, visualDensity: VisualDensity.compact),
          ]),
          TextFormField(
            initialValue: it.title,
            decoration: InputDecoration(labelText: s.title, isDense: true),
            onChanged: (v) => it.title = v,
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: DayField(label: isEvent ? s.date : s.dueDate, value: it.day, clearable: !isEvent, onChanged: (d) { it.day = d; onChanged(); })),
            if (isEvent) ...[
              const SizedBox(width: 8),
              Expanded(child: TimeField(label: s.time, value: it.start, onChanged: (t) { it.start = t; onChanged(); })),
            ],
            if (it.type == ItemType.pay) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: it.amount?.toStringAsFixed(it.amount! % 1 == 0 ? 0 : 2) ?? '',
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.amount, isDense: true),
                  onChanged: (v) => it.amount = double.tryParse(v),
                ),
              ),
            ],
          ]),
          if (isEvent) ...[
            const SizedBox(height: 8),
            TextFormField(initialValue: it.location, decoration: InputDecoration(labelText: s.location, isDense: true), onChanged: (v) => it.location = v),
          ],
          if (st.members.isNotEmpty) ...[
            const SizedBox(height: 8),
            MemberPicker(value: who, onChanged: onWho),
          ],
          if (it.evidence.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('“${it.evidence}”', maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          ],
        ]),
      ),
    );
  }

  TaskKind _kind(ItemType t) => t == ItemType.sign ? TaskKind.sign : t == ItemType.pay ? TaskKind.pay : t == ItemType.bring ? TaskKind.bring : TaskKind.other;

  String _typeName(S s, ItemType t) {
    switch (t) {
      case ItemType.event:
        return s.event;
      case ItemType.sign:
        return s.kind(TaskKind.sign);
      case ItemType.pay:
        return s.kind(TaskKind.pay);
      case ItemType.bring:
        return s.kind(TaskKind.bring);
      case ItemType.deadline:
        return s.dueDate;
    }
  }
}
