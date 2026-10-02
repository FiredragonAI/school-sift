import 'dart:convert';

import 'package:share_plus/share_plus.dart';

Future<void> exportText(String filename, String mime, String content) async {
  await Share.shareXFiles(
    [XFile.fromData(utf8.encode(content), mimeType: mime, name: filename)],
    fileNameOverrides: [filename],
  );
}

Future<void> openUrl(String url) async {
  // 原生端没有 url_launcher 时退化为分享链接
  await Share.share(url);
}
