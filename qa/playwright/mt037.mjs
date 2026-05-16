// MT-037 — welcome-back character grid shows synchronously for a returning
// user with >=1 saved character (no blank flash / "No characters yet" flash).
//
// Approach: use a PERSISTENT browser profile. Run #1 generates a full story
// (which saves a character to Isar/localStorage). Run #2 reloads the SAME
// profile as a returning user and verifies the wizard opens directly on the
// "Welcome back" character grid.
import { chromium } from '@playwright/test';
import { walkHero, pickStoryStyle, tapForwardArrow, tapGo, waitForStory } from './drive.mjs';
import { enableSemantics, dumpSemantics, clickSem } from './a11y.mjs';
import fs from 'fs';

const URL = 'http://127.0.0.1:8090';
const VP = { width: 414, height: 896 };
const PROFILE = './.mt037-profile';
fs.rmSync(PROFILE, { recursive: true, force: true });

function seedConsent(age, name) {
  const recordedAt = new Date().toISOString();
  return {
    'flutter.user_name': JSON.stringify(name),
    'flutter.user_age': String(age),
    'flutter.parental_consent_granted': 'true',
    'flutter.parental_consent_method': JSON.stringify('email_verified'),
    'flutter.parental_consent_verified': 'true',
    'flutter.parental_consent_recorded_at': JSON.stringify(recordedAt),
    'flutter.parental_consent_allow_photo_avatar': 'false',
  };
}

async function bootCtx(ctx) {
  const page = await ctx.newPage();
  await page.addInitScript(p => {
    for (const [k, v] of Object.entries(p)) localStorage.setItem(k, v);
  }, seedConsent(3, 'Darcy'));
  for (let attempt = 0; attempt < 2; attempt++) {
    await page.goto(URL, { waitUntil: 'load', timeout: 60000 });
    let ok = false;
    for (let t = 0; t < 40; t++) {
      await page.waitForTimeout(1500);
      if (await page.evaluate(() => !!document.querySelector('flutter-view'))) { ok = true; break; }
    }
    if (ok) break;
    await page.reload();
  }
  await page.waitForTimeout(4000);
  await enableSemantics(page);
  return page;
}

// ---- RUN 1: generate a story so a character is persisted ----
let ctx = await chromium.launchPersistentContext(PROFILE, { headless: true, viewport: VP });
let page = await bootCtx(ctx);
for (let t = 0; t < 5; t++) {
  if (await clickSem(page, 'Maybe later', 'button', { timeout: 1200, settle: 2500 })) break;
  await page.waitForTimeout(700); await enableSemantics(page);
}
await walkHero(page);
await pickStoryStyle(page, /story quest/i);
await tapForwardArrow(page, 4500);
await tapGo(page, 7000);
const made = await waitForStory(page, 110000);
console.log('run1 story generated (character saved):', made);
await page.screenshot({ path: 'screenshots/mt037-run1-story.png' });
await page.waitForTimeout(2000);
await ctx.close();

// ---- RUN 2: reopen the SAME profile as a returning user ----
ctx = await chromium.launchPersistentContext(PROFILE, { headless: true, viewport: VP });
page = await ctx.newPage();
// capture the FIRST few frames after the wizard mounts to detect a blank /
// "No characters yet" flash.
await page.addInitScript(p => {
  for (const [k, v] of Object.entries(p)) localStorage.setItem(k, v);
}, seedConsent(3, 'Darcy'));
await page.goto(URL, { waitUntil: 'load', timeout: 60000 });
let mounted = false;
const earlyFrames = [];
for (let t = 0; t < 50; t++) {
  await page.waitForTimeout(400);
  const fv = await page.evaluate(() => !!document.querySelector('flutter-view'));
  if (fv && !mounted) { mounted = true; }
  if (mounted) {
    try {
      await enableSemantics(page);
      const txt = (await dumpSemantics(page)).map(n => n.label || n.text || '').join(' ');
      earlyFrames.push(txt.slice(0, 80));
      if (/welcome back/i.test(txt)) break;
    } catch {}
  }
}
await page.waitForTimeout(2000);
await enableSemantics(page);
await page.screenshot({ path: 'screenshots/mt037-run2-welcomeback.png' });
const finalTxt = (await dumpSemantics(page)).map(n => n.label || n.text || '').join(' ');
console.log('run2 final screen:', finalTxt.replace(/\n/g, '/').slice(0, 300));

const showsWelcomeBack = /welcome back/i.test(finalTxt);
const sawNoCharFlash = earlyFrames.some(f => /no characters|no heroes yet/i.test(f));
console.log('shows "Welcome back" grid :', showsWelcomeBack);
console.log('saw "No characters" flash :', sawNoCharFlash);
console.log(`\nMT-037: ${(showsWelcomeBack && !sawNoCharFlash) ? 'PASS' : 'FAIL'}`);
console.log('  evidence: screenshots/mt037-run2-welcomeback.png');
await ctx.close();
