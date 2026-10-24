// 改子集字体的 cmap(码位 → 字形)。给 subset.mjs 的「西文标点改比例宽度」一步用。
//
// harfbuzz 子集化不能自定义 cmap,所以裁完以后在这里改:读出 cmap 的全部映射(format 4 / 12),
// 改掉要改的几个码位,再按规范重新写出 format 4(BMP)和必要时的 format 12(增补平面),
// format 14(异体字选择符)原样放回;最后重排表目录、重算各表校验和与 head.checkSumAdjustment。
// 别的表一个字节都不动。

const hex = (c) => c.toString(16).toUpperCase().padStart(4, '0');

/** 读表目录 → { version, tables: [{ tag, offset, data }] },按表在文件里的物理顺序。 */
export function readTables(font) {
  const tables = [];
  for (let i = 0, n = font.readUInt16BE(4); i < n; i++) {
    const r = 12 + i * 16;
    const offset = font.readUInt32BE(r + 8);
    const length = font.readUInt32BE(r + 12);
    tables.push({ tag: font.toString('latin1', r, r + 4), offset, data: font.subarray(offset, offset + length) });
  }
  tables.sort((a, b) => a.offset - b.offset);
  return { version: font.readUInt32BE(0), tables };
}

// OpenType 校验和:按大端 uint32 累加,不足 4 字节的尾巴补 0
function checksum(data) {
  let sum = 0;
  for (let i = 0; i < data.length; i += 4) {
    const word = ((data[i] << 24) | ((data[i + 1] ?? 0) << 16) | ((data[i + 2] ?? 0) << 8) | (data[i + 3] ?? 0)) >>> 0;
    sum = (sum + word) >>> 0;
  }
  return sum;
}

/** 按表重新拼出字体:数据保持原来的物理顺序、4 字节对齐;表目录按 tag 排序;重算校验和。 */
export function writeFont({ version, tables }) {
  const n = tables.length;
  let offset = 12 + 16 * n;
  const placed = tables.map((t) => {
    const p = { ...t, offset };
    offset += (t.data.length + 3) & ~3;
    return p;
  });
  const out = Buffer.alloc(offset);
  const pow2 = 2 ** Math.floor(Math.log2(n));
  out.writeUInt32BE(version, 0);
  out.writeUInt16BE(n, 4);
  out.writeUInt16BE(pow2 * 16, 6);
  out.writeUInt16BE(Math.log2(pow2), 8);
  out.writeUInt16BE(n * 16 - pow2 * 16, 10);
  const byTag = [...placed].sort((a, b) => Buffer.compare(Buffer.from(a.tag, 'latin1'), Buffer.from(b.tag, 'latin1')));
  let head = null;
  byTag.forEach((t, i) => {
    const r = 12 + i * 16;
    out.write(t.tag, r, 'latin1');
    out.writeUInt32BE(t.offset, r + 8);
    out.writeUInt32BE(t.data.length, r + 12);
    t.data.copy(out, t.offset);
    if (t.tag === 'head') {
      head = t;
      out.writeUInt32BE(0, t.offset + 8); // checkSumAdjustment 先置 0 再算
    }
    out.writeUInt32BE(checksum(out.subarray(t.offset, t.offset + t.data.length)), r + 4);
  });
  if (head) out.writeUInt32BE((0xb1b0afba - checksum(out)) >>> 0, head.offset + 8);
  return out;
}

/** 读 cmap:format 4 / 12 的映射合并成 Map(码位 → 字形号);format 14 原样留着。 */
export function parseCmap(cmap) {
  const map = new Map();
  let uvs = null;
  const seen = new Set();
  for (let i = 0, n = cmap.readUInt16BE(2); i < n; i++) {
    const off = cmap.readUInt32BE(4 + i * 8 + 4);
    if (seen.has(off)) continue; // (0,3) 与 (3,1) 通常指向同一份子表
    seen.add(off);
    const format = cmap.readUInt16BE(off);
    if (format === 4) {
      const segX2 = cmap.readUInt16BE(off + 6);
      const ends = off + 14;
      const starts = ends + segX2 + 2;
      const deltas = starts + segX2;
      const ranges = deltas + segX2;
      for (let s = 0; s < segX2; s += 2) {
        const start = cmap.readUInt16BE(starts + s);
        const end = cmap.readUInt16BE(ends + s);
        const delta = cmap.readUInt16BE(deltas + s);
        const ro = cmap.readUInt16BE(ranges + s);
        for (let c = start; c <= end && c !== 0xffff; c++) {
          let g = ro === 0 ? c : cmap.readUInt16BE(ranges + s + ro + 2 * (c - start));
          if (ro !== 0 && g === 0) continue;
          g = (g + delta) & 0xffff;
          if (g !== 0) map.set(c, g);
        }
      }
    } else if (format === 12) {
      for (let k = 0, groups = cmap.readUInt32BE(off + 12); k < groups; k++) {
        const r = off + 16 + 12 * k;
        const start = cmap.readUInt32BE(r);
        const end = cmap.readUInt32BE(r + 4);
        const glyph = cmap.readUInt32BE(r + 8);
        for (let c = start; c <= end; c++) map.set(c, glyph + c - start);
      }
    } else if (format === 14) {
      uvs = cmap.subarray(off, off + cmap.readUInt32BE(off + 2));
    } else {
      throw new Error(`cmap 里有 format ${format} 子表,这里没处理过,别硬改`);
    }
  }
  return { map, uvs };
}

// format 4:连续码位归成一段;段内字形号也连续就用 idDelta,否则放进 glyphIdArray
function format4(entries) {
  const segs = [];
  for (const [c, g] of entries) {
    const last = segs.at(-1);
    if (last && c === last.end + 1) {
      last.end = c;
      last.glyphs.push(g);
    } else {
      segs.push({ start: c, end: c, glyphs: [g] });
    }
  }
  segs.push({ start: 0xffff, end: 0xffff, glyphs: null }); // 规范要求的结尾段,映射到 0 号字形
  const n = segs.length;
  const deltas = [];
  const ranges = [];
  const glyphArray = [];
  segs.forEach((s, i) => {
    if (!s.glyphs) {
      deltas.push(1);
      ranges.push(0);
      return;
    }
    const d = s.glyphs[0] - s.start;
    if (s.glyphs.every((g, k) => g - (s.start + k) === d)) {
      deltas.push(d & 0xffff);
      ranges.push(0);
    } else {
      deltas.push(0);
      ranges.push(2 * (n - i) + 2 * glyphArray.length); // 从 idRangeOffset[i] 本身算起的字节偏移
      glyphArray.push(...s.glyphs);
    }
  });
  const length = 16 + 8 * n + 2 * glyphArray.length;
  if (length > 0xffff) throw new Error(`format 4 子表 ${length} 字节,超过 64 KB`);
  const out = Buffer.alloc(length);
  const pow2 = 2 ** Math.floor(Math.log2(n));
  out.writeUInt16BE(4, 0);
  out.writeUInt16BE(length, 2);
  out.writeUInt16BE(0, 4); // language
  out.writeUInt16BE(2 * n, 6);
  out.writeUInt16BE(2 * pow2, 8);
  out.writeUInt16BE(Math.log2(pow2), 10);
  out.writeUInt16BE(2 * n - 2 * pow2, 12);
  let o = 14;
  for (const s of segs) o = out.writeUInt16BE(s.end, o);
  o += 2; // reservedPad
  for (const s of segs) o = out.writeUInt16BE(s.start, o);
  for (const d of deltas) o = out.writeUInt16BE(d, o);
  for (const r of ranges) o = out.writeUInt16BE(r, o);
  for (const g of glyphArray) o = out.writeUInt16BE(g, o);
  return out;
}

// format 12:码位与字形号同时连续的归成一组
function format12(entries) {
  const groups = [];
  for (const [c, g] of entries) {
    const last = groups.at(-1);
    if (last && c === last.end + 1 && g === last.glyph + (c - last.start)) last.end = c;
    else groups.push({ start: c, end: c, glyph: g });
  }
  const out = Buffer.alloc(16 + 12 * groups.length);
  out.writeUInt16BE(12, 0);
  out.writeUInt32BE(out.length, 4);
  out.writeUInt32BE(groups.length, 12);
  groups.forEach((gr, i) => {
    out.writeUInt32BE(gr.start, 16 + 12 * i);
    out.writeUInt32BE(gr.end, 20 + 12 * i);
    out.writeUInt32BE(gr.glyph, 24 + 12 * i);
  });
  return out;
}

/** 写 cmap:BMP 用 format 4,有增补平面字符时加 format 12,format 14 原样放回。 */
export function buildCmap(map, uvs = null) {
  const entries = [...map].sort((a, b) => a[0] - b[0]);
  const f4 = format4(entries.filter(([c]) => c < 0xffff));
  const f12 = entries.some(([c]) => c > 0xffff) ? format12(entries) : null;
  // 编码记录按 (platformID, encodingID) 升序;同一份子表只写一次
  const records = [[0, 3, f4]];
  if (f12) records.push([0, 4, f12]);
  if (uvs) records.push([0, 5, uvs]);
  records.push([3, 1, f4]);
  if (f12) records.push([3, 10, f12]);
  let offset = 4 + 8 * records.length;
  const offsets = new Map();
  for (const [, , blob] of records) {
    if (offsets.has(blob)) continue;
    offsets.set(blob, offset);
    offset += blob.length;
  }
  const out = Buffer.alloc(offset);
  out.writeUInt16BE(records.length, 2);
  records.forEach(([platform, encoding, blob], i) => {
    out.writeUInt16BE(platform, 4 + 8 * i);
    out.writeUInt16BE(encoding, 6 + 8 * i);
    out.writeUInt32BE(offsets.get(blob), 8 + 8 * i);
  });
  for (const [blob, o] of offsets) blob.copy(out, o);
  return out;
}

/** 把 remap(码位 → 新字形号)写进字体的 cmap,返回新的字体 Buffer。 */
export function remapCmap(font, remap) {
  const parsed = readTables(font);
  const table = parsed.tables.find((t) => t.tag === 'cmap');
  const { map, uvs } = parseCmap(table.data);
  for (const [c, g] of remap) {
    if (!map.has(c)) throw new Error(`U+${hex(c)} 不在 cmap 里,没法改`);
    map.set(c, g);
  }
  table.data = buildCmap(map, uvs);
  return writeFont(parsed);
}
