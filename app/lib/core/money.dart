// 金额与货币。每条待办记自己的货币(ISO 4217 代码:USD / CNY),取自通知原文,
// 识别结果页和待办编辑里点金额前的符号可以改。
// 没记货币的一律按美元显示:0.2 及以前存的待办、手动新建的、通知只写了「元」「块」或根本没写的。
// 首批用户在加州,美国的中文学校、课后班、家长群里说「300元」一般也是指美元。

/// 没记货币时按这个显示
const defaultCurrency = 'USD';

/// 金额前的货币按钮依次切换这几种;也是 Claude 抽取时 currency 字段的可选值
const currencies = ['USD', 'CNY'];

/// 中英文界面一样:$300、¥120(中文界面里 $ 本来就是美元的常见写法)
String currencySymbol(String? currency) => switch (currency ?? defaultCurrency) {
      'USD' => r'$',
      'CNY' => '¥',
      final code => '$code ', // 导入的备份里手写了别的代码:原样显示,不猜
    };

/// 金额前的货币按钮点一下换成哪个
String nextCurrency(String? currency) => currencies[(currencies.indexOf(currency ?? defaultCurrency) + 1) % currencies.length];

/// 编辑框里的数字:整数不带小数点,否则两位小数(300、12.50)
String amountInput(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 2);

/// 读编辑框里的数字。千分位逗号、货币符号和空格都去掉,「1,250」「$300」也认得
double? parseAmount(String s) => double.tryParse(s.replaceAll(RegExp(r'[,\s$¥￥]'), ''));

/// 显示用:$300、¥12.50、$1,250
String formatAmount(double v, String? currency) => '${currencySymbol(currency)}${_grouped(amountInput(v))}';

String _grouped(String n) {
  final neg = n.startsWith('-');
  final digits = neg ? n.substring(1) : n;
  final dot = digits.indexOf('.');
  final whole = dot < 0 ? digits : digits.substring(0, dot);
  final b = StringBuffer(neg ? '-' : '');
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) b.write(',');
    b.write(whole[i]);
  }
  if (dot >= 0) b.write(digits.substring(dot));
  return b.toString();
}
