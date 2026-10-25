// 商店截图:本机网页版 + 演示数据,手机竖屏 1080×1920(432×768 @2.5x),中英各一套。
// 用法:先 flutter build web --release --no-web-resources-cdn --base-href / 并在 8768 端口起静态服务器
//(或 E2E_URL=...),再 cd app/tools/store && npm install && npm run shots。需要本机 Chrome 和 ffmpeg。
import { mkdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { launch, openApp, tap, sleep } from './lib.mjs';

const URL0 = process.env.E2E_URL || 'http://127.0.0.1:8768/';
const META = { zh: 'zh-CN', en: 'en-US' };
const OUT = (lang) => { const d = new URL(`../../android/fastlane/metadata/android/${META[lang]}/images/phoneScreenshots/`, import.meta.url); mkdirSync(d, { recursive: true }); return d; };

async function open(b) {
  const p = await openApp(b, URL0);
  await p.setViewport({ width: 432, height: 768, deviceScaleFactor: 2.5 });
  await sleep(1500);
  return p;
}
const snap = async (p, lang, name) => {
  await p.mouse.move(431, 330); // 别让鼠标停在底栏上弹出提示
  await sleep(1500);
  const raw = fileURLToPath(new URL(`${name}.raw.png`, OUT(lang)));
  await p.screenshot({ path: raw });
  // Play 要求 24 位 PNG(不带透明通道)
  execFileSync('ffmpeg', ['-v', 'error', '-y', '-i', raw, '-vf', 'format=rgb24', raw.replace('.raw.png', '.png')]);
  (await import('node:fs')).unlinkSync(raw);
  console.log('shot', lang, name);
};

async function run(b, lang, L) {
  const p = await open(b);
  await tap(p, '载入演示数据', { wait: 2000 });
  if (lang === 'en') {
    await sleep(1500);
    await p.mouse.click(389, 735); // 底栏「更多」
    await sleep(1500);
    for (let i = 0; i < 6; i++) { await p.mouse.move(216, 400); await p.mouse.wheel({ deltaY: 600 }); await sleep(250); }
    await sleep(800);
    await tap(p, 'English', { exact: true, wait: 1500 });
    await tap(p, 'Load demo data', { wait: 2000 });
    for (let i = 0; i < 6; i++) { await p.mouse.move(216, 400); await p.mouse.wheel({ deltaY: -800 }); await sleep(250); }
  }
  await tap(p, L.today, { exact: true, wait: 1500 });
  await snap(p, lang, '1_today');
  await tap(p, L.inbox, { exact: true, wait: 1500 });
  await snap(p, lang, '2_notices');
  await p.mouse.click(216, 250); // 第一条通知
  await sleep(1500);
  await snap(p, lang, '3_notice-detail');
  await p.mouse.click(28, 27); // 左上角返回
  await sleep(1200);
  await tap(p, L.cal, { exact: true, wait: 1500 });
  await snap(p, lang, '4_calendar');
  await tap(p, L.growth, { exact: true, wait: 1500 });
  await snap(p, lang, '5_growth');
  await tap(p, L.more, { exact: true, wait: 1500 });
  await snap(p, lang, '6_more');
  return p;
}

const b = await launch();
try {
  if (!process.env.ONLY_EN) await run(b, 'zh', { today: '今日', inbox: '通知', cal: '日程', growth: '成长', more: '更多' });
  await run(b, 'en', { today: 'Today', inbox: 'Notices', cal: 'Calendar', growth: 'Growth', more: 'More' });
} catch (e) {
  console.log('ERROR', e.message.slice(0, 800));
  process.exitCode = 1;
} finally {
  await b.close();
}
