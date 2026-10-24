// 「用英文回复」的衡量方式(验证门槛:50 人各用 3 次以上,见 ai-keyboard-research 报告 4.4)。
//
// 学校通没有服务器,也不加统计或埋点,所以:
//   - 用量 = 本机已存的回信条数(不另设计数器、不生成任何 ID)
//   - 第 3 封写完后,结果下面出现一次可关闭的反馈卡:有用 / 一般 / 没用 + 想不想要「任何 App 里都能用
//     的中英键盘」+ 可选一句话
//   - 家长不点「发送」就什么都不发。点了以后:
//       配了反馈表单(构建时 --dart-define=FEEDBACK_FORM_URL=...)→ 打开表单,只预填评分、回信条数、
//         要不要键盘这三个选择项;留言和联系方式由家长在表单里自己填(不进 URL,避免出现在访问日志里)
//       没配 → 把反馈整理成一段文字复制到剪贴板,家长自己贴到家长群或发给开发者
// 这些都是纯函数,界面在 ui/reply_screen.dart 的 ReplyFeedbackCard。

/// 写到第几封时请家长反馈
const int kFeedbackAfterReplies = 3;

/// 构建时注入的反馈表单地址;空 = 只能复制文字。
/// 支持占位符 {rating} {count} {keyboard} {lang},会替换成 URL 编码后的值(Tally 的隐藏字段、
/// Google 表单的 entry.xxx=… 预填都能这样配);没有占位符就原样打开。
const String kFeedbackFormUrl = String.fromEnvironment('FEEDBACK_FORM_URL');

enum FeedbackRating { useful, okay, notUseful }

bool shouldOfferFeedback({required int replyCount, required bool alreadyHandled}) =>
    !alreadyHandled && replyCount >= kFeedbackAfterReplies;

String ratingCode(FeedbackRating r) => switch (r) {
      FeedbackRating.useful => 'useful',
      FeedbackRating.okay => 'okay',
      FeedbackRating.notUseful => 'not_useful',
    };

/// 表单地址:只放三个选择项和条数,不放留言。模板为空或不是 http(s) 时返回 null。
Uri? feedbackFormUri(
  String template, {
  required FeedbackRating rating,
  required int replyCount,
  required bool wantsKeyboard,
  required String lang,
}) {
  final t = template.trim();
  if (t.isEmpty) return null;
  final values = {
    'rating': ratingCode(rating),
    'count': '$replyCount',
    'keyboard': wantsKeyboard ? 'yes' : 'no',
    'lang': lang,
  };
  var out = t;
  values.forEach((k, v) => out = out.replaceAll('{$k}', Uri.encodeQueryComponent(v)));
  final u = Uri.tryParse(out);
  if (u == null || !(u.scheme == 'https' || u.scheme == 'http') || u.host.isEmpty) return null;
  return u;
}

/// 没有表单时复制给家长的文字。[labels] 由界面按当前语言传入,这里只管拼。
String feedbackPlainText({
  required String header,
  required String ratingLabel,
  required String keyboardLabel,
  required int replyCount,
  required String countLabel,
  String comment = '',
}) {
  final lines = [
    header,
    ratingLabel,
    keyboardLabel,
    '$countLabel: $replyCount',
    if (comment.trim().isNotEmpty) comment.trim(),
  ];
  return lines.join('\n');
}
