// 界面上不画 emoji:日程/待办的负责人、学习记录的专注度和老师反馈都用 Material 图标。
// 打包的 Noto Sans SC 子集里没有 emoji,Web 版(CanvasKit)会去 fonts.gstatic.com 下载
// Noto Color Emoji 等回退字体,连不上(大陆、部分学校和公司网络)就显示 □。
// 发给家人的文字和系统通知由系统渲染,不受影响,那里照旧用 emoji。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:school_sift/main.dart';
import 'package:school_sift/store/app_state.dart';
import 'package:school_sift/ui/calendar_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 按 Emoji_Presentation 算 emoji(默认彩色显示的那些;✓ ⚠ 这类默认按文字显示的不算)。
// flutter analyze 的 valid_regexps 不认识 emoji 类的 Unicode 属性而误报;dart analyze 与 flutter test 都认
// ignore: valid_regexps
final emoji = RegExp(r'\p{Emoji_Presentation}', unicode: true);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, String lang) async {
    // 600×1100 逻辑像素,仍是手机布局(< 760)。测试字体每个字都是 1 em 宽,英文比真实字体宽得多,
    // 432 宽时今日页标题栏的「SchoolSift + 日期」会溢出(真机/浏览器上不会)
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final st = AppState();
    await st.load(inMemory: true);
    st.setLanguage(lang); // 演示数据按当前语言生成
    st.loadDemo();
    await tester.pumpWidget(ChangeNotifierProvider.value(value: st, child: const SchoolSiftApp()));
    await tester.pumpAndSettle();
  }

  Future<void> go(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Finder nav(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  // 一块区域里的文字(含 Text.rich);行内图标在 toPlainText 里是 U+FFFC
  String textOf(WidgetTester tester, Finder scope) => tester
      .widgetList<RichText>(find.descendant(of: scope, matching: find.byType(RichText)))
      .map((r) => r.text.toPlainText())
      .join('\n');

  // 当前屏幕上(后台页签不算)没有一处 emoji
  void expectNoEmojiOnScreen(WidgetTester tester) {
    final found = [
      for (final r in tester.widgetList<RichText>(find.byType(RichText)))
        if (emoji.hasMatch(r.text.toPlainText())) r.text.toPlainText(),
    ];
    expect(found, isEmpty);
  }

  // 行内图标跟着所在那行字的大小走,不是默认的 24
  void expectSizedToText(WidgetTester tester, Finder icon) {
    final line = tester.widget<RichText>(find.ancestor(of: icon, matching: find.byType(RichText)).first);
    final fontSize = line.text.style!.fontSize!;
    expect(tester.getSize(icon).height, inInclusiveRange(fontSize, fontSize * 1.5));
  }

  test('emoji 判定:原来界面上的 👤 ⭐ 🏫 算,✓ ⚠ · 不算', () {
    for (final ch in ['👤', '⭐', '🏫']) {
      expect(emoji.hasMatch(ch), isTrue, reason: ch);
    }
    for (final ch in ['✓', '⚠', '·', '¥', '￼']) {
      expect(emoji.hasMatch(ch), isFalse, reason: ch);
    }
  });

  for (final lang in ['zh', 'en']) {
    final zh = lang == 'zh';

    testWidgets('[$lang] 日程与待办:负责人前是人像图标,不是 emoji', (tester) async {
      await pump(tester, lang);
      // 今日页用的是同样的 EventRow / TaskTile
      expect(find.byIcon(Icons.person_outline), findsWidgets);
      expectNoEmojiOnScreen(tester);

      await go(tester, nav(zh ? '日程' : 'Calendar'));
      final piano = find.ancestor(of: find.text(zh ? '钢琴课' : 'Piano lesson'), matching: find.byType(EventRow));
      final pianoIcon = find.descendant(of: piano, matching: find.byIcon(Icons.person_outline));
      expect(pianoIcon, findsOneWidget);
      expectSizedToText(tester, pianoIcon);
      expect(textOf(tester, piano), contains(zh ? '琴行 · ￼ 妈妈' : 'Music studio · ￼ Mom'));
      expectNoEmojiOnScreen(tester);

      await go(tester, find.textContaining(zh ? '待办 (' : 'Tasks ('));
      final pay = find.ancestor(of: find.text(zh ? '缴费:课后服务费' : 'Pay: after-school program fee'), matching: find.byType(TaskTile));
      expect(find.descendant(of: pay, matching: find.byIcon(Icons.person_outline)), findsOneWidget);
      expect(textOf(tester, pay), contains('¥300 · ￼ ${zh ? '爸爸' : 'Dad'}'));
      // 逾期那行整行标红,图标也跟着红
      final late = find.ancestor(of: find.text(zh ? '签字:校服订购单' : 'Sign: spirit wear order form'), matching: find.byType(TaskTile));
      final lateIcon = find.descendant(of: late, matching: find.byIcon(Icons.person_outline));
      expect(tester.widget<Icon>(lateIcon).color, const Color(0xFFE6563F));
      expectSizedToText(tester, lateIcon);
      expectNoEmojiOnScreen(tester);
    });

    testWidgets('[$lang] 学习记录:专注度是星星图标,老师反馈前是学校图标', (tester) async {
      await pump(tester, lang);
      await go(tester, nav(zh ? '成长' : 'Growth'));
      await go(tester, find.text(zh ? '学习记录' : 'Study log'));
      final teacher = find.textContaining(zh ? '课堂发言积极' : 'Great participation');
      await tester.ensureVisible(teacher);
      await tester.pumpAndSettle();

      // 演示数据:昨天专注度 5、有家长备注;2 天前专注度 4、有老师反馈
      final day2 = find.ancestor(of: teacher, matching: find.byType(ListTile));
      expect(find.descendant(of: day2, matching: find.byIcon(Icons.star)), findsNWidgets(4));
      final school = find.descendant(of: day2, matching: find.byIcon(Icons.school_outlined));
      expect(school, findsOneWidget);
      expectSizedToText(tester, school);
      expect(textOf(tester, day2), contains('￼ ${zh ? '课堂发言积极' : 'Great participation'}'));

      final day1 = find.ancestor(of: find.textContaining(zh ? '数学作业做得快' : 'Math was quick'), matching: find.byType(ListTile));
      expect(find.descendant(of: day1, matching: find.byIcon(Icons.star)), findsNWidgets(5));
      expect(find.descendant(of: day1, matching: find.byIcon(Icons.school_outlined)), findsNothing);

      // 星星没有文字了,读屏照样能读出专注度
      expect(find.bySemanticsLabel(RegExp('${zh ? '专注度' : 'Focus'} 4/5')), findsWidgets);
      expectNoEmojiOnScreen(tester);
    });
  }
}
