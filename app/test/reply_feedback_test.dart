// 「用英文回复」的反馈卡:第 3 封才出现、处理过不再自动出现、不点按钮什么都不发;
// 表单地址只带三项选择和条数(不带留言)。Hive 在 testWidgets 里会卡死,一律 inMemory。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:school_sift/core/reply_feedback.dart';
import 'package:school_sift/main.dart';
import 'package:school_sift/models/models.dart';
import 'package:school_sift/store/app_state.dart';
import 'package:school_sift/ui/reply_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

ReplyRecord _old(String id) => ReplyRecord(
      id: id,
      createdAt: DateTime.now(),
      input: '旧的一封 $id',
      draft: const ReplyDraft(english: 'Hi, thanks!', backTranslation: '你好,谢谢!'),
    );

void main() {
  group('纯函数', () {
    test('第 3 封才出现,处理过就不再出现', () {
      expect(shouldOfferFeedback(replyCount: 2, alreadyHandled: false), isFalse);
      expect(shouldOfferFeedback(replyCount: 3, alreadyHandled: false), isTrue);
      expect(shouldOfferFeedback(replyCount: 9, alreadyHandled: false), isTrue);
      expect(shouldOfferFeedback(replyCount: 9, alreadyHandled: true), isFalse);
    });

    test('表单地址:占位符替换并编码;没模板或不是 http(s) 返回 null', () {
      final u = feedbackFormUri('https://tally.so/r/abc?rating={rating}&n={count}&kb={keyboard}&lang={lang}',
          rating: FeedbackRating.notUseful, replyCount: 4, wantsKeyboard: true, lang: 'zh');
      expect(u.toString(), 'https://tally.so/r/abc?rating=not_useful&n=4&kb=yes&lang=zh');
      expect(feedbackFormUri('', rating: FeedbackRating.useful, replyCount: 3, wantsKeyboard: false, lang: 'en'), isNull);
      expect(feedbackFormUri('javascript:alert(1)', rating: FeedbackRating.useful, replyCount: 3, wantsKeyboard: false, lang: 'en'), isNull);
      // 没占位符就原样打开
      expect(feedbackFormUri('https://forms.gle/xyz', rating: FeedbackRating.okay, replyCount: 3, wantsKeyboard: false, lang: 'en').toString(),
          'https://forms.gle/xyz');
    });

    test('复制的文字:有留言才带留言', () {
      final t = feedbackPlainText(header: 'H', ratingLabel: 'R', keyboardLabel: 'K', replyCount: 5, countLabel: 'N', comment: '  ');
      expect(t, 'H\nR\nK\nN: 5');
      expect(feedbackPlainText(header: 'H', ratingLabel: 'R', keyboardLabel: 'K', replyCount: 5, countLabel: 'N', comment: '挺好'), endsWith('\n挺好'));
    });
  });

  group('界面', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    final clipboard = <String>[];
    setUp(() {
      clipboard.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboard.add((call.arguments as Map)['text'] as String);
        return null;
      });
    });

    void bigView(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
    }

    MockClient fakeClaude() => MockClient((req) async => http.Response.bytes(
          utf8.encode(jsonEncode({
            'id': 'msg_1',
            'stop_reason': 'end_turn',
            'content': [
              {
                'type': 'text',
                'text': jsonEncode({'subject': '', 'english': 'Hi Ms. Garcia, thank you!', 'back_translation': 'Garcia 老师您好,谢谢您!', 'changes': [], 'notes': []}),
              },
            ],
          })),
          200,
          headers: {'content-type': 'application/json'},
        ));

    Future<AppState> state(int existingReplies) async {
      final st = AppState();
      await st.load(inMemory: true);
      st.settings.apiKey = 'sk-test';
      st.settings.aiReplyConsent = true;
      for (var i = 0; i < existingReplies; i++) {
        st.addReply(_old('r$i'));
      }
      return st;
    }

    Future<void> generate(WidgetTester tester, AppState st) async {
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: st,
        child: MaterialApp(theme: buildTheme(Brightness.light), home: ReplyComposePage(client: fakeClaude())),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '谢谢老师');
      await tester.ensureVisible(find.text('生成英文'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('生成英文'));
      await tester.pumpAndSettle();
    }

    testWidgets('第 1、2 封不出现', (tester) async {
      bigView(tester);
      final st = await state(1);
      await generate(tester, st);
      expect(st.replies.length, 2);
      expect(find.byType(ReplyFeedbackCard), findsNothing);
    });

    testWidgets('第 3 封出现;不选评价不发;复制后不再出现;什么都没联网', (tester) async {
      bigView(tester);
      final st = await state(2);
      await generate(tester, st);
      expect(st.replies.length, 3);
      expect(find.byType(ReplyFeedbackCard), findsOneWidget);
      expect(find.text('「用英文回复」对你有用吗?'), findsOneWidget);
      // 没配表单:按钮是「复制反馈」,说明里写清楚只放进剪贴板
      await tester.ensureVisible(find.text('复制反馈'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('复制反馈'));
      await tester.pumpAndSettle();
      expect(clipboard, isEmpty, reason: '没选评价时不复制');
      expect(st.settings.replyFeedbackHandled, isFalse);

      await tester.tap(find.text('一般'));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.enterText(find.widgetWithText(TextField, '想说的话(可选)'), '主题行很有用');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('复制反馈'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('复制反馈'));
      await tester.pumpAndSettle();
      expect(clipboard.single, contains('评价:一般'));
      expect(clipboard.single, contains('想要中英键盘:是'));
      expect(clipboard.single, contains('已写回信: 3'));
      expect(clipboard.single, endsWith('主题行很有用'));
      expect(st.settings.replyFeedbackHandled, isTrue);
      expect(find.byType(ReplyFeedbackCard), findsNothing, reason: '处理过就收起');
    });

    testWidgets('点「不了,谢谢」也算处理过;回信记录页还能手动打开', (tester) async {
      bigView(tester);
      final st = await state(2);
      await generate(tester, st);
      await tester.ensureVisible(find.text('不了,谢谢'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('不了,谢谢'));
      await tester.pumpAndSettle();
      expect(st.settings.replyFeedbackHandled, isTrue);
      expect(find.byType(ReplyFeedbackCard), findsNothing);
      expect(clipboard, isEmpty);

      await tester.tap(find.byTooltip('回信记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('反馈'));
      await tester.pumpAndSettle();
      expect(find.byType(ReplyFeedbackCard), findsOneWidget);
    });

    testWidgets('从历史打开旧信不出现', (tester) async {
      bigView(tester);
      final st = await state(5);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: st,
        child: MaterialApp(theme: buildTheme(Brightness.light), home: ReplyComposePage(record: st.replies.first)),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ReplyFeedbackCard), findsNothing);
    });
  });
}
