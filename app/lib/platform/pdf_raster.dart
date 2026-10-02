// PDF → 每页一张 PNG。Android 用系统 PdfRenderer,Web 用 pdf.js(printing 插件按需加载)。
// 之后和拍照走同一条路:本机 OCR 或发给 AI。

import 'dart:typed_data';

import 'package:printing/printing.dart';

Future<List<Uint8List>> rasterizePdf(Uint8List pdf, {int maxPages = 4, double dpi = 120}) async {
  final out = <Uint8List>[];
  await for (final page in Printing.raster(pdf, pages: List.generate(maxPages, (i) => i), dpi: dpi)) {
    out.add(await page.toPng());
  }
  return out;
}
