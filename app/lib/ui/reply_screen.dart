// 用英文回复(依据 ai-keyboard-research 报告 4.3,验证「海外华人:中文意思 → 得体英文」):
//   入口  通知详情「用英文回复」(带上通知原文) / 更多「用英文写信」(空白回信)
//   写    中文要点 + 写给谁 + 语气 + 邮件/短信;或克制模式:自己写的英文只纠错不重写
//   结果  英文 + 中文回译 + 纠错清单 / 发送前留意;复制、分享(同「发给家人」);每封自动存进本机历史

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../core/reply_feedback.dart';
import '../core/reply_writer.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../platform/export.dart';
import '../store/app_state.dart';
import 'inbox_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

void openReplyComposer(BuildContext context, {String? noticeId, ReplyRecord? record}) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => ReplyComposePage(noticeId: noticeId, record: record)));
}

class ReplyComposePage extends StatefulWidget {
  final String? noticeId;
  final ReplyRecord? record; // 从历史打开:带回当时的输入、选项和结果
  final http.Client? client; // 只在测试里注入
  const ReplyComposePage({super.key, this.noticeId, this.record, this.client});
  @override
  State<ReplyComposePage> createState() => _ReplyComposePageState();
}

class _ReplyComposePageState extends State<ReplyComposePage> {
  late final input = TextEditingController(text: widget.record?.input ?? '');
  late final signature = TextEditingController(text: context.read<AppState>().settings.replySignature);
  final resultKey = GlobalKey();
  late final String noticeId = widget.noticeId ?? widget.record?.noticeId ?? '';
  late ReplyRecipient recipient = widget.record?.recipient ?? ReplyRecipient.teacher;
  late ReplyTone tone = widget.record?.tone ?? ReplyTone.polite;
  late ReplyFormat format = widget.record?.format ?? ReplyFormat.email;
  late bool restrained = widget.record?.restrained ?? false;
  late ReplyRecord? result = widget.record;
  bool busy = false;
  bool showNotice = false;

  @override
  void initState() {
    super.initState();
    // 从历史打开时,要看的是那封信:直接滚到结果
    if (widget.record != null) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToResult(animate: false));
  }

  void _scrollToResult({bool animate = true}) {
    final c = resultKey.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: animate ? const Duration(milliseconds: 300) : Duration.zero, alignment: 0.05);
  }

  @override
  void dispose() {
    input.dispose();
    signature.dispose();
    super.dispose();
  }

  Notice? _notice(AppState st) => noticeId.isEmpty ? null : st.notices.where((n) => n.id == noticeId).firstOrNull;

  // persist: false —— 带按钮的 SnackBar 默认一直不消失,会把后面的「已复制」等提示堵在队列里
  void _snack(String m, {SnackBarAction? action}) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), action: action, persist: false));
  }

  void _openSettings() => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));

  Future<void> _generate() async {
    final s = S.read(context);
    final st = context.read<AppState>();
    FocusScope.of(context).unfocus();
    if (input.text.trim().isEmpty) {
      _snack(s.replyEmpty);
      return;
    }
    if (!st.settings.aiEnabled) {
      _snack(s.replyNoKeyBody, action: SnackBarAction(label: s.goSettings, onPressed: _openSettings));
      return;
    }
    if (!await ensureAiConsent(context, reply: true)) return;
    if (!mounted) return;
    final notice = _notice(st);
    setState(() => busy = true);
    try {
      final draft = await ReplyWriter(apiKey: st.settings.apiKey, model: st.settings.model, client: widget.client).write(
        ReplyRequest(
          input: input.text,
          recipient: recipient,
          tone: tone,
          format: format,
          restrained: restrained,
          noticeTitle: notice?.title ?? '',
          noticeBody: notice?.body ?? '',
        ),
        uiLang: st.language,
      );
      // 页面关了也照样存进历史:这一封已经花了家长的 API 额度
      final r = ReplyRecord(
        id: newId(),
        createdAt: DateTime.now(),
        noticeId: noticeId,
        noticeTitle: notice?.title ?? widget.record?.noticeTitle ?? '',
        recipient: recipient,
        tone: tone,
        format: format,
        restrained: restrained,
        input: input.text.trim(),
        draft: draft,
      );
      st.addReply(r);
      if (!mounted) return;
      setState(() => result = r);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToResult());
    } catch (e) {
      _snack('${s.replyFailed}: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    final theme = Theme.of(context);
    final notice = _notice(st);
    return Scaffold(
      appBar: AppBar(
        title: Text(noticeId.isEmpty ? s.replyWrite : s.replyInEnglish),
        actions: [
          IconButton(
            tooltip: s.replyHistory,
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReplyHistoryPage())),
          ),
        ],
      ),
      // 不用 ListView:它只建屏幕内的子项,滚到结果要求结果已经建好
      body: AbsorbPointer(
        absorbing: busy,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!st.settings.aiEnabled) ...[
              Card(
                color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.6),
                child: ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: Text(s.replyNoKeyTitle),
                  subtitle: Text(s.replyNoKeyBody),
                  trailing: TextButton(onPressed: _openSettings, child: Text(s.goSettings)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (notice != null) ...[
              _NoticeContext(notice: notice, expanded: showNotice, onToggle: () => setState(() => showNotice = !showNotice)),
              const SizedBox(height: 12),
            ],
            _Label(s.replyTo),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final r in ReplyRecipient.values)
                ChoiceChip(label: Text(s.recipientName(r)), selected: recipient == r, onSelected: (_) => setState(() => recipient = r)),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: restrained,
              title: Text(s.replyRestrained),
              subtitle: Text(s.replyRestrainedDesc),
              onChanged: (v) => setState(() => restrained = v),
            ),
            if (!restrained) ...[
              _Label(s.replyToneLabel),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final x in ReplyTone.values)
                  ChoiceChip(label: Text(s.toneName(x)), selected: tone == x, onSelected: (_) => setState(() => tone = x)),
              ]),
              const SizedBox(height: 12),
              _Label(s.replyFormatLabel),
              SegmentedButton<ReplyFormat>(
                segments: [
                  for (final f in ReplyFormat.values)
                    ButtonSegment(value: f, label: Text(s.formatName(f)), icon: Icon(f == ReplyFormat.email ? Icons.email_outlined : Icons.sms_outlined)),
                ],
                selected: {format},
                onSelectionChanged: (v) => setState(() => format = v.first),
                showSelectedIcon: false,
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: input,
              minLines: 4,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: restrained ? s.replyDraft : s.replyPoints,
                hintText: restrained ? s.replyDraftHint : s.replyPointsHint,
                hintMaxLines: 4,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: signature,
              decoration: InputDecoration(labelText: s.replySignature, hintText: s.replySignatureHint, helperText: s.replySignatureNote, helperMaxLines: 2),
              onChanged: (v) {
                st.settings.replySignature = v.trim();
                st.saveSettings();
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : _generate,
              icon: Icon(restrained ? Icons.spellcheck : Icons.translate),
              label: Text(restrained ? s.replyFix : s.replyGenerate),
            ),
            if (busy) ...[
              const SizedBox(height: 16),
              Row(children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Expanded(child: Text(s.replyRunning)),
              ]),
            ],
            if (result != null) ...[
              const SizedBox(height: 20),
              ReplyResultView(key: resultKey, record: result!, signature: signature.text),
              // 只在本次刚写完时出现(从历史打开旧信不出现),第 3 封起、处理过一次就不再自动出现
              if (widget.record == null && shouldOfferFeedback(replyCount: st.replies.length, alreadyHandled: st.settings.replyFeedbackHandled)) ...[
                const SizedBox(height: 12),
                const ReplyFeedbackCard(),
              ],
            ],
          ]),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );
}

/// 回复的是哪条通知:默认折叠成三行,点开看全文。
class _NoticeContext extends StatelessWidget {
  final Notice notice;
  final bool expanded;
  final VoidCallback onToggle;
  const _NoticeContext({required this.notice, required this.expanded, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final body = notice.body.trim();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: body.isEmpty ? null : onToggle,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.reply, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text('${s.replyContext}: ${notice.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge)),
              if (body.isNotEmpty) Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 20),
            ]),
            const SizedBox(height: 6),
            Text(
              body.isEmpty ? s.replyContextNoText : body,
              maxLines: expanded ? null : 3,
              overflow: expanded ? null : TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(s.replyContextNote, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// 一封回信的结果:英文(可复制、可分享)、中文回译、纠错清单、发送前留意。生成页和历史都用它。
class ReplyResultView extends StatelessWidget {
  final ReplyRecord record;
  final String signature;
  const ReplyResultView({super.key, required this.record, this.signature = ''});

  Future<void> _copy(BuildContext context, String text) async {
    final s = S.read(context);
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.copied)));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final d = ReplyWriter.applySignature(record.draft, signature);
    final todo = ReplyWriter.placeholders('${d.subject}\n${d.english}');
    // 克制模式不选语气和形式,只标对象
    final meta = (record.restrained
            ? [s.recipientName(record.recipient), s.replyRestrained]
            : [s.formatName(record.format), s.recipientName(record.recipient), s.toneName(record.tone)])
        .join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(record.restrained ? Icons.spellcheck : Icons.translate, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge)),
            ]),
            if (d.subject.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: SelectableText('${s.replySubject}: ${d.subject}', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4))),
                IconButton(
                  tooltip: s.copySubject,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copy(context, d.subject),
                ),
              ]),
            ],
            const SizedBox(height: 8),
            SelectableText(d.english, style: const TextStyle(fontSize: 15, height: 1.5)),
            if (todo.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
                child: Text(s.replyFillIn(todo.join('  ')), style: const TextStyle(color: Color(0xFF7A4B00), fontSize: 13)),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(onPressed: () => _copy(context, d.english), icon: const Icon(Icons.copy, size: 18), label: Text(s.copy)),
              OutlinedButton.icon(
                onPressed: () => shareOrCopy(context, d.english, subject: d.subject.isEmpty ? null : d.subject),
                icon: const Icon(Icons.send_outlined, size: 18),
                label: Text(s.share),
              ),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.replyBack, style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            SelectableText(d.backTranslation.isEmpty ? '—' : d.backTranslation, style: const TextStyle(height: 1.5)),
          ]),
        ),
      ),
      if (record.restrained) ...[
        const SizedBox(height: 12),
        _Section(
          title: s.replyChanges,
          children: [
            if (d.changes.isEmpty) Text(s.replyNoChanges),
            for (final c in d.changes)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: c.before, style: TextStyle(decoration: TextDecoration.lineThrough, color: theme.colorScheme.error)),
                  const TextSpan(text: '  →  '),
                  TextSpan(text: c.after, style: const TextStyle(color: Color(0xFF2DA36A), fontWeight: FontWeight.w600)),
                  if (c.reason.isNotEmpty) TextSpan(text: '  · ${c.reason}', style: theme.textTheme.bodySmall),
                ])),
              ),
          ],
        ),
      ],
      if (d.notes.isNotEmpty) ...[
        const SizedBox(height: 12),
        _Section(title: s.replyNotes, children: [
          for (final n in d.notes) Padding(padding: const EdgeInsets.only(top: 2), child: Text('· $n')),
        ]),
      ],
    ]);
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            ...children,
          ]),
        ),
      );
}

/// 回信记录:标题是家长自己写的第一行(最好认),点开回到生成页,可以改了重写。
class ReplyHistoryPage extends StatelessWidget {
  const ReplyHistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(s.replyHistory),
        actions: [
          if (st.replies.isNotEmpty)
            TextButton.icon(
              onPressed: () => showReplyFeedbackSheet(context),
              icon: const Icon(Icons.feedback_outlined),
              label: Text(s.fbMenu),
            ),
        ],
      ),
      body: st.replies.isEmpty
          ? EmptyState(icon: Icons.history, text: s.replyHistoryEmpty)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: st.replies.length,
              itemBuilder: (c, i) {
                final r = st.replies[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: Icon(r.restrained ? Icons.spellcheck : (r.format == ReplyFormat.email ? Icons.email_outlined : Icons.sms_outlined)),
                      title: Text(r.input.split('\n').first, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [s.recipientName(r.recipient), s.md(Day.of(r.createdAt)), if (r.noticeTitle.isNotEmpty) r.noticeTitle].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: s.delete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirmDialog(c, '${s.delete}?')) st.removeReply(r.id);
                        },
                      ),
                      onTap: () => openReplyComposer(c, record: r),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// 回信记录页「反馈」:关掉卡片后想再给反馈也能找到。
Future<void> showReplyFeedbackSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(c).bottom),
      child: const SingleChildScrollView(child: ReplyFeedbackCard(inSheet: true)),
    ),
  );
}

/// 反馈卡(衡量方式见 core/reply_feedback.dart):有用 / 一般 / 没用 + 要不要键盘 + 可选一句话。
/// 不点「打开反馈表单 / 复制反馈」就什么都不发;点了或关掉都记为已处理,不再自动出现。
class ReplyFeedbackCard extends StatefulWidget {
  final bool inSheet;
  const ReplyFeedbackCard({super.key, this.inSheet = false});
  @override
  State<ReplyFeedbackCard> createState() => _ReplyFeedbackCardState();
}

class _ReplyFeedbackCardState extends State<ReplyFeedbackCard> {
  FeedbackRating? rating;
  bool keyboard = false;
  final comment = TextEditingController();

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  String _ratingLabel(S s, FeedbackRating r) => switch (r) {
        FeedbackRating.useful => s.fbUseful,
        FeedbackRating.okay => s.fbOkay,
        FeedbackRating.notUseful => s.fbNotUseful,
      };

  void _markHandled() {
    final st = context.read<AppState>();
    st.settings.replyFeedbackHandled = true;
    st.saveSettings();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), persist: false));

  Future<void> _send() async {
    final s = S.read(context);
    final st = context.read<AppState>();
    if (rating == null) {
      _snack(s.fbPickRating);
      return;
    }
    final uri = feedbackFormUri(kFeedbackFormUrl, rating: rating!, replyCount: st.replies.length, wantsKeyboard: keyboard, lang: st.language);
    if (uri != null) {
      // 留言不进 URL:先复制,家长在表单里粘贴
      if (comment.text.trim().isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: comment.text.trim()));
        if (mounted) _snack(s.fbCommentCopied);
      }
      await openUrl(uri.toString());
    } else {
      final text = feedbackPlainText(
        header: s.fbHeader,
        ratingLabel: s.fbRatingLine(_ratingLabel(s, rating!)),
        keyboardLabel: keyboard ? s.fbWantsKeyboard : s.fbNoKeyboard,
        replyCount: st.replies.length,
        countLabel: s.fbCountLabel,
        comment: comment.text,
      );
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) _snack(s.fbCopied);
    }
    if (!mounted) return;
    _markHandled();
    if (widget.inSheet) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final hasForm = kFeedbackFormUrl.trim().isNotEmpty;
    final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(Icons.feedback_outlined, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(s.fbTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 6),
      Text(s.fbBody, style: theme.textTheme.bodySmall),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final r in FeedbackRating.values)
          ChoiceChip(label: Text(_ratingLabel(s, r)), selected: rating == r, onSelected: (_) => setState(() => rating = r)),
      ]),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: keyboard,
        onChanged: (v) => setState(() => keyboard = v ?? false),
        title: Text(s.fbKeyboard, style: theme.textTheme.bodyMedium),
      ),
      TextField(controller: comment, minLines: 1, maxLines: 4, decoration: InputDecoration(labelText: s.fbComment)),
      const SizedBox(height: 8),
      Text(hasForm ? s.fbPrivacy : s.fbPrivacyCopy, style: theme.textTheme.bodySmall),
      const SizedBox(height: 8),
      OverflowBar(alignment: MainAxisAlignment.end, spacing: 8, children: [
        TextButton(
          onPressed: () {
            _markHandled();
            if (widget.inSheet) Navigator.of(context).pop();
          },
          child: Text(s.fbDismiss),
        ),
        FilledButton.icon(
          onPressed: _send,
          icon: Icon(hasForm ? Icons.open_in_new : Icons.copy_all_outlined, size: 18),
          label: Text(hasForm ? s.fbSendForm : s.fbCopy),
        ),
      ]),
    ]);
    if (widget.inSheet) return content;
    return Card(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
      child: Padding(padding: const EdgeInsets.all(14), child: content),
    );
  }
}
