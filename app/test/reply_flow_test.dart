// 「用英文回复」界面:从通知详情进入并带上通知;没 key 时提示不崩;生成 → 英文 + 中文回译 → 复制;
// 克制模式;从「更多」写空白回信、在回信记录里打开旧的一封。
// Hive 的真实 IO 在 testWidgets 的 FakeAsync 里会卡死,这里一律 AppState.load(inMemory: true)。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:school_sift/main.dart';
import 'package:school_sift/models/models.dart';
import 'package:school_sift/store/app_state.dart';
import 'package:school_sift/ui/reply_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _email = {
  'subject': 'Book Fair volunteer – Wednesday morning',
  'english': "Hi [Teacher's name],\n\nI'd love to volunteer at the Book Fair, but I'm only free on Wednesday morning. Would that work?\n\n"
      "Also, I've already ordered our Picture Day photos online. Do I still need to return the paper order form?\n\nThank you,\n[Your name]",
  'back_translation': "主题:书展志愿者——周三上午\n\n[Teacher's name] 老师您好:\n\n我很想去书展做志愿者,但我只有周三上午有空。这样可以吗?\n\n"
      '另外,照片日的照片我已经在网上订好了。纸质订购单还需要交回吗?\n\n谢谢,\n[Your name]',
  'changes': [],
  'notes': ["请把 [Teacher's name] 换成老师的称呼,例如 Ms. Garcia。"],
};

const _light = {
  'subject': '',
  'english': 'Hi Ms. Garcia, Mia will be absent tomorrow because she has a fever.',
  'back_translation': 'Garcia 老师您好,Mia 明天会缺课,因为她发烧了。',
  'changes': [
    {'before': 'will absent', 'after': 'will be absent', 'reason': 'absent 是形容词,前面要加 be'},
    {'before': 'she have', 'after': 'she has', 'reason': '第三人称单数'},
  ],
  'notes': [],
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  Future<AppState> demoState() async {
    final st = AppState();
    await st.load(inMemory: true);
    st.loadDemo();
    return st;
  }

  /// 假的 Anthropic 接口:记下请求体,回一段结构化输出。
  MockClient fakeClaude(Map<String, dynamic> out, List<Map<String, dynamic>> sent) => MockClient((req) async {
        sent.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'id': 'msg_1',
            'stop_reason': 'end_turn',
            'content': [
              {'type': 'text', 'text': jsonEncode(out)},
            ],
          })),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

  Widget composer(AppState st, Widget page) =>
      ChangeNotifierProvider.value(value: st, child: MaterialApp(theme: buildTheme(Brightness.light), home: page));

  String userTextOf(Map<String, dynamic> body) => (body['messages'][0]['content'] as List).single['text'] as String;

  List<String> selectableTexts(WidgetTester tester) =>
      tester.widgetList<SelectableText>(find.byType(SelectableText)).map((w) => w.data ?? '').toList();

  Finder nav(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  testWidgets('通知详情 → 用英文回复:带上这条通知;没 key 时提示去设置,不崩', (tester) async {
    bigView(tester);
    final st = await demoState();
    await tester.pumpWidget(ChangeNotifierProvider.value(value: st, child: const SchoolSiftApp()));
    await tester.pumpAndSettle();
    await tester.tap(nav('通知'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Picture Day & Book Fair'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('用英文回复'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('用英文回复'));
    await tester.pumpAndSettle();

    expect(find.text('回复: Picture Day & Book Fair'), findsOneWidget);
    expect(find.text('需要 Claude API key'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '我想报名做书展志愿者');
    await tester.ensureVisible(find.text('生成英文'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生成英文'));
    await tester.pump();
    expect(find.descendant(of: find.byType(SnackBar), matching: find.textContaining('在设置里填一个')), findsOneWidget);
    expect(find.descendant(of: find.byType(SnackBar), matching: find.text('去设置')), findsOneWidget);
    expect(st.replies, isEmpty);
    expect(tester.takeException(), isNull);
    // 带按钮的提示也要自己消失,不然后面的提示都排不上(计时从入场动画结束才开始)
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('生成 → 英文 + 中文回译 → 复制;署名只在本机填入;存进历史', (tester) async {
    bigView(tester);
    final st = await demoState();
    st.settings.apiKey = 'sk-test';
    final sent = <Map<String, dynamic>>[];
    String? clip;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(composer(st, ReplyComposePage(noticeId: 'n5', client: fakeClaude(_email, sent))));
    await tester.pumpAndSettle();
    expect(find.text('需要 Claude API key'), findsNothing);
    await tester.tap(find.text('催办'));
    await tester.enterText(find.byType(TextField).at(0), '我想报名做书展志愿者,但只有周三上午有空。照片网上已经订了,纸质表还要交吗?');
    await tester.enterText(find.byType(TextField).at(1), 'Lin Wang (Mia’s mom)');
    await tester.ensureVisible(find.text('生成英文'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生成英文'));
    await tester.pumpAndSettle();

    // 第一次用:先弹隐私告知
    expect(find.text('把要点发给 Claude?'), findsOneWidget);
    expect(sent, isEmpty);
    await tester.tap(find.text('发送并生成'));
    await tester.pumpAndSettle();

    // 发出去的:通知原文做上下文、选的语气;署名不发
    final userText = userTextOf(sent.single);
    expect(userText, contains('Recipient: teacher'));
    expect(userText, contains('Tone: followUp'));
    expect(userText, contains('Format: email'));
    expect(userText, contains('Picture Day is'));
    expect(userText, contains('纸质表还要交吗'));
    expect(jsonEncode(sent.single), isNot(contains('Lin Wang')));

    // 显示的:主题、英文、回译,[Your name] 换成了署名,占位提示还在
    final shown = selectableTexts(tester);
    expect(shown.any((t) => t.contains('Book Fair volunteer')), isTrue);
    final english = shown.firstWhere((t) => t.startsWith("Hi [Teacher's name]"));
    expect(english, endsWith('Thank you,\nLin Wang (Mia’s mom)'));
    expect(shown.firstWhere((t) => t.startsWith('主题:书展')), endsWith('谢谢,\nLin Wang (Mia’s mom)'));
    expect(shown.any((t) => t.contains('[Your name]')), isFalse);
    expect(find.textContaining("发送前把方括号换成真实信息:[Teacher's name]"), findsOneWidget);
    expect(find.text('中文回译 · 核对意思有没有被改'), findsOneWidget);
    expect(find.text('邮件 · 老师 · 催办'), findsOneWidget);
    expect(find.textContaining('换成老师的称呼'), findsOneWidget);

    await tester.ensureVisible(find.text('复制'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(clip, english);
    expect(find.text('已复制到剪贴板'), findsOneWidget);

    // 历史:存的是带占位的原稿,显示时才填署名
    expect(st.replies, hasLength(1));
    final r = st.replies.single;
    expect(r.noticeId, 'n5');
    expect(r.tone, ReplyTone.followUp);
    expect(r.draft.english, endsWith('[Your name]'));
    expect(st.settings.aiReplyConsent, isTrue);
    expect(st.settings.replySignature, 'Lin Wang (Mia’s mom)');
  });

  testWidgets('克制模式:不选语气和形式,发的是 <draft>,结果列出每处改动', (tester) async {
    bigView(tester);
    final st = await demoState();
    st.settings.apiKey = 'sk-test';
    st.settings.aiReplyConsent = true; // 同意过就不再弹
    final sent = <Map<String, dynamic>>[];
    await tester.pumpWidget(composer(st, ReplyComposePage(client: fakeClaude(_light, sent))));
    await tester.pumpAndSettle();
    expect(find.text('语气'), findsOneWidget);
    expect(find.textContaining('回复:'), findsNothing); // 空白回信不带通知

    await tester.tap(find.text('克制模式'));
    await tester.pumpAndSettle();
    expect(find.text('语气'), findsNothing);
    expect(find.text('形式'), findsNothing);
    expect(find.text('你写的英文'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Hi Ms. Garcia, Mia will absent tomorrow because she have a fever.');
    await tester.ensureVisible(find.text('只纠错'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('只纠错'));
    await tester.pumpAndSettle();

    final userText = userTextOf(sent.single);
    expect(userText, contains('<draft>\nHi Ms. Garcia, Mia will absent tomorrow'));
    expect(userText, isNot(contains('Tone:')));
    expect(sent.single['system'], contains('Correct only real errors'));
    expect(find.text('改了哪些地方'), findsOneWidget);
    expect(find.text('老师 · 克制模式'), findsOneWidget);
    expect(find.textContaining('第三人称单数'), findsOneWidget);
    expect(selectableTexts(tester), contains('Hi Ms. Garcia, Mia will be absent tomorrow because she has a fever.'));
    expect(st.replies.single.restrained, isTrue);
    expect(st.replies.single.draft.changes, hasLength(2));
  });

  testWidgets('更多 → 用英文写信(空白);回信记录能打开旧的一封', (tester) async {
    bigView(tester);
    final st = await demoState();
    st.addReply(ReplyRecord(
      id: 'r1',
      createdAt: DateTime.now(),
      noticeId: 'n5',
      noticeTitle: 'Picture Day & Book Fair',
      input: '纸质表还要交吗?',
      draft: const ReplyDraft(
        subject: 'Picture Day order form',
        english: "Hi [Teacher's name], do I still need to return the paper order form? Thank you, [Your name]",
        backTranslation: "[Teacher's name] 老师您好,纸质订购单还需要交回吗?谢谢,[Your name]",
      ),
    ));
    await tester.pumpWidget(ChangeNotifierProvider.value(value: st, child: const SchoolSiftApp()));
    await tester.pumpAndSettle();
    await tester.tap(nav('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('用英文写信'));
    await tester.pumpAndSettle();
    expect(find.text('用中文写要点'), findsOneWidget);
    expect(find.textContaining('回复:'), findsNothing);

    await tester.tap(find.byTooltip('回信记录'));
    await tester.pumpAndSettle();
    expect(find.text('纸质表还要交吗?'), findsOneWidget);
    await tester.tap(find.text('纸质表还要交吗?'));
    await tester.pumpAndSettle();
    expect(find.text('回复: Picture Day & Book Fair'), findsOneWidget);
    expect(selectableTexts(tester).any((t) => t.contains('do I still need to return the paper order form')), isTrue);
    // 打开旧信时直接滚到结果:「复制」不用再往下翻就在屏幕里
    expect(find.text('复制'), findsOneWidget);
    expect(tester.getCenter(find.text('复制')).dy, lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio));
  });
}
