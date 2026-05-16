// Semantics-tree navigation for the Story Weaver wizard.
// Drives the app by ARIA role + accessible name instead of raw coordinates.
import { bootA11y, clickSem, findSem, findAllSem, waitSem, dumpSemantics, shot, enableSemantics }
  from './a11y.mjs';

// Tap a Flutter text field by its semantics node, then type.
export async function typeIntoField(page, fieldHit, text) {
  await page.mouse.click(Math.round(fieldHit.x), Math.round(fieldHit.y));
  await page.waitForTimeout(700);
  await page.keyboard.type(text, { delay: 90 });
  await page.waitForTimeout(900);
}

// Onboard a fresh user through to the wizard. age 3..11.
export async function onboardA11y(opts = {}) {
  const age = opts.age || 3;
  const name = opts.name || 'Darcy';
  const ctx = await bootA11y(opts);
  const { page } = ctx;

  await clickSem(page, "Let's start", 'button', { settle: 2800 });

  // Name field — its semantic node has no role; match by surrounding group.
  // The field box is the empty-text node ~(24,479,366,67).
  const fieldHit = await page.evaluate(() => {
    // pick the largest empty-label node between the heading and the submit btn
    const nodes = [...document.querySelectorAll('flt-semantics')];
    let best = null;
    for (const n of nodes) {
      const lbl = (n.getAttribute('aria-label') || n.textContent || '').trim();
      const r = n.getBoundingClientRect();
      if (!lbl && r.width > 200 && r.height > 30 && r.height < 120 && r.y > 300 && r.y < 600) {
        if (!best || r.width * r.height < best.w * best.h) best = { x: r.x + r.width/2, y: r.y + r.height/2, w: r.width, h: r.height };
      }
    }
    return best;
  });
  if (fieldHit) await typeIntoField(page, fieldHit, name);
  await clickSem(page, "That's me", 'button', { settle: 3000 });

  // Age screen — each age tile is a semantics node "Age N".
  await clickSem(page, `Age ${age}`, null, { settle: 3500 });

  // Consent (children) — scroll, check, give permission.
  if (age < 13) {
    await enableSemantics(page);
    for (let i = 0; i < 6; i++) { await page.mouse.wheel(0, 700); await page.waitForTimeout(500); }
    // consent checkbox
    const cb = await findSem(page, '', 'checkbox')
      || await findSem(page, 'agree') || await findSem(page, 'consent');
    if (cb) { await page.mouse.click(Math.round(cb.x), Math.round(cb.y)); await page.waitForTimeout(900); }
    const allowed = await clickSem(page, 'permission', 'button', { settle: 4500 })
      || await clickSem(page, 'Allow', 'button', { settle: 4500 })
      || await clickSem(page, 'Continue', 'button', { settle: 4500 });
    if (!allowed) console.log('  WARN: consent-allow button not found via semantics');
  }

  // "Shape the stories" modal -> Maybe later (if present).
  // The modal can appear a beat late, so poll for the button by role.
  await enableSemantics(page);
  for (let t = 0; t < 8; t++) {
    const dismissed = await clickSem(page, 'Maybe later', 'button', { timeout: 1500, settle: 3000 });
    if (dismissed) break;
    await page.waitForTimeout(800);
    await enableSemantics(page);
  }

  return ctx;
}

// Boot directly into the wizard as a returning, consent-seeded under-13 user.
// Bypasses the email-verification consent wall. The wizard opens to either the
// "Welcome back" character grid (if saved characters exist) or HeroCreatorStep.
// Returns { browser, page, errors }.
export async function onboardSeeded(opts = {}) {
  const age = opts.age || 3;
  const name = opts.name || 'Darcy';
  const ctx = await bootA11y({ ...opts, seedConsent: { age, name } });
  const { page } = ctx;
  // give the wizard a moment to settle on its first route
  await page.waitForTimeout(2500);
  await enableSemantics(page);
  // dismiss the "Shape the stories" modal if it appears
  for (let t = 0; t < 5; t++) {
    const d = await clickSem(page, 'Maybe later', 'button', { timeout: 1200, settle: 2500 });
    if (d) break;
    await page.waitForTimeout(700);
    await enableSemantics(page);
  }
  return ctx;
}

export { bootA11y, clickSem, findSem, findAllSem, waitSem, dumpSemantics, shot, enableSemantics };
