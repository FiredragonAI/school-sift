// 冒烟:载入演示数据后五个页签都能渲染,通知详情能走到识别核对并写入。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:school_sift/main.dart';
import 'package:school_sift/store/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppState> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final st = AppState();
    await st.load();
    st.loadDemo();
    await tester.pumpWidget(ChangeNotifierProvider.value(value: st, child: const SchoolSiftApp()));
    await tester.pumpAndSettle();
    return st;
  }

  testWidgets('五个页签渲染', (tester) async {
    await pump(tester);
    expect(find.text('今天和明天'), findsOneWidget);
    expect(find.text('要家长办的事'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('通知')));
    await tester.pumpAndSettle();
    expect(find.text('秋游改期'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('日程')));
    await tester.pumpAndSettle();
    expect(find.text('接下来'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('成长')));
    await tester.pumpAndSettle();
    expect(find.text('趋势'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('更多')));
    await tester.pumpAndSettle();
    expect(find.text('家庭成员'), findsOneWidget);
  });

  testWidgets('通知 → 识别 → 写入日程与待办', (tester) async {
    final st = await pump(tester);
    final before = st.events.length;
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('通知')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('视力筛查知情同意书'));
    await tester.pumpAndSettle();
    expect(find.text('识别结果 · 请核对'), findsOneWidget);
    expect(find.textContaining('签字'), findsWidgets);
    await tester.ensureVisible(find.text('写入日程与待办'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('写入日程与待办'));
    await tester.pumpAndSettle();
    expect(st.events.length, greaterThan(before));
    expect(st.tasks.any((t) => t.noticeId == 'n4'), isTrue);
    expect(st.notices.firstWhere((n) => n.id == 'n4').processed, isTrue);
  });
}
