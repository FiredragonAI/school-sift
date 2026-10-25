// 置顶大图(Feature Graphic,1024×500):渲染 feature.html,转成 24 位 PNG 写进 metadata。
// 用法:cd app/tools/store && npm install && npm run feature。需要本机 Chrome 和 ffmpeg。
import puppeteer from 'puppeteer-core';
import { execFileSync } from 'node:child_process';
import { unlinkSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const META = { zh: 'zh-CN', en: 'en-US' };
const b = await puppeteer.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true, args: ['--allow-file-access-from-files'] });
const p = await b.newPage();
await p.setViewport({ width: 1024, height: 500, deviceScaleFactor: 1 });
for (const [l, dir] of Object.entries(META)) {
  await p.goto(new URL(`./feature.html?l=${l}`, import.meta.url).href, { waitUntil: 'networkidle0' });
  await p.evaluate(() => document.fonts.ready);
  const out = fileURLToPath(new URL(`../../android/fastlane/metadata/android/${dir}/images/featureGraphic.png`, import.meta.url));
  await p.screenshot({ path: out + '.raw.png' });
  execFileSync('ffmpeg', ['-v', 'error', '-y', '-i', out + '.raw.png', '-vf', 'format=rgb24', out]);
  unlinkSync(out + '.raw.png');
  console.log('feature graphic', dir);
}
await b.close();
