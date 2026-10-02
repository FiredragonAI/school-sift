// 通知收件箱(F01 / F02 / I07):
//   列表  原文永远可搜(ParentSquare 被骂最多的一点)
//   录入  粘贴文字 / 拍照 / 相册 / 截图 / PDF → 本机 OCR 或 Claude 识别 → 家长核对 → 写入日程/待办
//   详情  原文 + 附图 + 已生成的条目,可随时重新识别

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/claude_extractor.dart';
import '../core/notice_parser.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../platform/ocr.dart' as ocr;
import '../platform/pdf_raster.dart';
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
        heroTag: 'fab_inbox',
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
                          leading: n.imageIds.isNotEmpty
                              ? SizedBox(width: 44, height: 44, child: storedImage(c, n.imageIds.first))
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

Future<void> showNoticeEditor(BuildContext context, {bool camera = false}) async {
  final s = S.read(context);
  final st = context.read<AppState>();
  if (st.children.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.pleaseAddChild)));
    return;
  }
  await Navigator.push(context, MaterialPageRoute(builder: (_) => NoticeComposePage(startCamera: camera)));
}

void openNotice(BuildContext context, Notice n, {bool review = false}) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => NoticeDetailPage(noticeId: n.id, startReview: review || !n.processed)));
}

/// 调 AI 前的一次性告知(隐私):说清发什么、发给谁、不发什么。
Future<bool> ensureAiConsent(BuildContext context) async {
  final st = context.read<AppState>();
  if (st.settings.aiConsent) return true;
  final s = S.read(context);
  var remember = true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => AlertDialog(
        title: Text(s.aiConsentTitle),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.aiConsentBody),
          const SizedBox(height: 8),
          CheckboxListTile(value: remember, onChanged: (v) => setS(() => remember = v ?? true), title: Text(s.aiConsentRemember), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.aiConsentOk)),
        ],
      ),
    ),
  );
  if (ok == true && remember) {
    st.settings.aiConsent = true;
    st.saveSettings();
  }
  return ok == true;
}

String ocrLangFor(AppState st) {
  switch (st.settings.ocrLang) {
    case 'eng':
      return 'eng';
    case 'chi':
      return 'eng+chi_sim';
    default:
      return st.language == 'zh' ? 'eng+chi_sim' : 'eng';
  }
}

// ---------- 录入 ----------

class _Att {
  final Uint8List jpeg;
  final String label;
  _Att(this.jpeg, this.label);
}

class NoticeComposePage extends StatefulWidget {
  final bool startCamera;
  const NoticeComposePage({super.key, this.startCamera = false});
  @override
  State<NoticeComposePage> createState() => _NoticeComposePageState();
}

class _NoticeComposePageState extends State<NoticeComposePage> {
  final title = TextEditingController();
  final body = TextEditingController();
  late String childId;
  final atts = <_Att>[];
  Uint8List? pdfBytes;
  bool busy = false;
  String status = '';

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    childId = st.filterChildId.isNotEmpty ? st.filterChildId : st.children.first.id;
    if (widget.startCamera) WidgetsBinding.instance.addPostFrameCallback((_) => _addPhoto(camera: true));
  }

  Future<void> _addPhoto({bool camera = false}) async {
    final b = await pickImageBytes(context, camera: camera);
    if (b != null && mounted) setState(() => atts.add(_Att(b, '')));
  }

  Future<void> _addFile() async {
    final s = S.read(context);
    final x = await openFile(acceptedTypeGroups: [
      const XTypeGroup(label: 'images & PDF', extensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf'], mimeTypes: ['image/*', 'application/pdf']),
    ]);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final isPdf = x.name.toLowerCase().endsWith('.pdf') || x.mimeType == 'application/pdf' || (bytes.length > 4 && String.fromCharCodes(bytes.sublist(0, 4)) == '%PDF');
    if (!mounted) return;
    if (isPdf) {
      setState(() {
        busy = true;
        status = 'PDF…';
      });
      try {
        final pages = await rasterizePdf(bytes);
        if (!mounted) return;
        setState(() {
          pdfBytes = bytes;
          for (var i = 0; i < pages.length; i++) {
            atts.add(_Att(compressBytes(pages[i]), '${s.page}${i + 1}'));
          }
        });
      } catch (e) {
        _snack('PDF: $e');
      } finally {
        if (mounted) setState(() { busy = false; status = ''; });
      }
    } else {
      setState(() => atts.add(_Att(compressBytes(bytes), '')));
    }
  }

  Future<bool> _ocr() async {
    final s = S.read(context);
    final st = context.read<AppState>();
    if (atts.isEmpty) return false;
    setState(() {
      busy = true;
      status = s.ocrRunning;
    });
    final buf = StringBuffer();
    try {
      for (var i = 0; i < atts.length; i++) {
        final text = await ocr.ocrImage(
          atts[i].jpeg,
          lang: ocrLangFor(st),
          onProgress: (p) {
            if (mounted) setState(() => status = '${s.ocrRunning} ${i + 1}/${atts.length} ${(p * 100).round()}%');
          },
        );
        if (text.isNotEmpty) buf.writeln(text);
      }
    } catch (e) {
      _snack('${s.ocrFailed}: $e');
      return false;
    } finally {
      if (mounted) setState(() { busy = false; status = ''; });
    }
    final got = buf.toString().trim();
    if (got.isEmpty) {
      _snack(s.ocrEmpty);
      return false;
    }
    body.text = [body.text.trim(), got].where((e) => e.isNotEmpty).join('\n\n');
    _snack(s.ocrDone);
    return true;
  }

  Future<void> _run({required bool ai}) async {
    final s = S.read(context);
    final st = context.read<AppState>();
    if (body.text.trim().isEmpty && atts.isEmpty) {
      _snack(s.noContent);
      return;
    }
    Extraction ex;
    if (ai) {
      if (!st.settings.aiEnabled) {
        _snack(s.aiNoKey);
        return;
      }
      if (!await ensureAiConsent(context)) return;
      if (!mounted) return;
      setState(() { busy = true; status = s.aiRunning; });
      try {
        ex = await ClaudeExtractor(apiKey: st.settings.apiKey, model: st.settings.model).extract(
          text: body.text,
          attachments: [
            if (pdfBytes != null) ClaudeAttachment('application/pdf', base64Encode(pdfBytes!)) else for (final a in atts) ClaudeAttachment('image/jpeg', base64Encode(a.jpeg)),
          ],
          today: Day.today(),
          uiLang: st.language,
        );
      } catch (e) {
        _snack('${s.aiFailed}: $e');
        return;
      } finally {
        if (mounted) setState(() { busy = false; status = ''; });
      }
    } else {
      if (body.text.trim().isEmpty) {
        // 只有图没有字:先本机 OCR
        if (!await _ocr()) return;
        if (!mounted) return;
      }
      ex = NoticeParser().parse(body.text, titleHint: title.text.trim().isEmpty ? null : title.text.trim());
    }
    final n = Notice(
      id: newId(),
      childId: childId,
      title: title.text.trim().isNotEmpty ? title.text.trim() : (ex.title.isNotEmpty ? ex.title : s.t('学校通知', 'School notice')),
      body: body.text.trim(),
      source: pdfBytes != null ? 'file' : (atts.isNotEmpty ? 'photo' : 'paste'),
      receivedAt: DateTime.now(),
      imageIds: [for (final a in atts) st.putImage(base64Encode(a.jpeg))],
      extractor: ai ? 'ai' : 'rules',
    );
    st.addNotice(n);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => NoticeDetailPage(noticeId: n.id, initial: ex, extractor: ai ? 'ai' : 'rules')));
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    final aiOn = st.settings.aiEnabled;
    return Scaffold(
      appBar: AppBar(title: Text(s.newNotice)),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          ChildPicker(value: childId, onChanged: (v) => setState(() => childId = v)),
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
          Text(s.attachments, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          if (atts.isNotEmpty)
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: atts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (c, i) => Stack(children: [
                  GestureDetector(
                    onTap: () => showFullImage(c, base64Encode(atts[i].jpeg)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(atts[i].jpeg, width: 96, height: 96, fit: BoxFit.cover)),
                  ),
                  if (atts[i].label.isNotEmpty)
                    Positioned(left: 4, bottom: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)), child: Text(atts[i].label, style: const TextStyle(color: Colors.white, fontSize: 11)))),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        atts.removeAt(i);
                        if (atts.every((a) => a.label.isEmpty)) pdfBytes = null;
                      }),
                      child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                    ),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: () => _addPhoto(camera: true), icon: const Icon(Icons.photo_camera_outlined), label: Text(s.takePhoto)),
            OutlinedButton.icon(onPressed: () => _addPhoto(), icon: const Icon(Icons.photo_library_outlined), label: Text(s.pickPhoto)),
            OutlinedButton.icon(onPressed: _addFile, icon: const Icon(Icons.attach_file), label: Text(s.pickFile)),
          ]),
          if (atts.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _ocr, icon: const Icon(Icons.document_scanner_outlined), label: Text('${s.ocrRun} · ${ocr.ocrEngineName}')),
          ],
          if (busy) ...[
            const SizedBox(height: 16),
            Row(children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: 10), Expanded(child: Text(status))]),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: busy ? null : () => _run(ai: aiOn),
            icon: Icon(aiOn ? Icons.auto_awesome : Icons.rule),
            label: Text(aiOn ? s.aiExtract : s.rulesExtract),
          ),
          TextButton(
            onPressed: busy ? null : () => _run(ai: !aiOn),
            child: Text(aiOn ? s.useRulesInstead : s.useAiInstead),
          ),
          if (!aiOn)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(s.aiNoKey, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            ),
        ]),
      ),
    );
  }
}

// ---------- 通知详情 / 识别核对 ----------

class NoticeDetailPage extends StatefulWidget {
  final String noticeId;
  final bool startReview;
  final Extraction? initial;
  final String extractor;
  const NoticeDetailPage({super.key, required this.noticeId, this.startReview = false, this.initial, this.extractor = 'rules'});
  @override
  State<NoticeDetailPage> createState() => _NoticeDetailPageState();
}

class _NoticeDetailPageState extends State<NoticeDetailPage> {
  Extraction? ex;
  String extractorUsed = 'rules';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      ex = widget.initial;
      extractorUsed = widget.extractor;
    } else if (widget.startReview) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _extractRules());
    }
  }

  Notice? get _notice => context.read<AppState>().notices.where((e) => e.id == widget.noticeId).firstOrNull;

  void _extractRules() {
    final n = _notice;
    if (n == null || n.body.trim().isEmpty) return;
    setState(() {
      ex = NoticeParser().parse(n.body, titleHint: n.title);
      extractorUsed = 'rules';
    });
  }

  Future<void> _extractAi() async {
    final s = S.read(context);
    final st = context.read<AppState>();
    final n = _notice;
    if (n == null) return;
    if (!st.settings.aiEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.aiNoKey)));
      return;
    }
    if (!await ensureAiConsent(context)) return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final r = await ClaudeExtractor(apiKey: st.settings.apiKey, model: st.settings.model).extract(
        text: n.body,
        attachments: [for (final id in n.imageIds) if (st.image(id) != null) ClaudeAttachment('image/jpeg', st.image(id)!)],
        today: Day.today(),
        uiLang: st.language,
      );
      if (!mounted) return;
      setState(() {
        ex = r;
        extractorUsed = 'ai';
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${s.aiFailed}: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
          if (n.extractor.isNotEmpty) ...[
            const SizedBox(width: 6),
            Chip(visualDensity: VisualDensity.compact, avatar: Icon(n.extractor == 'ai' ? Icons.auto_awesome : Icons.rule, size: 16), label: Text(n.extractor == 'ai' ? s.extractorAi : s.extractorRules)),
          ],
          const Spacer(),
          Text(
            '${s.source}: ${switch (n.source) { 'photo' => s.sourcePhoto, 'file' => s.sourceFile, 'demo' => s.sourceDemo, _ => s.sourcePaste }}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ]),
        const SizedBox(height: 12),
        if (n.imageIds.isNotEmpty) ...[
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: n.imageIds.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (c, i) => GestureDetector(
                onTap: () => showStoredImage(c, n.imageIds[i]),
                child: SizedBox(width: 110, child: storedImage(c, n.imageIds[i], height: 140)),
              ),
            ),
          ),
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
        if (busy)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: 10), Text(s.aiRunning)]),
          )
        else if (ex == null) ...[
          if (linkedEvents.isNotEmpty || linkedTasks.isNotEmpty) ...[
            Text(s.t('已生成', 'Created'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            for (final e in linkedEvents) ListTile(dense: true, leading: const Icon(Icons.event), title: Text(e.title), subtitle: Text('${s.mdw(e.day)} ${s.tod(e.start)}')),
            for (final t in linkedTasks) ListTile(dense: true, leading: Icon(kindIcon(t.kind), color: kindColor(t.kind)), title: Text(t.title), subtitle: Text(t.due == null ? s.noDue : s.dueIn(t.due!))),
            const SizedBox(height: 8),
          ],
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: n.body.isEmpty ? null : _extractRules, icon: const Icon(Icons.rule), label: Text(s.rulesExtract))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.tonalIcon(onPressed: _extractAi, icon: const Icon(Icons.auto_awesome), label: Text(s.extractorAi))),
          ]),
        ] else
          _ReviewPanel(
            key: ValueKey(ex),
            notice: n,
            ex: ex!,
            extractor: extractorUsed,
            onCancel: () => setState(() => ex = null),
            onRetryAi: _extractAi,
            onCommit: (evs, ts) {
              st.commitExtraction(n, evs, ts, reschedule: ex!.reschedule, extractor: extractorUsed);
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
  final String extractor;
  final VoidCallback onCancel;
  final VoidCallback onRetryAi;
  final void Function(List<Event>, List<Task>) onCommit;
  const _ReviewPanel({super.key, required this.notice, required this.ex, required this.extractor, required this.onCancel, required this.onRetryAi, required this.onCommit});
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
      Row(children: [
        Expanded(child: Text(s.extractTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        Chip(visualDensity: VisualDensity.compact, avatar: Icon(widget.extractor == 'ai' ? Icons.auto_awesome : Icons.rule, size: 16), label: Text(widget.extractor == 'ai' ? s.extractorAi : s.extractorRules)),
      ]),
      for (final line in widget.ex.summary.where((l) => !l.startsWith('⚠')))
        Padding(padding: const EdgeInsets.only(top: 2), child: Text('· $line', style: Theme.of(context).textTheme.bodySmall)),
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
      Row(children: [
        TextButton.icon(
          onPressed: () => setState(() => items.add(ExtractedItem(type: ItemType.event, title: widget.notice.title, day: Day.today().add(1), confidence: 1, evidence: ''))),
          icon: const Icon(Icons.add),
          label: Text(s.addItem),
        ),
        const Spacer(),
        if (widget.extractor != 'ai') TextButton.icon(onPressed: widget.onRetryAi, icon: const Icon(Icons.auto_awesome, size: 18), label: Text(s.useAiInstead)),
      ]),
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
                  ts.add(Task(id: newId(), childId: widget.notice.childId, kind: kind, title: it.title, due: it.day, amount: it.amount, assigneeId: who[it] ?? '', noticeId: widget.notice.id, imageId: kind == TaskKind.sign ? widget.notice.imageIds.firstOrNull : null, createdAt: DateTime.now()));
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
              items: [for (final t in ItemType.values) DropdownMenuItem(value: t, child: Text(_typeName(s, t), style: TextStyle(color: color, fontWeight: FontWeight.w700)))],
              onChanged: (v) {
                it.type = v!;
                onChanged();
              },
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: conf >= 80 ? const Color(0xFFE3F5EA) : conf >= 60 ? const Color(0xFFFFF3E0) : const Color(0xFFFDE7E4), borderRadius: BorderRadius.circular(10)),
              child: Text('${s.confidence} $conf%', style: const TextStyle(fontSize: 11, color: Colors.black87)),
            ),
            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onDelete, visualDensity: VisualDensity.compact),
          ]),
          TextFormField(initialValue: it.title, decoration: InputDecoration(labelText: s.title, isDense: true), onChanged: (v) => it.title = v),
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
                  initialValue: it.amount == null ? '' : it.amount!.toStringAsFixed(it.amount! % 1 == 0 ? 0 : 2),
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
