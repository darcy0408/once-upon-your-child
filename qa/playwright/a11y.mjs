// Semantics-tree helpers for the Story Weaver Flutter-web QA harness.
//
// Flutter web renders to a single CanvasKit <canvas> with no addressable
// DOM. BUT it injects a hidden <flt-semantics-placeholder> button; activating
// it makes Flutter build a real <flt-semantics> subtree with ARIA roles and
// accessible names. These helpers enable that tree and query/click it.
import { chromium } from '@playwright/test';

export const URL = process.env.SW_URL || 'http://127.0.0.1:8090';
export const VP = { width: 414, height: 896 };

// Launch + load the app, wait for engine mount, then ENABLE the semantics
// tree by activating the accessibility placeholder.
// Returns { browser, page, errors }.
export async function bootA11y(opts = {}) {
  const viewport = opts.viewport || VP;
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport, deviceScaleFactor: 1 });
  const errors = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push('PAGEERROR: ' + e.message));

  if (opts.seedStorage) {
    await page.addInitScript(seed => {
      for (const [k, v] of Object.entries(seed)) localStorage.setItem(k, v);
    }, opts.seedStorage);
  }

  // Seed a recorded parental-consent + name + age so an under-13 "returning
  // user" boots straight into the wizard, bypassing the email-verification
  // consent wall (which cannot complete headless). shared_preferences_web
  // encodes: bool -> "true"/"false", int -> raw number, String -> JSON string.
  if (opts.seedConsent) {
    const age = opts.seedConsent.age || 3;
    const name = opts.seedConsent.name || 'Darcy';
    const recordedAt = new Date().toISOString();           // after 2026-03-21 cutoff
    const pref = {
      'flutter.user_name': JSON.stringify(name),
      'flutter.user_age': String(age),
      'flutter.parental_consent_granted': 'true',
      'flutter.parental_consent_method': JSON.stringify('email_verified'),
      'flutter.parental_consent_verified': 'true',
      'flutter.parental_consent_recorded_at': JSON.stringify(recordedAt),
      'flutter.parental_consent_allow_photo_avatar': 'false',
    };
    await page.addInitScript(p => {
      for (const [k, v] of Object.entries(p)) localStorage.setItem(k, v);
    }, pref);
  }

  let mounted = false;
  for (let attempt = 0; attempt < 2 && !mounted; attempt++) {
    await page.goto(URL, { waitUntil: 'load', timeout: 60000 });
    for (let t = 0; t < 40; t++) {
      await page.waitForTimeout(1500);
      const ok = await page.evaluate(() => !!document.querySelector('flutter-view'));
      if (ok) { mounted = true; break; }
    }
    if (!mounted) await page.reload();
  }
  if (!mounted) {
    await page.screenshot({ path: 'screenshots/BOOT-FAILED.png' });
    throw new Error('Flutter engine never mounted flutter-view.');
  }
  await page.waitForTimeout(4000);
  await enableSemantics(page);
  return { browser, page, errors };
}

// Activate the Flutter accessibility placeholder so the <flt-semantics>
// subtree is built. Idempotent — safe to call again after route changes.
export async function enableSemantics(page) {
  const has = await page.evaluate(() => document.querySelectorAll('flt-semantics').length > 0);
  if (has) return true;
  await page.evaluate(() => {
    const el = document.querySelector(
      'flt-semantics-placeholder, [aria-label="Enable accessibility"]');
    if (el) {
      el.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
      el.dispatchEvent(new MouseEvent('mouseup', { bubbles: true }));
      el.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    }
  });
  await page.waitForTimeout(2500);
  return page.evaluate(() => document.querySelectorAll('flt-semantics').length > 0);
}

// Dump every semantics node — for recon. Returns array of {role,label,text,id}.
export async function dumpSemantics(page) {
  return page.evaluate(() => [...document.querySelectorAll('flt-semantics')].map(n => ({
    role: n.getAttribute('role'),
    label: n.getAttribute('aria-label'),
    text: (n.textContent || '').trim().slice(0, 80),
    id: n.id || '',
    tappable: n.getAttribute('role') === 'button' || n.hasAttribute('flt-tappable'),
  })));
}

// Find a semantics node by accessible name (label OR text), optional role.
// `name` may be a string (substring, case-insensitive) or a RegExp.
function matchNodes(page, name, role) {
  return page.evaluate(({ name, role, isRe }) => {
    const re = isRe ? new RegExp(name, 'i') : null;
    const test = s => {
      if (!s) return false;
      return re ? re.test(s) : s.toLowerCase().includes(String(name).toLowerCase());
    };
    return [...document.querySelectorAll('flt-semantics')]
      .map((n, i) => ({ n, i }))
      .filter(({ n }) => {
        if (role && n.getAttribute('role') !== role) return false;
        return test(n.getAttribute('aria-label')) || test((n.textContent || '').trim());
      })
      .map(({ n }) => {
        const r = n.getBoundingClientRect();
        return {
          role: n.getAttribute('role'),
          label: n.getAttribute('aria-label'),
          text: (n.textContent || '').trim().slice(0, 60),
          x: r.x + r.width / 2, y: r.y + r.height / 2,
          w: r.width, h: r.height,
        };
      });
  }, { name: name instanceof RegExp ? name.source : name, role, isRe: name instanceof RegExp });
}

export async function findSem(page, name, role) {
  const all = await matchNodes(page, name, role);
  return all[0] || null;
}

export async function findAllSem(page, name, role) {
  return matchNodes(page, name, role);
}

// Wait until a semantics node matching name/role exists and is non-zero size.
export async function waitSem(page, name, role, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const hit = await findSem(page, name, role);
    if (hit && hit.w > 0 && hit.h > 0) return hit;
    await page.waitForTimeout(500);
  }
  return null;
}

// Click a semantics node by name/role. Falls back to its center coordinates
// (semantics nodes are positioned over the canvas, so the click lands on the
// real widget underneath). Returns true on success.
export async function clickSem(page, name, role, opts = {}) {
  const timeoutMs = opts.timeout ?? 15000;
  const hit = await waitSem(page, name, role, timeoutMs);
  if (!hit) {
    console.log(`  clickSem MISS: "${name}"${role ? ' [' + role + ']' : ''}`);
    return false;
  }
  await page.mouse.click(Math.round(hit.x), Math.round(hit.y));
  console.log(`  clickSem "${(hit.label || hit.text).slice(0,30)}" @ (${Math.round(hit.x)},${Math.round(hit.y)})`);
  await page.waitForTimeout(opts.settle ?? 1200);
  return true;
}

export async function shot(page, name) {
  const p = `screenshots/${name}.png`;
  await page.screenshot({ path: p, fullPage: false });
  return p;
}

// Type into the currently focused field (after clicking it).
export async function typeText(page, txt) {
  await page.keyboard.type(txt, { delay: 60 });
  await page.waitForTimeout(600);
}
