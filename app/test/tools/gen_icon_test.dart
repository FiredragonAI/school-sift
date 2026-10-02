// 不是测试,是图标生成器:借 widget 测试环境把 Canvas 画的 Logo 导出成 PNG,
// 写到 Android mipmap 与 web/icons。改图标只改 _IconPainter,然后:
//   flutter test test/tools/gen_icon_test.dart (环境变量 GEN_ICON=1)
// 不设环境变量时直接跳过,所以平时 `flutter test` 不会重写文件。

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _enabled = Platform.environment['GEN_ICON'] == '1';

class IconPainter extends CustomPainter {
  final bool maskable; // 可遮罩图标:内容缩进到安全区
  IconPainter({this.maskable = false});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E6BE6), Color(0xFF5BB0FF)],
      ).createShader(rect);
    if (maskable) {
      canvas.drawRect(rect, bg);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(s * 0.22)), bg);
    }
    // 学士帽:菱形帽顶 + 弧形帽身 + 流苏
    final k = maskable ? 0.78 : 1.0;
    final cx = s / 2, cy = s * 0.5;
    final w = s * 0.34 * k, h = s * 0.13 * k;
    final white = Paint()..color = Colors.white;
    final top = Path()
      ..moveTo(cx, cy - h * 1.6)
      ..lineTo(cx + w, cy - h * 0.4)
      ..lineTo(cx, cy + h * 0.8)
      ..lineTo(cx - w, cy - h * 0.4)
      ..close();
    canvas.drawPath(top, white);
    final body = Path()
      ..moveTo(cx - w * 0.55, cy + h * 0.1)
      ..lineTo(cx - w * 0.55, cy + h * 1.5)
      ..quadraticBezierTo(cx, cy + h * 2.6, cx + w * 0.55, cy + h * 1.5)
      ..lineTo(cx + w * 0.55, cy + h * 0.1)
      ..lineTo(cx, cy + h * 0.8)
      ..close();
    canvas.drawPath(body, Paint()..color = Colors.white.withValues(alpha: 0.85));
    final tassel = Paint()
      ..color = const Color(0xFFFFD166)
      ..strokeWidth = s * 0.03 * k
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx + w, cy - h * 0.4), Offset(cx + w, cy + h * 1.6), tassel);
    canvas.drawCircle(Offset(cx + w, cy + h * 1.8), s * 0.035 * k, Paint()..color = const Color(0xFFFFD166));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

Future<void> _write(String path, int size, {bool maskable = false}) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  IconPainter(maskable: maskable).paint(canvas, Size.square(size.toDouble()));
  final img = await rec.endRecording().toImage(size, size);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  final f = File(path);
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('generate icons', () async {
    if (!_enabled) return;
    const android = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final e in android.entries) {
      await _write('android/app/src/main/res/mipmap-${e.key}/ic_launcher.png', e.value);
    }
    await _write('web/icons/Icon-192.png', 192);
    await _write('web/icons/Icon-512.png', 512);
    await _write('web/icons/Icon-maskable-192.png', 192, maskable: true);
    await _write('web/icons/Icon-maskable-512.png', 512, maskable: true);
    await _write('web/favicon.png', 64);
    await _write('../docs/icon-512.png', 512);
  });
}
