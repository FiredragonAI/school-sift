// 「用英文回复」:家长用中文写要点 → 得体的英文邮件/短信 + 中文回译。
// 依据 C:\claude\ai-keyboard-research\report.md 4.3「海外华人:中文意思 → 得体英文」,先在学校通里验证两周(4.4)。
//
// 和通知识别走同一条 Claude 调用(callClaudeJson):家长自己的 key、浏览器直连、结构化输出。
// 拼 prompt、解析返回、填署名、找占位都是纯函数,单测不打网络。
//   - 回译:把写好的英文逐句直译回中文,家长用它确认意思没被改
//   - 克制模式:家长自己写的英文只纠错不重写,每处改动列出来
//   - 署名:模型只写 [Your name] 占位,真名在本机填入,不发给 AI

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'claude_extractor.dart';

/// 一次生成请求:家长写的内容、选项,以及(从通知进入时)通知原文。
class ReplyRequest {
  final String input; // 中文要点;克制模式下是家长自己写的英文
  final ReplyRecipient recipient;
  final ReplyTone tone;
  final ReplyFormat format;
  final bool restrained;
  final String noticeTitle;
  final String noticeBody;
  const ReplyRequest({
    required this.input,
    this.recipient = ReplyRecipient.teacher,
    this.tone = ReplyTone.polite,
    this.format = ReplyFormat.email,
    this.restrained = false,
    this.noticeTitle = '',
    this.noticeBody = '',
  });
}

class ReplyWriter {
  final String apiKey;
  final String model;
  final http.Client? client;
  const ReplyWriter({required this.apiKey, required this.model, this.client});

  /// 模型写在署名处的占位;本机用家长保存的署名替换。
  static const signaturePlaceholder = '[Your name]';

  static final Map<String, dynamic> schema = {
    'type': 'object',
    'additionalProperties': false,
    'required': ['subject', 'english', 'back_translation', 'changes', 'notes'],
    'properties': {
      'subject': {'type': 'string'},
      'english': {'type': 'string'},
      'back_translation': {'type': 'string'},
      'changes': {
        'type': 'array',
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['before', 'after', 'reason'],
          'properties': {
            'before': {'type': 'string'},
            'after': {'type': 'string'},
            'reason': {'type': 'string'},
          },
        },
      },
      'notes': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
  };

  static const _backTranslation =
      'Translate faithfully, sentence by sentence, without polishing, adding, or dropping anything: the parent reads it to confirm the English says what they meant. '
      'Copy [placeholders] unchanged. Use Traditional characters if the parent wrote in Traditional Chinese; otherwise Simplified.';

  static String systemPrompt({required bool restrained, required String uiLang}) {
    final lang = uiLang == 'zh' ? 'Simplified Chinese' : 'English';
    if (restrained) {
      return '''
You proofread an English message that a Chinese-speaking parent wrote themselves, to school staff or to another parent. Their child goes to school in an English-speaking country, usually the US. It must stay the parent's own message.

- Correct only real errors: grammar, spelling, punctuation, a wrong word, or a phrase a native reader would misunderstand.
- Keep their words, sentence order, tone, formality, and length. Do not rewrite sentences that are already correct, do not add greetings, sign-offs, or new content, and do not make it fancier.
- If part of the draft is in Chinese, translate just that part into plain English.
- If nothing needs fixing, return the draft unchanged.

Fields:
- subject: always "".
- english: the corrected message.
- changes: one entry per correction: before (the parent's original words), after (your correction), reason (a short phrase in $lang).
- notes: at most 3 suggestions in $lang that you did NOT apply because they go beyond corrections, e.g. the tone may be too casual for this recipient. [] if none.
- back_translation: the corrected message in Chinese. $_backTranslation
''';
    }
    return '''
You write messages for a Chinese-speaking parent whose child goes to school in an English-speaking country, usually the US. The parent says what they want to say, usually in Chinese, and you write the English message they will send. They will check your work through a back-translation, so being faithful matters more than sounding impressive.

Faithfulness:
- Say what the parent's points say, no more and no less. Do not add facts, reasons, excuses, promises, offers, dates, times, amounts, or names that are not in the points or in the school notice. Keep relative dates as the parent wrote them ("next Wednesday").
- If the message needs a detail the parent did not give (the child's name, the teacher's name, a date), write a short placeholder in square brackets such as [Child's name]. Never guess. Use a name from the school notice only when it clearly belongs to the person you are writing to.
- Sign off with the exact placeholder $signaturePlaceholder unless the points say how to sign; the app fills it in on the device, so don't mention it in notes.

Style: a courteous, confident native-speaking parent. Clear, warm, and concise; not stiff, not flowery. Render Chinese courtesy phrases (麻烦您了, 辛苦了, 不好意思打扰) with their natural English equivalents, not word for word. Don't over-apologize. Use US spelling unless the notice uses British spelling.

Recipient:
- teacher: friendly and professional.
- office (front office / attendance): brief and complete. Put the child's full name and grade or class first (placeholders if unknown), since the office deals with many families.
- nurse: state health details (symptoms, medication, dose, timing) exactly as given; never add medical advice.
- coach: friendly and brief.
- parent (another family): warm and casual.

Tone:
- polite: courteous and warm.
- firm: clear and direct about the request or position; respectful, without hedging or apologizing.
- apology: own the issue once, sincerely and briefly, and say what happens next.
- followUp: a polite nudge about an earlier message or request; restate the ask and any deadline; assume good intent.
- thanks: sincere and specific.

Format:
- email: a short, specific subject line; a greeting; one to three short paragraphs; a sign-off.
- text: one to three sentences, no subject, a short greeting, signed "- $signaturePlaceholder".

Fields:
- subject: the email subject line, or "" for a text message.
- english: the message body, ready to paste.
- back_translation: the English message in Chinese; if there is a subject, start with the line "主题:<subject in Chinese>". $_backTranslation
- changes: always [] in this mode.
- notes: at most 3 short notes in $lang the parent should check before sending: placeholders to fill in, an assumption you made, or something in their points you could not include. [] if none.
''';
  }

  /// 用户消息:对象(普通模式再加语气、形式)、可选的通知原文、家长写的内容。
  static String userText(ReplyRequest r) {
    final b = StringBuffer('Recipient: ${r.recipient.name}\n');
    if (!r.restrained) {
      b
        ..writeln('Tone: ${r.tone.name}')
        ..writeln('Format: ${r.format.name}');
    }
    final notice = [r.noticeTitle.trim(), r.noticeBody.trim()].where((e) => e.isNotEmpty).join('\n');
    if (notice.isNotEmpty) {
      b
        ..writeln()
        ..writeln('The school notice the parent is replying to (context only; do not repeat it back):')
        ..writeln('<school_notice>')
        ..writeln(notice)
        ..writeln('</school_notice>');
    }
    final tag = r.restrained ? 'draft' : 'points';
    b
      ..writeln()
      ..writeln('<$tag>')
      ..writeln(r.input.trim())
      ..write('</$tag>');
    return b.toString();
  }

  Future<ReplyDraft> write(ReplyRequest r, {required String uiLang}) async {
    final j = await callClaudeJson(
      apiKey: apiKey,
      model: model,
      system: systemPrompt(restrained: r.restrained, uiLang: uiLang),
      content: [
        {'type': 'text', 'text': userText(r)},
      ],
      schema: schema,
      client: client,
      truncatedMessage: '输出被截断,请把要点写短一点再试',
    );
    return parseResult(j, restrained: r.restrained);
  }

  /// 模型返回 → ReplyDraft。克制模式没有主题;普通模式没有纠错清单;空条目和没改的条目丢掉。
  static ReplyDraft parseResult(Map<String, dynamic> j, {bool restrained = false}) {
    String str(Object? v) => (v ?? '').toString().trim();
    return ReplyDraft(
      subject: restrained ? '' : str(j['subject']),
      english: str(j['english']),
      backTranslation: str(j['back_translation']),
      changes: [
        if (restrained)
          for (final c in (j['changes'] as List?) ?? const [])
            if (c is Map && str(c['before']) != str(c['after']))
              ReplyChange(before: str(c['before']), after: str(c['after']), reason: str(c['reason'])),
      ],
      notes: [
        for (final n in (j['notes'] as List?) ?? const [])
          if (str(n).isNotEmpty) str(n),
      ],
    );
  }

  /// 用本机保存的署名替换 [Your name](回译里模型偶尔会写成 [你的名字],一并换掉)。署名为空就原样留着让家长补。
  static ReplyDraft applySignature(ReplyDraft d, String signature) {
    final name = signature.trim();
    if (name.isEmpty) return d;
    final re = RegExp(r'\[(your name|你的名字|您的名字|你的姓名|您的姓名)\]', caseSensitive: false);
    return ReplyDraft(
      subject: d.subject,
      english: d.english.replaceAll(re, name),
      backTranslation: d.backTranslation.replaceAll(re, name),
      changes: d.changes,
      notes: d.notes,
    );
  }

  /// 还没填的 [方括号] 占位,去重保序。
  static List<String> placeholders(String text) =>
      {for (final m in RegExp(r'\[[^\[\]\n]{1,40}\]').allMatches(text)) m[0]!}.toList();
}
