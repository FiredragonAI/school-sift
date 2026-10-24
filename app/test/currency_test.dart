// 金额的货币:每条待办记自己的货币,取自通知原文($ / dollars / USD / 美元 / 美金 → USD,
// ¥ / ￥ / RMB / 人民币 → CNY);只写「元」「块」或没写的不记,按美元显示(首批用户在加州)。
// 中英文界面显示一样:$300、¥120。0.2 存下的待办没有 currency,也按美元。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:school_sift/core/claude_extractor.dart';
import 'package:school_sift/core/money.dart';
import 'package:school_sift/core/notice_parser.dart';
import 'package:school_sift/l10n/strings.dart';
import 'package:school_sift/main.dart';
import 'package:school_sift/models/models.dart';
import 'package:school_sift/store/app_state.dart';
import 'package:school_sift/ui/calendar_screen.dart';
import 'package:school_sift/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final p = NoticeParser(today: const Day(2026, 10, 1));
  ExtractedItem payIn(String text) => p.parse(text).items.firstWhere((e) => e.type == ItemType.pay);

  group('规则识别:中文通知', () {
    test('只写「元」:金额照认,货币不记,显示成美元', () {
      final it = payIn('本学期课后服务费用300元,请于10月10日前通过缴费平台缴纳。');
      expect(it.amount, 300);
      expect(it.currency, isNull);
      expect(formatAmount(it.amount!, it.currency), '\$300');
    });

    test('人民币 / ¥ / ￥ / RMB → CNY', () {
      for (final text in [
        '春游车费每人人民币50元,请于10月12日前交给班主任。',
        '春游车费每人50元人民币,请于10月12日前交给班主任。',
        '春游车费每人50元(人民币),请于10月12日前交给班主任。',
        '春游车费每人¥50,请于10月12日前交给班主任。',
        '春游车费每人￥50,请于10月12日前交给班主任。',
        '春游车费每人 RMB 50,请于10月12日前交给班主任。',
      ]) {
        final it = payIn(text);
        expect(it.amount, 50, reason: text);
        expect(it.currency, 'CNY', reason: text);
        expect(it.day, const Day(2026, 10, 12), reason: text);
      }
    });

    test('美元 / 美金 / \$ → USD;以前「380美元」连金额都认不出', () {
      for (final text in [
        '中文学校本学期学费380美元,请于10月10日前缴纳。',
        '中文学校本学期学费380美金,请于10月10日前缴纳。',
        '中文学校本学期学费 \$380,请于10月10日前缴纳。',
      ]) {
        final it = payIn(text);
        expect(it.amount, 380, reason: text);
        expect(it.currency, 'USD', reason: text);
      }
    });
  });

  group('规则识别:英文通知', () {
    test('\$ / dollars / USD → USD,千分位也认', () {
      for (final (text, amount) in [
        ('The field trip cost is \$12 per student, due by Oct 17.', 12.0),
        ('After-school program tuition is \$1,250 per semester, due by October 15.', 1250.0),
        ('Please send 20 dollars for the class party by Friday, October 24.', 20.0),
        ('The yearbook is USD 35 if ordered by Oct 20.', 35.0),
      ]) {
        final it = payIn(text);
        expect(it.amount, amount, reason: text);
        expect(it.currency, 'USD', reason: text);
      }
    });

    test('RMB → CNY', () {
      final it = payIn('The China exchange trip deposit is RMB 2,000, due by Oct 30.');
      expect(it.amount, 2000);
      expect(it.currency, 'CNY');
      expect(formatAmount(it.amount!, it.currency), '¥2,000');
    });

    test('英文演示通知「\$300 is due」识别成 USD 300', () {
      final st = AppState()..language = 'en';
      st.loadDemo();
      final n1 = st.notices.firstWhere((n) => n.id == 'n1');
      final it = NoticeParser().parse(n1.body).items.firstWhere((e) => e.type == ItemType.pay);
      expect(it.amount, 300);
      expect(it.currency, 'USD');
    });
  });

  test('Claude:schema 要每条给 currency(USD / CNY / null),返回映射到识别结果', () {
    final item = ClaudeExtractor.schema['properties']['items']['items'] as Map<String, dynamic>;
    expect(item['required'], contains('currency'));
    expect(jsonEncode(item['properties']['currency']), '{"anyOf":[{"type":"string","enum":["USD","CNY"]},{"type":"null"}]}');
    expect(ClaudeExtractor.systemPrompt(today: const Day(2026, 10, 1), uiLang: 'zh'), contains('currency = "USD"'));

    Map<String, dynamic> pay(String date, num amount, Object? currency) =>
        {'type': 'pay', 'title': 'Pay $date', 'date': date, 'start': null, 'end': null, 'location': '', 'amount': amount, 'currency': currency, 'confidence': 0.9, 'evidence': ''};
    final ex = ClaudeExtractor.parseResult({
      'title': 'Fees',
      'reschedule': false,
      'summary': <String>[],
      'items': [
        pay('2026-10-11', 12, 'USD'),
        pay('2026-10-12', 50, 'CNY'),
        pay('2026-10-13', 300, null),
        pay('2026-10-14', 5, 'usd'), // 大小写宽松
        pay('2026-10-15', 5, 'EUR'), // 不认识的不记,按美元显示
      ],
    });
    expect(ex.items.map((i) => i.currency), ['USD', 'CNY', null, 'USD', null]);
  });

  test('待办存货币;0.2 存的数据没有 currency 也能读;打勾(copyWith)不丢货币', () {
    final t = Task(id: 'x', childId: 'c', kind: TaskKind.pay, title: '缴费:春游', amount: 120, currency: 'CNY', createdAt: DateTime(2026, 10, 1));
    final back = Task.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
    expect(back.currency, 'CNY');
    expect(back.copyWith(status: TaskStatus.done).currency, 'CNY');

    final legacy = Task.fromJson({
      'id': 'old', 'childId': 'c', 'kind': 'pay', 'title': '缴费', 'due': '2026-10-10', 'amount': 300,
      'assigneeId': '', 'noticeId': '', 'imageId': null, 'status': 'open', 'createdAt': '2026-10-01T00:00:00.000',
    });
    expect(legacy.currency, isNull);
    expect(formatAmount(legacy.amount!, legacy.currency), '\$300');
  });

  test('显示与输入:\$ / ¥ 加千分位,没记货币按美元;编辑框里的数字', () {
    expect(formatAmount(300, 'USD'), '\$300');
    expect(formatAmount(300, null), '\$300');
    expect(formatAmount(120, 'CNY'), '¥120');
    expect(formatAmount(12.5, 'CNY'), '¥12.50');
    expect(formatAmount(1250, 'USD'), '\$1,250');
    expect(formatAmount(1234567.5, null), '\$1,234,567.50');
    expect(formatAmount(35, 'EUR'), 'EUR 35');
    expect(amountInput(300), '300');
    expect(amountInput(12.5), '12.50');
    expect(parseAmount('1,250'), 1250);
    expect(parseAmount(' \$300 '), 300);
    expect(parseAmount('¥12.5'), 12.5);
    expect(parseAmount(''), isNull);
    expect([nextCurrency(null), nextCurrency('USD'), nextCurrency('CNY')], ['CNY', 'CNY', 'USD']);
  });

  group('界面', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<AppState> pump(WidgetTester tester, String lang, {double width = 600}) async {
      tester.view.physicalSize = Size(width * 2, 2200); // 宽 < 760 都是手机布局
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      final st = AppState();
      await st.load(inMemory: true);
      st.setLanguage(lang); // 演示数据按当前语言生成
      st.loadDemo();
      await tester.pumpWidget(ChangeNotifierProvider.value(value: st, child: const SchoolSiftApp()));
      await tester.pumpAndSettle();
      return st;
    }

    Future<void> go(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    Finder nav(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));
    Finder taskRow(String title) => find.ancestor(of: find.text(title), matching: find.byType(TaskTile));
    String textOf(WidgetTester tester, Finder scope) => tester
        .widgetList<RichText>(find.descendant(of: scope, matching: find.byType(RichText)))
        .map((r) => r.text.toPlainText())
        .join('\n');
    String screenText(WidgetTester tester) => textOf(tester, find.byType(Scaffold).first);
    // 金额前的货币按钮上现在写的是什么
    Finder currencyButton(String symbol) => find.descendant(of: find.byType(AmountField), matching: find.text(symbol));

    for (final lang in ['zh', 'en']) {
      final zh = lang == 'zh';
      final s = S(lang);
      final payTitle = zh ? '缴费:课后服务费' : 'Pay: after-school program fee';

      testWidgets('[$lang] 今日页、待办列表、发给家人、CSV:\$300,人民币的是 ¥120,旧数据按 \$', (tester) async {
        final st = await pump(tester, lang);
        // 中文演示通知写「300元」(不记货币),英文写「\$300」(USD):都显示 $300
        expect(textOf(tester, taskRow(payTitle)), contains('\$300'));
        expect(screenText(tester), isNot(contains('¥')));

        st.upsertTask(Task(id: 'cny', childId: 'c_a', kind: TaskKind.pay, title: zh ? '缴费:国内夏令营' : 'Pay: China summer camp', due: Day.today().add(3), amount: 120, currency: 'CNY', createdAt: DateTime.now()));
        await tester.pumpAndSettle();
        final cnyTitle = zh ? '缴费:国内夏令营' : 'Pay: China summer camp';
        expect(textOf(tester, taskRow(cnyTitle)), contains('¥120'));

        await go(tester, nav(s.tabCalendar));
        await go(tester, find.textContaining('${s.viewTasks} ('));
        expect(textOf(tester, taskRow(payTitle)), contains('\$300'));
        expect(textOf(tester, taskRow(cnyTitle)), contains('¥120'));
        await go(tester, find.text('${s.done} · 2')); // 已完成的「秋季校服 / yearbook」
        expect(textOf(tester, taskRow(zh ? '缴费:秋季校服' : 'Pay: yearbook')), contains(zh ? '\$260' : '\$35'));

        final t2 = st.tasks.firstWhere((t) => t.id == 't2');
        expect(taskShareText(s, st, t2), contains('· \$300'));
        expect(taskShareText(s, st, st.tasks.firstWhere((t) => t.id == 'cny')), contains('· ¥120'));

        final csv = st.exportCsv('tasks').split('\r\n');
        expect(csv.first, endsWith('child,kind,title,due,amount,currency,assignee,status,created'));
        List<String> row(String title) => csv.firstWhere((l) => l.contains(title)).split(',');
        expect(row(payTitle).sublist(4, 6), ['300.0', 'USD']);
        expect(row(cnyTitle).sublist(4, 6), ['120.0', 'CNY']);
        expect(row(zh ? '签字:家长会回执' : 'Sign: conference request form').sublist(4, 6), ['', ''], reason: '没有金额就不写货币');

        // 0.2 的备份:待办里没有 currency 这个键
        final old = st.toJson();
        for (final t in old['tasks'] as List) {
          (t as Map).remove('currency');
        }
        st.importJson(jsonEncode(old));
        await tester.pumpAndSettle();
        expect(st.tasks.every((t) => t.currency == null), isTrue);
        expect(textOf(tester, taskRow(payTitle)), contains('\$300'));
        expect(textOf(tester, taskRow(cnyTitle)), contains('\$120'));
      });

      testWidgets('[$lang] 待办编辑:点金额前的 \$ 换成 ¥,保存后列表显示 ¥300', (tester) async {
        final st = await pump(tester, lang);
        await go(tester, nav(s.tabCalendar));
        await go(tester, find.textContaining('${s.viewTasks} ('));

        await go(tester, find.text(payTitle));
        expect(currencyButton('\$'), findsOneWidget);
        expect(find.bySemanticsLabel(s.currencyName('USD')), findsOneWidget);
        await go(tester, find.byTooltip(s.currencySwitch));
        expect(currencyButton('¥'), findsOneWidget);
        expect(find.bySemanticsLabel(s.currencyName('CNY')), findsOneWidget);
        await go(tester, find.text(s.save));
        expect(st.tasks.firstWhere((t) => t.id == 't2').currency, 'CNY');
        expect(textOf(tester, taskRow(payTitle)), contains('¥300'));

        // 再点一下换回美元
        await go(tester, find.text(payTitle));
        expect(currencyButton('¥'), findsOneWidget);
        await go(tester, find.byTooltip(s.currencySwitch));
        await go(tester, find.text(s.save));
        expect(st.tasks.firstWhere((t) => t.id == 't2').currency, 'USD');
        expect(textOf(tester, taskRow(payTitle)), contains('\$300'));
      });

      testWidgets('[$lang] 识别结果页:通知写人民币,金额前就是 ¥;写入后待办显示 ¥', (tester) async {
        // 测试字体每个字都是 1 em 宽:600 宽时,英文通知详情页顶部那行(孩子、已处理、离线规则、来源)
        // 在写入后会溢出 67 px。那行本来就这样,与货币无关,这里用 750 宽避开
        final st = await pump(tester, lang, width: 750);
        final d = Day.today().add(10);
        final title = zh ? '春游车费' : 'China exchange trip';
        st.addNotice(Notice(
          id: 'n_cny',
          childId: 'c_a',
          title: title,
          source: 'paste',
          receivedAt: DateTime.now(),
          body: zh ? '春游车费每人人民币50元,请于${d.m}月${d.d}日前交给班主任。' : 'The China exchange trip deposit is RMB 2,000, due by ${s.monthName(d.m)} ${d.d}.',
        ));
        await go(tester, nav(s.tabInbox));
        await go(tester, find.text(title)); // 没处理过的通知一打开就离线识别

        expect(find.text(s.extractTitle), findsOneWidget);
        expect(currencyButton('¥'), findsOneWidget);
        // 识别结果页上也能切换
        await go(tester, find.byTooltip(s.currencySwitch));
        expect(currencyButton('\$'), findsOneWidget);
        await go(tester, find.byTooltip(s.currencySwitch));
        expect(currencyButton('¥'), findsOneWidget);

        await go(tester, find.text(s.commit));
        final t = st.tasks.firstWhere((t) => t.noticeId == 'n_cny');
        expect((t.kind, t.amount, t.currency), (TaskKind.pay, zh ? 50.0 : 2000.0, 'CNY'));

        tester.state<NavigatorState>(find.byType(Navigator).first).pop(); // 返回键的提示文字随界面语言变
        await tester.pumpAndSettle();
        await go(tester, nav(s.tabCalendar));
        await go(tester, find.textContaining('${s.viewTasks} ('));
        expect(textOf(tester, taskRow(t.title)), contains(zh ? '¥50' : '¥2,000'));
      });
    }
  });
}
