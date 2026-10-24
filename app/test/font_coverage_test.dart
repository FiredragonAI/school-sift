// 打包字体的覆盖检查:lib/ 里出现的字符都要在 Noto Sans SC 子集里。
//
// Web 端(CanvasKit)没有系统字体,子集里没有的字只能等 Google 字体 CDN 补,CDN 不通就是 □。
// 首版字体是在界面文案写出来之前裁的,漏了 → · — … ’ “ ” ✓ ⚠ 等十几个符号,一直没人发现。
// 不算缺字:emoji(CJK 字库本来就没有)和不可见的格式字符(如导出 CSV 用的 BOM)。
// 失败时按 tools/fontsubset/subset.mjs 开头的说明重新裁剪;重裁后还缺的是字库里本来就没有的字,
// 换一个字库里有的字符。同一检查的 harfbuzz 版:node tools/fontsubset/check.mjs。

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final used = <int, Set<String>>{};
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    for (final r in f.readAsStringSync().runes) {
      if (r > 0x7e) used.putIfAbsent(r, () => {}).add(f.path.replaceAll(r'\', '/'));
    }
  }
  // flutter analyze 的 valid_regexps 不认识 emoji 类的 Unicode 属性而误报;dart analyze 与 flutter test 都认
  // ignore: valid_regexps
  final exempt = RegExp(r'[\p{Emoji_Presentation}\p{Default_Ignorable_Code_Point}]', unicode: true);

  for (final weight in ['Regular', 'Bold']) {
    final font = _Font(File('assets/fonts/NotoSansSC-$weight.otf').readAsBytesSync());

    test('NotoSansSC-$weight 覆盖 lib/ 用到的字符', () {
      final missing = [
        for (final e in used.entries)
          if (!font.cmap.containsKey(e.key) && !exempt.hasMatch(String.fromCharCode(e.key)))
            '${_hex(e.key)} ${String.fromCharCode(e.key)}(${e.value.join(', ')})',
      ];
      expect(missing, isEmpty, reason: 'lib/ 用了、字体里没有的字符;重新裁剪字体,或换成字库里有的字符');
    });

    // SC 版字库默认把这几个标点映射成全角字形,英文里 "Don’t" 会变成 "Don’ t";subset.mjs 已改成比例宽度
    test('NotoSansSC-$weight 的 · • ‘ ’ “ ” 是比例宽度', () {
      for (final c in '·•‘’“”'.runes) {
        final g = font.cmap[c];
        if (g == null) continue;
        expect(font.advance(g), lessThan(font.unitsPerEm), reason: '${_hex(c)} ${String.fromCharCode(c)} 是全角字形');
      }
    });
  }
}

String _hex(int c) => 'U+${c.toRadixString(16).toUpperCase().padLeft(4, '0')}';

/// 只读 cmap(format 4 / 12)、head、hhea、hmtx 的最小 OpenType 解析。
class _Font {
  _Font(Uint8List bytes) : _d = ByteData.sublistView(bytes) {
    final tables = <String, int>{};
    for (var i = 0; i < _d.getUint16(4); i++) {
      final r = 12 + 16 * i;
      tables[String.fromCharCodes(bytes, r, r + 4)] = _d.getUint32(r + 8);
    }
    unitsPerEm = _d.getUint16(tables['head']! + 18);
    _numHMetrics = _d.getUint16(tables['hhea']! + 34);
    _hmtx = tables['hmtx']!;
    _readCmap(tables['cmap']!);
  }

  final ByteData _d;
  late final int unitsPerEm;
  late final int _numHMetrics;
  late final int _hmtx;
  final cmap = <int, int>{};

  int advance(int glyph) => _d.getUint16(_hmtx + 4 * (glyph < _numHMetrics ? glyph : _numHMetrics - 1));

  void _readCmap(int base) {
    for (var i = 0; i < _d.getUint16(base + 2); i++) {
      final sub = base + _d.getUint32(base + 8 + 8 * i);
      switch (_d.getUint16(sub)) {
        case 4:
          final segX2 = _d.getUint16(sub + 6);
          final ends = sub + 14, starts = ends + segX2 + 2, deltas = starts + segX2, ranges = deltas + segX2;
          for (var s = 0; s < segX2; s += 2) {
            final start = _d.getUint16(starts + s), end = _d.getUint16(ends + s);
            final delta = _d.getUint16(deltas + s), ro = _d.getUint16(ranges + s);
            for (var c = start; c <= end && c != 0xFFFF; c++) {
              final g = ro == 0 ? c : _d.getUint16(ranges + s + ro + 2 * (c - start));
              if (ro != 0 && g == 0) continue;
              final glyph = (g + delta) & 0xFFFF;
              if (glyph != 0) cmap[c] = glyph;
            }
          }
        case 12:
          for (var k = 0; k < _d.getUint32(sub + 12); k++) {
            final r = sub + 16 + 12 * k;
            final start = _d.getUint32(r), end = _d.getUint32(r + 4), first = _d.getUint32(r + 8);
            for (var c = start; c <= end; c++) {
              cmap[c] = first + c - start;
            }
          }
      }
    }
  }
}
