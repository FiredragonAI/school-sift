// 从 Noto Sans CJK SC 全字库裁出 app 用得到的子集,写到 assets/fonts/。
//
// 为什么要裁:全字库单个字重 ~16 MB,两个字重打进 Web 包和 APK 都太重。
// 为什么要打:Web 端(CanvasKit)没有系统字体可回退,theme 指定的 NotoSansSC
// 不在包里时,首帧部分汉字是 □,靠 Google 字体 CDN 几秒后补——大陆用户补不上。
//
// 字符集 = 几部分的并集:
//   1. lib/ 下所有 .dart 源码里出现的非 ASCII 字符(界面文案等;初期可能很少)
//   2. GB2312 全部 6763 个汉字(一级 3755 + 二级 3008),兜住用户手输的学校名/人名
//   3. CJK 标点区 U+3000–U+303F(、。「」《》…)与全角区 U+FF00–U+FFEF(全角标点/数字/字母)
//   外加 ASCII 可见字符(含数字、字母)。生僻字仍走引擎的网络回退。
//
// 用法:node subset.mjs <全字库所在目录>
//   目录里要有 NotoSansCJKsc-Regular.otf 与 NotoSansCJKsc-Bold.otf(Google 官方,SIL OFL)。
//   输出 assets/fonts/NotoSansSC-Regular.otf、NotoSansSC-Bold.otf。
//
// 注意:package.json 把 subset-font 钉死在 2.7.0。2.9.0 裁 CID CFF 字库时会把整张 CFF 表丢掉,
//   产出 0.19 MB 的「空壳」字体(有 cmap 没轮廓),别升级。

import { readFileSync, writeFileSync, readdirSync, statSync, mkdirSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import subsetFont from 'subset-font';

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

// ---- 裁字 ----
const outDir = join(appRoot, 'assets', 'fonts');
mkdirSync(outDir, { recursive: true });
for (const weight of ['Regular', 'Bold']) {
  const inName = `NotoSansCJKsc-${weight}.otf`;
  const outName = `NotoSansSC-${weight}.otf`;
  const full = readFileSync(join(srcDir, inName));
  // sfnt = 保持原容器(CFF OTF),Flutter 直接能读
  const sub = await subsetFont(full, text, { targetFormat: 'sfnt' });
  writeFileSync(join(outDir, outName), sub);
  console.log(`${inName} → ${outName}: ${(full.length / 1048576).toFixed(1)} MB → ${(sub.length / 1048576).toFixed(2)} MB`);
}
console.log('done');
