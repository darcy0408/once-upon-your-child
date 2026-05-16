// Shared helpers for Story Weaver Flutter-web QA harness.
// Flutter CanvasKit renders to a canvas: no usable DOM. Drive by coordinate.
import { chromium } from '@playwright/test';

// Release build served statically on :8090 (fast single-file boot).
// The `flutter run` DDC dev server on :8080 is too slow/flaky to bootstrap
// reliably headless (1159-script load). See qa/playwright/README notes.
export const URL = process.env.SW_URL || 'http://127.0.0.1:8090';
export const VP = { width: 414, height: 896 };

// Launch + load the app, waiting until the canvas has actually painted
// (not a blank white frame). Returns { browser, page, errors }.
export async function boot(opts = {}) {
  const viewport = opts.viewport || VP;
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport, deviceScaleFactor: 1 });
  const errors = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push('PAGEERROR: ' + e.message));

  let mounted = false;
  for (let attempt = 0; attempt < 2 && !mounted; attempt++) {
    await page.goto(URL, { waitUntil: 'load', timeout: 60000 });
    // Poll for the Flutter engine to mount its view host.
    for (let t = 0; t < 40; t++) {
      await page.waitForTimeout(1500);
      const s = await page.evaluate(() => ({
        fv: !!document.querySelector('flutter-view'),
        host: !!document.querySelector('flt-glass-pane,flt-scene-host,flt-semantics-host'),
      }));
      if (s.fv || s.host) { mounted = true; break; }
    }
    if (!mounted) await page.reload();
  }
  if (!mounted) {
    await page.screenshot({ path: 'screenshots/BOOT-FAILED.png' });
    throw new Error('Flutter engine never mounted flutter-view after 2 attempts.');
  }
  // engine mounted; give the splash + first route a moment to settle
  await page.waitForTimeout(4000);
  return { browser, page, errors };
}

export async function shot(page, name) {
  const p = `screenshots/${name}.png`;
  await page.screenshot({ path: p, fullPage: false });
  return p;
}

// click at fractional coordinates of the viewport (0..1)
export async function clickFrac(page, fx, fy, label = '') {
  const x = Math.round(VP.width * fx);
  const y = Math.round(VP.height * fy);
  await page.mouse.click(x, y);
  if (label) console.log(`  click ${label} @ (${x},${y})`);
  await page.waitForTimeout(1200);
}

export async function clickXY(page, x, y, label = '') {
  await page.mouse.click(x, y);
  if (label) console.log(`  click ${label} @ (${x},${y})`);
  await page.waitForTimeout(1200);
}

export async function typeText(page, txt) {
  await page.keyboard.type(txt, { delay: 60 });
  await page.waitForTimeout(600);
}
