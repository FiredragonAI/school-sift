// 冒烟:载入演示数据后五个页签都能渲染,通知详情能走到识别核对并写入;数据落盘后能重新读出。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';
import 'package:school_sift/main.dart';
import 'package:school_sift/store/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Hive 是真实文件 IO,在 testWidgets 的 FakeAsync 里永远等不到(连 close 都会卡住),
  // 所以 widget 测试用 inMemory 模式,持久化单独用普通 test 验证。

  Future<AppState> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final st = AppState();
    await st.load(inMemory: true);
    st.loadDemo();
    await tester.pumpWidget(ChangeNotifierProvider.value(value: st, child: const SchoolSiftApp()));
    await tester.pumpAndSettle();
    return st;
  }

  Finder nav(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  testWidgets('五个页签渲染', (tester) async {
    await pump(tester);
    expect(find.text('今天和明天'), findsOneWidget);
    expect(find.text('要家长办的事'), findsOneWidget);
    await tester.tap(nav('通知'));
    await tester.pumpAndSettle();
    expect(find.text('秋游改期'), findsOneWidget);
    await tester.tap(nav('日程'));
    await tester.pumpAndSettle();
    expect(find.text('接下来'), findsOneWidget);
    await tester.tap(nav('成长'));
    await tester.pumpAndSettle();
    expect(find.text('趋势'), findsOneWidget);
    await tester.tap(nav('更多'));
    await tester.pumpAndSettle();
    expect(find.text('家庭成员'), findsOneWidget);
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('通知 → 识别 → 写入日程与待办', (tester) async {
    final st = await pump(tester);
    final before = st.events.length;
    await tester.tap(nav('通知'));
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

  test('数据与图片落盘后能重新读出(Hive)', () async {
    final dir = Directory.systemTemp.createTempSync('schoolsift_test');
    addTearDown(() => Hive.close());
    final st = AppState();
    await st.load(hivePath: dir.path);
    st.loadDemo();
    final id = st.putImage('aGVsbG8='); // "hello"
    st.upsertTask(st.tasks.first.copyWith(imageId: id));
    final st2 = AppState();
    await st2.load(hivePath: dir.path);
    expect(st2.notices.length, st.notices.length);
    expect(st2.children.length, 2);
    expect(st2.image(id), 'aGVsbG8=');
    // 备份导出带图片;导进一个干净实例后图片还在
    final json = st2.exportJson();
    expect(json, contains('aGVsbG8='));
    final st3 = AppState();
    await st3.load(hivePath: dir.path);
    await st3.clearAll();
    expect(st3.image(id), isNull);
    st3.importJson(json);
    expect(st3.image(id), 'aGVsbG8=');
    expect(st3.tasks.first.imageId, id);
  });
}
