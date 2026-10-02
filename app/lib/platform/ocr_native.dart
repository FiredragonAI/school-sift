import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

const bool ocrSupported = true;
const String ocrEngineName = 'ML Kit';

/// [lang] 与 Web 端同一套码:含 chi → 中文模型(也认拉丁字母),否则拉丁模型。
Future<String> ocrImage(Uint8List bytes, {required String lang, void Function(double)? onProgress}) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg');
  await f.writeAsBytes(bytes, flush: true);
  final rec = TextRecognizer(script: lang.contains('chi') ? TextRecognitionScript.chinese : TextRecognitionScript.latin);
  try {
    onProgress?.call(0.2);
    final r = await rec.processImage(InputImage.fromFilePath(f.path));
    onProgress?.call(1);
    // 按行拼,保留段落结构,规则解析器靠换行切句
    return r.blocks.map((b) => b.lines.map((l) => l.text).join('\n')).join('\n').trim();
  } finally {
    await rec.close();
    try {
      await f.delete();
    } catch (_) {}
  }
}
