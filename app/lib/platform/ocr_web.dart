import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const bool ocrSupported = true;
const String ocrEngineName = 'Tesseract.js';

const _scriptUrl = 'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js';
Future<void>? _loading;

Future<void> _ensureLoaded() {
  if (web.window.has('Tesseract')) return Future.value();
  return _loading ??= () {
    final c = Completer<void>();
    final s = web.HTMLScriptElement()
      ..src = _scriptUrl
      ..async = true;
    s.onload = ((web.Event _) => c.complete()).toJS;
    s.onerror = ((web.Event _) => c.completeError(StateError('无法加载 Tesseract.js(需要联网一次)'))).toJS;
    web.document.head!.append(s);
    return c.future;
  }();
}

@JS('Tesseract.recognize')
external JSPromise<JSObject> _recognize(JSString image, JSString lang, JSObject options);

/// [lang] 是 Tesseract 语言码:eng / chi_sim / eng+chi_sim。
/// 第一次用某种语言会从 CDN 下载训练数据(eng ≈ 4 MB,chi_sim ≈ 20 MB),之后浏览器缓存。
Future<String> ocrImage(Uint8List bytes, {required String lang, void Function(double)? onProgress}) async {
  await _ensureLoaded();
  final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
  final opts = JSObject();
  if (onProgress != null) {
    opts['logger'] = ((JSObject m) {
      final status = (m['status'] as JSString?)?.toDart ?? '';
      final p = (m['progress'] as JSNumber?)?.toDartDouble ?? 0;
      if (status == 'recognizing text') onProgress(p);
    }).toJS;
  }
  final res = await _recognize(dataUrl.toJS, lang.toJS, opts).toDart;
  final data = res['data'] as JSObject;
  return ((data['text'] as JSString?)?.toDart ?? '').trim();
}
