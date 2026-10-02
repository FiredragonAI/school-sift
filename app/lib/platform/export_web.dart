import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

Future<void> exportText(String filename, String mime, String content) async {
  final bytes = utf8.encode(content);
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}

Future<void> openUrl(String url) async {
  web.window.open(url, '_blank');
}

/// 发一段文字:支持 Web Share 的浏览器(手机)弹分享面板;否则返回 false,由调用方复制到剪贴板。
Future<bool> shareText(String text, {String? subject}) async {
  final nav = web.window.navigator;
  if (!nav.has('share')) return false;
  try {
    await nav.share(web.ShareData(text: text, title: subject ?? '')).toDart;
    return true;
  } catch (_) {
    return false;
  }
}
