// 通知详情页顶部那一行:孩子 · 已处理/待确认 · AI/离线规则 · 来源。
// 窄屏手机上不能溢出,也不能把「来源」挤出屏幕;放得下时还是原来的一行,来源靠右。
// 测试字体每个字都是 1 em 宽,英文比真实字体宽得多:这里 360 宽就溢出,
// 对应真实构建里 375 宽(iPhone SE / mini)把 "Source: Demo" 切成 "Source: Dem"。

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:school_sift/main.dart';
import 'package:school_sift/store/app_state.dart';
import 'package:school_sift/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // 先按 750 宽打开(今日页等其他页面在测试字体下也有窄屏溢出,与本测试无关),
  // 进到通知详情后再把窗口改成要测的宽度,这时只有详情页在台上参与布局。
  Future<AppState> openNotice(WidgetTester tester, {required String lang, required String title, required double width}) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(1500, 1800);
    addTearDown(tester.view.reset);
    final st = AppState();
    await st.load(inMemory: true);
    st.setLanguage(lang);
    st.loadDemo();
    await tester.pumpWidget(ChangeNotifierProvider.value(value: st, child: const SchoolSiftApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(lang == 'en' ? 'Notices' : '通知')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    tester.view.physicalSize = Size(width * 2, 812 * 2);
    await tester.pumpAndSettle();
    return st;
  }

  Rect chipOf(WidgetTester tester, String label) => tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(Chip)));

  // 四项都完整地在页边距以内、互不重叠;要么还在一行(来源靠右),要么来源单独在最下面一行(靠左)
  void expectHeaderFits(WidgetTester tester, double width, {required String processed, required String rules, required String source}) {
    final tags = [tester.getRect(find.byType(ChildTag)), chipOf(tester, processed), chipOf(tester, rules)];
    final src = tester.getRect(find.text(source));
    final all = [...tags, src];
    for (var i = 0; i < all.length; i++) {
      expect(all[i].left, greaterThanOrEqualTo(16), reason: '${all[i]}');
      expect(all[i].right, lessThanOrEqualTo(width - 16), reason: '${all[i]}');
      for (var j = i + 1; j < all.length; j++) {
        expect(all[i].overlaps(all[j]), isFalse, reason: '${all[i]} / ${all[j]}');
      }
    }
    if (tags.every((r) => (r.center.dy - src.center.dy).abs() < 0.5)) {
      expect(src.right, moreOrLessEquals(width - 16));
    } else {
      expect(src.left, moreOrLessEquals(16));
      expect(src.top, greaterThanOrEqualTo(tags.map((r) => r.bottom).reduce(math.max)));
    }
  }

  const cases = [
    (lang: 'en', title: 'Parent-Teacher Conferences', processed: 'Processed', rules: 'Offline rules', source: 'Source: Demo'),
    (lang: 'zh', title: '三年级家长会通知', processed: '已处理', rules: '离线规则', source: '来源: 演示'),
  ];

  for (final c in cases) {
    for (final width in [360.0, 320.0]) {
      testWidgets('${c.lang} 已处理的通知,$width 宽:顶部一行不溢出,四项都在屏幕里', (tester) async {
        await openNotice(tester, lang: c.lang, title: c.title, width: width);
        expect(tester.takeException(), isNull);
        expectHeaderFits(tester, width, processed: c.processed, rules: c.rules, source: c.source);
      });
    }

    testWidgets('${c.lang} 放得下时还是一行:孩子靠左、两个标签依次排开、来源靠右', (tester) async {
      const width = 700.0; // 仍是手机布局(< 760)
      await openNotice(tester, lang: c.lang, title: c.title, width: width);
      expect(tester.takeException(), isNull);
      final tag = tester.getRect(find.byType(ChildTag));
      final done = chipOf(tester, c.processed);
      final rules = chipOf(tester, c.rules);
      final source = tester.getRect(find.text(c.source));
      expect(tag.left, moreOrLessEquals(16));
      expect(done.left, moreOrLessEquals(tag.right + 8));
      expect(rules.left, moreOrLessEquals(done.right + 6));
      expect(source.right, moreOrLessEquals(width - 16));
      for (final r in [tag, done, rules]) {
        expect(r.center.dy, moreOrLessEquals(source.center.dy), reason: '$r');
      }
    });
  }

  testWidgets('en 核对后写入:标签变成 Processed · Offline rules 也不溢出', (tester) async {
    const width = 600.0;
    final st = await openNotice(tester, lang: 'en', title: 'Vision screening consent', width: width);
    expect(find.text('Review extraction'), findsOneWidget);
    await tester.ensureVisible(find.text('Add to calendar & tasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to calendar & tasks'));
    await tester.pumpAndSettle();
    expect(st.notices.firstWhere((n) => n.id == 'n4').processed, isTrue);
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expectHeaderFits(tester, width, processed: 'Processed', rules: 'Offline rules', source: 'Source: Demo');
  });
}
