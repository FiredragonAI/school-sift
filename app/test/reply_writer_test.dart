// 「用英文回复」的纯函数与存储:prompt 拼装、请求体、返回解析、署名替换、占位检测、历史进备份和落盘。不打真网络。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_sift/core/claude_extractor.dart';
import 'package:school_sift/core/reply_writer.dart';
import 'package:school_sift/models/models.dart';
import 'package:school_sift/store/app_state.dart';
import 'package:school_sift/store/settings.dart';

http.Response _claude(Map<String, dynamic> out, {String stop = 'end_turn'}) => http.Response.bytes(
      utf8.encode(jsonEncode({
        'id': 'msg_1',
        'stop_reason': stop,
        'content': [
          {'type': 'text', 'text': jsonEncode(out)},
        ],
      })),
      200,
      headers: {'content-type': 'application/json'},
    );

ReplyRecord _record({String id = 'r1', String input = '纸质表还要交吗?'}) => ReplyRecord(
      id: id,
      createdAt: DateTime(2026, 10, 23, 9),
      noticeId: 'n5',
      noticeTitle: 'Picture Day & Book Fair',
      recipient: ReplyRecipient.nurse,
      tone: ReplyTone.followUp,
      format: ReplyFormat.text,
      restrained: true,
      input: input,
      draft: const ReplyDraft(
        english: 'Hi, do I still need to return the paper form? - [Your name]',
        backTranslation: '你好,纸质表还需要交回吗?- [Your name]',
        changes: [ReplyChange(before: 'a', after: 'b', reason: 'c')],
        notes: ['n'],
      ),
    );

void main() {
  group('prompt', () {
    test('普通模式:对象、语气、形式 + 通知原文 + 要点', () {
      final text = ReplyWriter.userText(const ReplyRequest(
        input: '  小雨明天请假一天  ',
        recipient: ReplyRecipient.office,
        tone: ReplyTone.apology,
        format: ReplyFormat.text,
        noticeTitle: 'Field trip',
        noticeBody: 'Buses leave at 8:00 AM.',
      ));
      expect(text, startsWith('Recipient: office\nTone: apology\nFormat: text\n'));
      expect(text, contains('<school_notice>\nField trip\nBuses leave at 8:00 AM.\n</school_notice>'));
      expect(text, endsWith('<points>\n小雨明天请假一天\n</points>'));
    });

    test('空白回信不带通知;克制模式不带语气和形式,内容放 <draft>', () {
      expect(ReplyWriter.userText(const ReplyRequest(input: 'hi')), isNot(contains('school_notice')));
      final light = ReplyWriter.userText(const ReplyRequest(input: 'Mia will absent tomorrow.', restrained: true, tone: ReplyTone.firm));
      expect(light, isNot(contains('Tone:')));
      expect(light, isNot(contains('Format:')));
      expect(light, contains('<draft>\nMia will absent tomorrow.\n</draft>'));
      expect(light, isNot(contains('<points>')));
    });

    test('system prompt:不许加事实、署名占位、回译;每个对象和语气都有说明;说明文字跟界面语言', () {
      final zh = ReplyWriter.systemPrompt(restrained: false, uiLang: 'zh');
      expect(zh, contains('Do not add facts'));
      expect(zh, contains('placeholder ${ReplyWriter.signaturePlaceholder}'));
      expect(zh, contains('back_translation'));
      expect(zh, contains('notes in Simplified Chinese'));
      // 新加一个对象/语气却忘了写进 prompt,模型就只能瞎猜
      for (final r in ReplyRecipient.values) {
        expect(zh, contains('\n- ${r.name}'), reason: r.name);
      }
      for (final t in ReplyTone.values) {
        expect(zh, contains('\n- ${t.name}:'), reason: t.name);
      }
      final light = ReplyWriter.systemPrompt(restrained: true, uiLang: 'en');
      expect(light, contains('Correct only real errors'));
      expect(light, contains('reason (a short phrase in English)'));
      expect(light, isNot(contains(ReplyWriter.signaturePlaceholder)));
      expect(light, contains('back_translation'));
    });
  });

  test('write():结构化输出 + 浏览器直连头;返回映射成 ReplyDraft', () async {
    Map<String, dynamic>? sent;
    Map<String, String>? headers;
    final client = MockClient((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      headers = req.headers;
      return _claude({
        'subject': 'Early pickup on Wednesday',
        'english': 'Hi Ms. Garcia,\n\nI need to pick up [Child\'s name] early on Wednesday.\n\nThank you,\n[Your name]',
        'back_translation': '主题:周三提前接孩子\n\nGarcia 老师您好:\n\n我周三需要提前接 [Child\'s name]。\n\n谢谢,\n[Your name]',
        'changes': [
          {'before': 'x', 'after': 'y', 'reason': 'z'},
        ],
        'notes': ['  请把 [Child\'s name] 换成孩子的英文名  ', ''],
      });
    });
    final d = await ReplyWriter(apiKey: 'sk-test', model: 'claude-opus-5-5', client: client)
        .write(const ReplyRequest(input: '周三要提前接孩子', noticeTitle: 'Early dismissal'), uiLang: 'zh');
    expect(headers!['x-api-key'], 'sk-test');
    expect(headers!['anthropic-dangerous-direct-browser-access'], 'true');
    expect(headers!['anthropic-beta'], 'server-side-fallback-2026-07-01');
    expect(sent!['model'], 'claude-opus-5-5');
    expect(sent!['output_config']['format']['type'], 'json_schema');
    expect(sent!['output_config']['format']['schema'], ReplyWriter.schema);
    expect(sent!['output_config']['effort'], 'low');
    expect(sent!['fallbacks'], 'default');
    expect(sent!['system'], contains('Faithfulness'));
    final content = sent!['messages'][0]['content'] as List;
    expect(content.single['text'], contains('<points>\n周三要提前接孩子\n</points>'));
    expect(content.single['text'], contains('Early dismissal'));
    expect(d.subject, 'Early pickup on Wednesday');
    expect(d.english, endsWith('[Your name]'));
    expect(d.backTranslation, startsWith('主题:'));
    expect(d.changes, isEmpty); // 普通模式不该有纠错清单
    expect(d.notes, ['请把 [Child\'s name] 换成孩子的英文名']);
  });

  test('Haiku 不带 effort / fallbacks / beta 头;输出被截断时给回信自己的提示', () async {
    Map<String, dynamic>? sent;
    Map<String, String>? headers;
    final client = MockClient((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      headers = req.headers;
      return http.Response(jsonEncode({'stop_reason': 'max_tokens', 'content': []}), 200);
    });
    await expectLater(
      ReplyWriter(apiKey: 'k', model: 'claude-haiku-4-5', client: client).write(const ReplyRequest(input: 'x'), uiLang: 'zh'),
      throwsA(isA<ClaudeError>().having((e) => e.message, 'message', contains('要点'))),
    );
    expect((sent!['output_config'] as Map).containsKey('effort'), isFalse);
    expect(sent!.containsKey('fallbacks'), isFalse);
    expect(headers!.containsKey('anthropic-beta'), isFalse);
  });

  test('parseResult:克制模式没有主题,留下真改动、丢掉没改的和坏条目;字段缺失不崩', () {
    final d = ReplyWriter.parseResult({
      'subject': 'should be dropped',
      'english': ' Mia will be absent tomorrow. ',
      'back_translation': 'Mia 明天会缺课。',
      'changes': [
        {'before': 'will absent', 'after': 'will be absent', 'reason': '缺 be'},
        {'before': 'same', 'after': 'same', 'reason': ''},
        'garbage',
      ],
      'notes': null,
    }, restrained: true);
    expect(d.subject, '');
    expect(d.english, 'Mia will be absent tomorrow.');
    expect(d.changes.single.after, 'will be absent');
    expect(d.changes.single.reason, '缺 be');
    expect(d.notes, isEmpty);
    final empty = ReplyWriter.parseResult({});
    expect(empty.english, '');
    expect(empty.backTranslation, '');
    expect(empty.changes, isEmpty);
  });

  test('applySignature:英文和回译里的署名占位在本机填上;署名为空就原样保留', () {
    const d = ReplyDraft(english: 'Thanks,\n[Your name]', backTranslation: '谢谢,\n[你的名字]', notes: ['n']);
    final signed = ReplyWriter.applySignature(d, '  Lin (Mia’s mom) ');
    expect(signed.english, 'Thanks,\nLin (Mia’s mom)');
    expect(signed.backTranslation, '谢谢,\nLin (Mia’s mom)');
    expect(signed.notes, ['n']);
    expect(ReplyWriter.applySignature(d, '   ').english, d.english);
    expect(ReplyWriter.applySignature(const ReplyDraft(english: '- [your NAME]'), 'Lin').english, '- Lin');
  });

  test('placeholders:找出还没填的方括号,去重保序', () {
    expect(ReplyWriter.placeholders("Hi [Teacher's name], [Child's name] is sick. [Teacher's name]"), ["[Teacher's name]", "[Child's name]"]);
    expect(ReplyWriter.placeholders('No brackets here.'), isEmpty);
    expect(ReplyWriter.placeholders('[]'), isEmpty);
  });

  test('ReplyRecord JSON 往返;不认识的对象/语气/形式回落到默认,不崩', () {
    final back = ReplyRecord.fromJson(jsonDecode(jsonEncode(_record().toJson())) as Map<String, dynamic>);
    expect(back.recipient, ReplyRecipient.nurse);
    expect(back.tone, ReplyTone.followUp);
    expect(back.format, ReplyFormat.text);
    expect(back.restrained, isTrue);
    expect(back.noticeTitle, 'Picture Day & Book Fair');
    expect(back.draft.changes.single.after, 'b');
    expect(back.draft.notes, ['n']);
    final odd = ReplyRecord.fromJson({
      'id': 'x',
      'createdAt': '2026-10-23T09:00:00.000',
      'recipient': 'principal',
      'tone': 'sarcastic',
      'format': 'fax',
      'input': 'i',
      'draft': {'english': 'e'},
    });
    expect(odd.recipient, ReplyRecipient.teacher);
    expect(odd.tone, ReplyTone.polite);
    expect(odd.format, ReplyFormat.email);
    expect(odd.draft.english, 'e');
  });

  test('设置:回信的同意和署名能存能读,旧设置没有这两项时取默认', () {
    final s = Settings.fromJson(Settings(aiReplyConsent: true, replySignature: 'Lin').toJson());
    expect(s.aiReplyConsent, isTrue);
    expect(s.replySignature, 'Lin');
    final old = Settings.fromJson({'apiKey': 'k', 'aiConsent': true});
    expect(old.aiReplyConsent, isFalse);
    expect(old.replySignature, '');
  });

  test('回信历史进备份 JSON;旧备份没有 replies 也能导入;清空全部会删掉', () async {
    final st = AppState()..addReply(_record());
    final st2 = AppState()..importJson(st.exportJson());
    expect(st2.replies.single.input, '纸质表还要交吗?');
    expect(st2.repliesTo('n5'), hasLength(1));
    expect(st2.repliesTo('n1'), isEmpty);
    final old = AppState()..importJson('{"version": 2, "children": []}');
    expect(old.replies, isEmpty);
    st2.removeReply('r1');
    expect(st2.replies, isEmpty);
    st.addReply(_record(id: 'r2'));
    await st.clearAll();
    expect(st.replies, isEmpty);
  });

  test('删除孩子时,回这个孩子通知的信一起删;空白回信和别的孩子的留着', () {
    final st = AppState()..loadDemo(); // n5 属于 c_a(小雨),n2 属于 c_b(小航)
    st.addReply(_record(id: 'to_a')); // noticeId n5
    st.addReply(ReplyRecord(id: 'to_b', createdAt: DateTime(2026, 10, 23), noticeId: 'n2', input: 'b', draft: const ReplyDraft(english: 'e')));
    st.addReply(ReplyRecord(id: 'blank', createdAt: DateTime(2026, 10, 23), input: 'x', draft: const ReplyDraft(english: 'e')));
    st.removeChild('c_a');
    expect(st.replies.map((r) => r.id), unorderedEquals(['to_b', 'blank']));
  });

  test('回信历史落盘(Hive)后能重新读出,新的在前', () async {
    final dir = Directory.systemTemp.createTempSync('schoolsift_reply_test');
    addTearDown(() => Hive.close());
    final st = AppState();
    await st.load(hivePath: dir.path);
    st.addReply(_record(id: 'old', input: '第一封'));
    st.addReply(_record(id: 'new', input: '第二封'));
    final st2 = AppState();
    await st2.load(hivePath: dir.path);
    expect(st2.replies.map((r) => r.input), ['第二封', '第一封']);
    expect(st2.replies.first.draft.backTranslation, contains('纸质表'));
  });
}
