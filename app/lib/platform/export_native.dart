import 'dart:convert';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> exportText(String filename, String mime, String content) async {
  await Share.shareXFiles(
    [XFile.fromData(utf8.encode(content), mimeType: mime, name: filename)],
    fileNameOverrides: [filename],
  );
}

Future<void> openUrl(String url) async {
  // 用系统浏览器打开(加到 Google 日历、反馈表单);打不开时退化为分享链接
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok) await Share.share(url);
}

/// 发一段文字给家人(短信 / 微信 / WhatsApp 都行)——F05:对方不用装 App。
Future<bool> shareText(String text, {String? subject}) async {
  await Share.share(text, subject: subject);
  return true;
}
