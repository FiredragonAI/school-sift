// 核对打包字体:lib/ 用到的字符都在 assets/fonts/NotoSansSC-*.otf 里(harfbuzz 读 cmap)。
//
// Web 端(CanvasKit)没有系统字体,子集里没有的字只能等 Google 字体 CDN 补,CDN 不通就是 □。
// 列出 lib/ 下 .dart 源码里出现、字体 cmap 里没有的字符。不算缺字的两类:
//   - emoji(Emoji_Presentation,如 👤 🏫 ⭐):CJK 字库本来就没有,交给系统 / 引擎的 emoji 字体
//   - 不可见的格式字符(Default_Ignorable_Code_Point,如导出 CSV 用的 BOM U+FEFF)
// 另外核对 · • ‘ ’ “ ” 在西文里是比例宽度(见 subset.mjs),否则英文里 "Don’t" 会变成 "Don’ t";
// 以及 subset.mjs 第二遍只留简体语言系统、横排默认 feature 之后,界面用得到的替换、连字和字距都还在(LAYOUT)。
// 有问题时退出码 1。test/font_coverage_test.dart 是前两项的 Dart 版(不排版),CI 跑那个。
//
// 用法:node check.mjs [lib 目录]
//   默认查本仓库的 app/lib;也可以指向别的分支检出的 lib/,看那边新加的文案是否都覆盖了。

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import hbPromise from 'harfbuzzjs';

const here = dirname(fileURLToPath(import.meta.url));
const appRoot = resolve(here, '..', '..');
export const fontPaths = ['Regular', 'Bold'].map((w) => join(appRoot, 'assets', 'fonts', `NotoSansSC-${w}.otf`));
export const PROPORTIONAL = [...'·•‘’“”'];
const exempt = /[\p{Emoji_Presentation}\p{Default_Ignorable_Code_Point}]/u;
export const hex = (c) => `U+${c.toString(16).toUpperCase().padStart(4, '0')}`;

// 版式:shape(文本, 文种, 语言) → harfbuzz 排出的字形。英文界面的语言是 en,中文界面是 zh。
const LAYOUT = [
  ['西文里 … 换成基线省略号(latn 默认语言系统的 locl)', (shape) => shape('…', 'Latn', 'en')[0].g !== shape('…', 'Hani', 'zh')[0].g],
  ['中文里 — 是全角、西文里不是(ZHS 的 locl)', (shape, upem) => shape('—', 'Hani', 'zh')[0].ax >= upem && shape('—', 'Latn', 'en')[0].ax < upem],
  ['—— 连成一个字形', (shape) => shape('——', 'Hani', 'zh').length === 1 && shape('——', 'Latn', 'en').length === 1],
  ['fi 连字', (shape) => shape('fi', 'Latn', 'en').length === 1],
  ['字距(To 比 T 单独排窄)', (shape) => shape('To', 'Latn', 'en')[0].ax < shape('T', 'Latn', 'en')[0].ax],
];

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (name.endsWith('.dart')) out.push(p);
  }
  return out;
}

/** lib/ 里出现的非 ASCII 字符 → Map(码位 → 出现过的文件) */
export function usedChars(libDir) {
  const used = new Map();
  for (const f of walk(libDir)) {
    for (const ch of readFileSync(f, 'utf8')) {
      const c = ch.codePointAt(0);
      if (c <= 0x7e) continue;
      if (!used.has(c)) used.set(c, new Set());
      used.get(c).add(f.slice(libDir.length + 1).replaceAll('\\', '/'));
    }
  }
  return used;
}

/** 指定文种、语言排一段横排文本 → harfbuzz 的字形列表 */
function shapeText(hb, font, text, script, language) {
  const buf = hb.createBuffer();
  buf.addText(text);
  buf.setDirection('ltr');
  buf.setScript(script);
  buf.setLanguage(language);
  hb.shape(font, buf);
  const glyphs = buf.json();
  buf.destroy();
  return glyphs;
}

/** 西文语境下(Latn / en)这个字符排出来的字形与字宽 */
export function shapeLatin(hb, font, ch) {
  return shapeText(hb, font, ch, 'Latn', 'en')[0];
}

/** → { ok, lines } */
export async function checkFonts(libDir = join(appRoot, 'lib'), fonts = fontPaths) {
  const hb = await hbPromise;
  const used = [...usedChars(libDir)].sort((a, b) => a[0] - b[0]);
  const lines = [`${libDir}: ${used.length} 个不同的非 ASCII 字符`];
  let ok = true;
  for (const path of fonts) {
    const blob = hb.createBlob(readFileSync(path));
    const face = hb.createFace(blob, 0);
    const font = hb.createFont(face);
    const cmap = new Set(face.collectUnicodes());
    const missing = [];
    const skipped = [];
    for (const [c, files] of used) {
      if (cmap.has(c)) continue;
      const ch = String.fromCodePoint(c);
      (exempt.test(ch) ? skipped : missing).push(`${hex(c)} ${ch}  ${[...files].join(', ')}`);
    }
    const wide = [];
    for (const ch of PROPORTIONAL) {
      if (!cmap.has(ch.codePointAt(0))) continue;
      const g = shapeLatin(hb, font, ch);
      if (g.ax >= face.upem) wide.push(`${hex(ch.codePointAt(0))} ${ch} 字宽 ${g.ax}/${face.upem}`);
    }
    const shape = (text, script, language) => shapeText(hb, font, text, script, language);
    const layoutLost = LAYOUT.filter(([, works]) => !works(shape, face.upem)).map(([what]) => what);
    lines.push(`${basename(path)}: cmap ${cmap.size} 个码位`);
    lines.push(missing.length ? `  缺 ${missing.length} 个:` : '  lib/ 用到的字符都有', ...missing.map((s) => `    ${s}`));
    if (skipped.length) lines.push(`  不算缺字(emoji / 不可见格式字符)${skipped.length} 个:`, ...skipped.map((s) => `    ${s}`));
    if (wide.length) lines.push('  这些标点是全角字形,英文里会出现空隙:', ...wide.map((s) => `    ${s}`));
    lines.push(layoutLost.length ? '  版式丢了(subset.mjs 的 FEATURES / KEEP_LANGSYS 裁多了?):' : `  版式:${LAYOUT.length} 项替换 / 连字 / 字距都在`,
      ...layoutLost.map((s) => `    ${s}`));
    if (missing.length || wide.length || layoutLost.length) ok = false;
    font.destroy();
    face.destroy();
    blob.destroy();
  }
  return { ok, lines };
}

const isMain = process.argv[1] && resolve(process.argv[1]).toLowerCase() === fileURLToPath(import.meta.url).toLowerCase();
if (isMain) {
  const { ok, lines } = await checkFonts(process.argv[2] ? resolve(process.argv[2]) : undefined);
  console.log(lines.join('\n'));
  // 不用 process.exit():Windows 上 V8 后台还在优化 harfbuzz 的 wasm 时硬退出,偶尔触发 libuv 断言(退出码 127)
  process.exitCode = ok ? 0 : 1;
}
