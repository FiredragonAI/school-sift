// 删掉 GSUB / GPOS 里用不到的语言系统(LangSys),给 subset.mjs 第二遍裁字用。
//
// Noto Sans CJK SC 的每个文种(DFLT cyrl grek hang hani kana latn)下都有默认语言系统和 JAN KOR ZHH ZHS ZHT。
// 日 / 韩 / 繁 / 港的 locl 把几乎每个汉字换成当地写法(每种 7,500–8,900 条替换)。harfbuzz 裁字时把所有
// 语言系统里的替换目标都算进版式闭包,所以子集里近一半字形是这些简体 App 永远用不到的异体。
// 这里只把 Script 表里的 LangSysRecord 删到只剩白名单(原地压紧,别的字节不动);没人引用的 feature 和
// lookup 由 harfbuzz 裁字时自己丢掉。文本的语言不在字体里时,排版引擎用默认语言系统(这个字体里就是简体)。

import { readTables, writeFont } from './cmap.mjs';

/** 只保留 keep 里的语言系统标签(4 字符,如 'ZHS '),默认语言系统总是保留。返回新的字体 Buffer。 */
export function keepLangSys(font, keep) {
  const parsed = readTables(font);
  for (const table of parsed.tables) {
    if (table.tag !== 'GSUB' && table.tag !== 'GPOS') continue;
    const d = Buffer.from(table.data); // 复制一份再改,不碰调用方的 Buffer
    const scriptList = d.readUInt16BE(4);
    for (let i = 0, n = d.readUInt16BE(scriptList); i < n; i++) {
      const script = scriptList + d.readUInt16BE(scriptList + 2 + 6 * i + 4);
      const count = d.readUInt16BE(script + 2);
      // LangSysRecord:4 字节标签 + 2 字节偏移;按标签排序,删掉一部分后顺序不变
      const kept = [];
      for (let k = 0; k < count; k++) {
        const r = script + 4 + 6 * k;
        if (keep.includes(d.toString('latin1', r, r + 4))) kept.push(Buffer.from(d.subarray(r, r + 6)));
      }
      d.writeUInt16BE(kept.length, script + 2);
      kept.forEach((rec, k) => rec.copy(d, script + 4 + 6 * k));
    }
    table.data = d;
  }
  return writeFont(parsed);
}
