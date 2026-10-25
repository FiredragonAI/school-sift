// 无头 Chrome 驱动 Flutter Web:打开语义树后按文字找按钮 / 输入框。
import puppeteer from 'puppeteer-core';
import { mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

export const OUT = new URL('./shots/', import.meta.url);
mkdirSync(OUT, { recursive: true });
export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export async function launch() {
  return puppeteer.launch({
    executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    headless: true,
    args: ['--no-first-run', '--no-default-browser-check', '--disable-features=Translate'],
  });
}

export async function openApp(browser, url, { fresh = true } = {}) {
  const ctx = fresh ? await browser.createBrowserContext() : browser.defaultBrowserContext();
  const page = await ctx.newPage();
  await page.setViewport({ width: 430, height: 932, deviceScaleFactor: 1 });
  page.on('console', (m) => { if (m.type() === 'error') console.log(`[${url} console.error]`, m.text().slice(0, 300)); });
  page.on('pageerror', (e) => console.log(`[${url} pageerror]`, String(e).slice(0, 300)));
  await page.goto(url, { waitUntil: 'networkidle0' });
  await page.waitForSelector('flt-semantics-placeholder, flt-glass-pane', { timeout: 30000 });
  await sleep(1500);
  await enableSemantics(page);
  // Auth 模拟器在页面底部盖一条警告横幅,会挡住底部导航;测试里去掉
  await page.evaluate(() => setInterval(() => document.querySelectorAll(".firebase-emulator-warning").forEach((e) => e.remove()), 300));
  return page;
}

export async function enableSemantics(page) {
  await page.evaluate(() => {
    const p = document.querySelector('flt-semantics-placeholder');
    if (p) p.click();
  });
  await sleep(800);
}

/** 所有语义节点的文字(调试用) */
export async function labels(page) {
  return page.evaluate(() => [...document.querySelectorAll('flt-semantics')]
    .map((e) => (e.getAttribute('aria-label') || e.innerText || '').trim())
    .filter(Boolean));
}

async function findBox(page, text, { exact = false, role } = {}) {
  return page.evaluate(({ text, exact, role }) => {
    const all = [...document.querySelectorAll('flt-semantics, input, textarea, [role]')];
    const hit = all.filter((e) => {
      if (role && e.getAttribute('role') !== role) return false;
      const t = ((e.getAttribute('aria-label') || '') + ' ' + (e.textContent || '')).trim();
      return exact ? t === text || (e.getAttribute('aria-label') || '') === text : t.includes(text);
    }).map((e) => ({ e, r: e.getBoundingClientRect() }))
      .filter(({ r }) => r.width > 0 && r.height > 0)
      // 最里层(面积最小)的那个
      .sort((a, b) => a.r.width * a.r.height - b.r.width * b.r.height);
    if (!hit.length) return null;
    const r = hit[0].r;
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  }, { text, exact, role });
}

export async function tap(page, text, opts = {}) {
  for (let i = 0; i < 20; i++) {
    const b = await findBox(page, text, opts);
    if (b) {
      await page.mouse.click(b.x, b.y);
      await sleep(opts.wait ?? 900);
      return;
    }
    await sleep(500);
  }
  throw new Error(`找不到: ${text}\n现有: ${(await labels(page)).slice(0, 60).join(' | ')}`);
}

export async function has(page, text, timeout = 10000) {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    if (await findBox(page, text)) return true;
    await sleep(400);
  }
  return false;
}

/** 点输入框(按标签文字)后输入 */
export async function fill(page, label, value) {
  // 只找输入框(aria-label 以标签开头),免得点到「忘记密码」这种也含「密码」的按钮
  let box = null;
  for (let i = 0; i < 20 && !box; i++) {
    box = await page.evaluate((label) => {
      const e = [...document.querySelectorAll("input, textarea")].find((x) => (x.getAttribute("aria-label") || "").startsWith(label));
      if (!e) return null;
      const r = e.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    }, label);
    if (!box) await sleep(500);
  }
  if (!box) throw new Error("找不到输入框: " + label);
  await page.mouse.click(box.x, box.y);
  await sleep(400);
  // 用 CDP 插入文字,不发合成按键(合成按键会让 Flutter 的键盘转换器报 null.toString,是测试工具的问题)
  const cdp = await page.createCDPSession();
  await cdp.send('Input.insertText', { text: value });
  await cdp.detach();
  await sleep(300);
}

export async function shot(page, name) {
  await page.screenshot({ path: fileURLToPath(new URL(`${name}.png`, OUT)) });
}

/** Auth 模拟器:点验证邮件里的链接 */
export async function verifyEmail(email) {
  const r = await fetch('http://localhost:9099/emulator/v1/projects/demo-schoolsift/oobCodes');
  const { oobCodes } = await r.json();
  const code = [...oobCodes].reverse().find((c) => c.email === email && c.requestType === 'VERIFY_EMAIL');
  if (!code) throw new Error(`no verify code for ${email}`);
  const res = await fetch(code.oobLink);
  if (!res.ok) throw new Error(`verify failed ${res.status}`);
}
