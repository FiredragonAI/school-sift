// 从 Noto Sans CJK SC 全字库裁出 app 用得到的子集,写到 assets/fonts/。
//
// 为什么要裁:全字库单个字重 ~16 MB,两个字重打进 Web 包和 APK 都太重。
// 为什么要打:Web 端(CanvasKit)没有系统字体可回退,theme 指定的 NotoSansSC
// 不在包里时,首帧部分汉字是 □,靠 Google 字体 CDN 几秒后补——大陆用户补不上。
//
// 字符集 = 几部分的并集:
//   1. lib/ 下所有 .dart 源码里出现的非 ASCII 字符(界面文案,包括 → · — … ✓ ⚠ ▲ 这类符号)
//   2. GB2312 全部 6763 个汉字(一级 3755 + 二级 3008),兜住用户手输的学校名/人名
//   3. CJK 标点区 U+3000–U+303F(、。「」《》…)与全角区 U+FF00–U+FFEF(全角标点/数字/字母)
//   外加 ASCII 可见字符(含数字、字母)。生僻字仍走引擎的网络回退。
//
// 改了界面文案就要重跑:第 1 部分是跑脚本那一刻 lib/ 的快照。首版字体是在界面文案写出来之前
//   裁的(当时 lib/ 只有 155 个非 ASCII 字符,全在 2、3 里),后来文案用到的 → · — – … ’ “ ” • ¥ ≈
//   ▲ ▼ ✓ ⚠ 一直不在包里,Web 端只能等 CDN 补(2026-10-23 重裁补上)。
//   test/font_coverage_test.dart(CI 会跑)拦住「lib/ 用了、字体里没有」的字符;node check.mjs 是
//   同一检查的 harfbuzz 版,本脚本跑完也会打印。字库里本来就没有的字(如 ✗ U+2717)重裁也补不上,
//   换一个字库里有的字符(界面上用 × U+00D7)。emoji 不算:CJK 字库没有,交给系统的 emoji 字体。
//
// 西文标点改比例宽度:SC 版把 · • ‘ ’ “ ” 默认映射成全角字形(中文排版习惯),原样打包的话英文
//   文案和英文通知里 "Don’t" 会显示成 "Don’ t"、" · " 两边空一大块。字库里有这几个字符的比例宽度
//   字形(日文 / 韩文的 locl 用的就是它们,子集的版式闭包已经把它们留下了),裁完把 cmap 里这几个
//   码位改指向它们(cmap.mjs),样子和以前缺字时回退到 Roboto 等西文字体一致。— … 不用动:
//   西文里本来就是比例宽度,夹在汉字中间时字库自己换成全角。
//
// 用法:node subset.mjs <全字库所在目录>
//   目录里要有 NotoSansCJKsc-Regular.otf 与 NotoSansCJKsc-Bold.otf(Google 官方 2.004,SIL OFL;
//   github.com/notofonts/noto-cjk 的 Sans/OTF/SimplifiedChinese/)。
//   输出 assets/fonts/NotoSansSC-Regular.otf、NotoSansSC-Bold.otf。
//
// 注意:package.json 把 subset-font 钉死在 2.7.0。2.9.0 裁 CID CFF 字库时会把整张 CFF 表丢掉,
//   产出 0.19 MB 的「空壳」字体(有 cmap 没轮廓),别升级。harfbuzzjs 钉在 subset-font 自带的 0.10.3,
//   用来排版查字形。

import { readFileSync, writeFileSync, readdirSync, statSync, mkdirSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import subsetFont from 'subset-font';
import hbPromise from 'harfbuzzjs';
import { remapCmap } from './cmap.mjs';
import { PROPORTIONAL, checkFonts, hex, shapeLatin } from './check.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const appRoot = resolve(here, '..', '..');
const srcDir = process.argv[2];
if (!srcDir) {
  console.error('用法:node subset.mjs <含 NotoSansCJKsc-Regular/Bold.otf 的目录>');
  process.exit(2);
}

// ---- 1. 源码里出现过的字符 ----
function walk(dir, out) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (name.endsWith('.dart')) out.push(p);
  }
  return out;
}
const chars = new Set();
for (let c = 0x20; c <= 0x7e; c++) chars.add(String.fromCodePoint(c));
let fromSrc = 0;
for (const f of walk(join(appRoot, 'lib'), [])) {
  for (const ch of readFileSync(f, 'utf8')) {
    if (ch.codePointAt(0) > 0x7e && !chars.has(ch)) { chars.add(ch); fromSrc++; }
  }
}

// ---- 2. GB2312 全部汉字:按码位枚举再用 gbk 解码,不依赖任何外部字表 ----
// 一级 B0A1–D7F9、二级 D8A1–F7FE;GBK 在这些码位上与 GB2312 完全一致。
const dec = new TextDecoder('gbk');
let fromGb = 0;
for (let hi = 0xb0; hi <= 0xf7; hi++) {
  for (let lo = 0xa1; lo <= 0xfe; lo++) {
    const ch = dec.decode(new Uint8Array([hi, lo]));
    if (ch === '�' || ch.length !== 1) continue; // D7FA–D7FE 等未定义码位
    if (!chars.has(ch)) { chars.add(ch); fromGb++; }
  }
}

// ---- 3. CJK 标点 + 全角区:整段按码位加入,字库里没有的码位 subset 时自然跳过 ----
let fromPunct = 0;
for (const [lo, hi] of [[0x3000, 0x303f], [0xff00, 0xffef]]) {
  for (let c = lo; c <= hi; c++) {
    const ch = String.fromCodePoint(c);
    if (!chars.has(ch)) { chars.add(ch); fromPunct++; }
  }
}

const text = [...chars].join('');
console.log(`字符集:源码 ${fromSrc} + GB2312 ${fromGb} + 标点/全角 ${fromPunct} + ASCII 95 = ${chars.size}`);

// ---- 西文标点:找出子集里的比例宽度字形 ----
// 日文 locl 下 · • ‘ ’ “ ” 排出来就是比例宽度字形,拿它们在子集里的字形号。
const hb = await hbPromise;
function proportionalRemap(font) {
  const blob = hb.createBlob(font);
  const face = hb.createFace(blob, 0);
  const hbFont = hb.createFont(face);
  const have = new Set(face.collectUnicodes());
  const remap = new Map();
  const notes = [];
  for (const ch of PROPORTIONAL) {
    const c = ch.codePointAt(0);
    if (!have.has(c)) continue;
    const latin = shapeLatin(hb, hbFont, ch);
    if (latin.ax < face.upem) continue; // 已经是比例宽度
    const buf = hb.createBuffer();
    buf.addText(ch);
    buf.setDirection('ltr');
    buf.setScript('Kana');
    buf.setLanguage('ja');
    hb.shape(hbFont, buf);
    const [ja] = buf.json();
    buf.destroy();
    if (ja.ax >= face.upem) throw new Error(`${hex(c)} ${ch} 在日文 locl 下也是全角,字库换版本了?`);
    remap.set(c, ja.g);
    notes.push(`${ch} ${latin.ax}→${ja.ax}`);
  }
  hbFont.destroy();
  face.destroy();
  blob.destroy();
  return { remap, notes };
}

// ---- 裁字 ----
const outDir = join(appRoot, 'assets', 'fonts');
mkdirSync(outDir, { recursive: true });
for (const weight of ['Regular', 'Bold']) {
  const inName = `NotoSansCJKsc-${weight}.otf`;
  const outName = `NotoSansSC-${weight}.otf`;
  const full = readFileSync(join(srcDir, inName));
  // sfnt = 保持原容器(CFF OTF),Flutter 直接能读
  const sub = await subsetFont(full, text, { targetFormat: 'sfnt' });
  const { remap, notes } = proportionalRemap(sub);
  const out = remapCmap(sub, remap);
  writeFileSync(join(outDir, outName), out);
  console.log(`${inName} → ${outName}: ${(full.length / 1048576).toFixed(1)} MB → ${(out.length / 1048576).toFixed(2)} MB;比例宽度标点 ${notes.join(' ') || '无'}`);
}

// ---- 核对 ----
const { ok, lines } = await checkFonts();
console.log(lines.join('\n'));
if (!ok) process.exitCode = 1;
console.log(ok ? 'done' : '字体已写出,但核对没通过,见上');
