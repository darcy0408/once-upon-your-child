// Full-flow driver: onboard -> wizard -> generate a story, all via semantics.
// Exports reusable stages so MT verification scripts can compose them.
import { onboardA11y, onboardSeeded, dumpSemantics, shot, enableSemantics,
         clickSem, findSem, findAllSem } from './nav-a11y.mjs';

export async function tapNode(page, node, settle = 2800) {
  await page.mouse.click(Math.round(node.x), Math.round(node.y));
  await page.waitForTimeout(settle);
}

// Click the first semantics node whose name matches `re` (RegExp) and is
// NOT chrome. If the node is below the fold it is scrolled into view first.
// Returns the node clicked, or null.
const CHROME = /^(close|parent$|pick hero|pick team|pick place|make magic|life quests|heroes|bedtime|read this question|parent controls)/i;
export async function tapMatch(page, re, settle = 2800) {
  await enableSemantics(page);
  // Up to 6 scroll attempts to bring a matching node into the viewport.
  for (let scroll = 0; scroll < 7; scroll++) {
    const nodes = await dumpSemantics(page);
    // Prefer a genuinely tappable (button-role) node over wrapper containers,
    // which share the same accessible name as 3+ duplicate nodes.
    const matches = nodes.filter(n => (n.label || n.text)
      && re.test((n.label || n.text)) && !CHROME.test((n.label || n.text).trim()));
    const hit = matches.find(n => n.tappable) || matches[0];
    if (hit) {
      const posAll = await findAllSem(page, (hit.label || hit.text).slice(0, 12), 'button');
      const pos = posAll.length ? posAll
        : await findAllSem(page, (hit.label || hit.text).slice(0, 12), hit.role);
      if (pos.length) {
        // smallest matching rect = the actual leaf widget, not a wrapper
        pos.sort((a, b) => (a.w * a.h) - (b.w * b.h));
        const p = pos[0];
        if (p.y > 60 && p.y < 884) {
          await page.mouse.click(Math.round(p.x), Math.round(p.y));
          console.log(`  tap "${(hit.label||hit.text).replace(/\n/g,' ').slice(0,34)}"`);
          await page.waitForTimeout(settle);
          return hit;
        }
        // off-screen: scroll toward it
        await page.mouse.move(207, 450);
        await page.mouse.wheel(0, p.y < 60 ? -500 : 500);
        await page.waitForTimeout(700);
        await enableSemantics(page);
        continue;
      }
    }
    // no match yet — scroll down to reveal more content
    await page.mouse.move(207, 450);
    await page.mouse.wheel(0, 500);
    await page.waitForTimeout(700);
    await enableSemantics(page);
  }
  return null;
}

// Get past the "Choose Your Look" avatar gallery (bare GestureDetector tiles).
export async function pickAvatar(page) {
  await page.mouse.click(115, 150);            // first tile, 2-col grid
  await page.waitForTimeout(3500);
  await clickSem(page, 'Use this look', 'button', { timeout: 6000, settle: 3500 });
}

// Read the wizard progress label, e.g. "Pick Team, step 2 of 4".
export async function progressLabel(page) {
  await enableSemantics(page);
  const g = await findSem(page, 'Progress:', 'group');
  return g ? (g.label || g.text) : '';
}

// The MoonPhaseProgress bar exposes each wizard sub-step as a tappable
// button ("Pick Hero" / "Pick Team" / "Pick Place" / "Make Magic!").
// Tapping a dot is the most reliable way to advance/jump between steps.
export async function gotoStep(page, dotName, settle = 3500) {
  return clickSem(page, dotName, 'button', { timeout: 6000, settle });
}

// Walk the Sprout HeroCreatorStep: gender -> avatar -> archetype -> companion
// -> world -> story-style. Progress-bar dot labels are Sprout-flavoured
// ("My Hero!" / "My Buddies!" / "My World!" / "Make Magic!").
export async function walkHero(page, opts = {}) {
  await clickSem(page, opts.gender || 'Girl', 'button', { settle: 3000 });
  await pickAvatar(page);
  // archetype — auto-advances to the Buddies step once a tile is selected.
  await page.waitForTimeout(2000);
  await tapMatch(page, /role:/i, 3500);
  // Buddies (Team) step — pick a companion, then jump to the World step.
  await tapMatch(page, /^pebble|^robin|^mochi|^sunny|^ember|^clover|^biscuit/i, 2500);
  await gotoStep(page, /my world|pick place/i, 3500);
  // World (Place) step — pick a scene tile. Confirm the selection took by
  // re-tapping if the wizard hasn't auto-advanced off the World step.
  await page.waitForTimeout(1800);
  await tapMatch(page, /^scene:.*rainbow/i, 3500);
  let pl = await progressLabel(page);
  if (/my world/i.test(pl)) {                 // still on World — retry the tap
    await tapMatch(page, /^scene:/i, 3500);
  }
  // jump to the Make Magic (story-style) step.
  await gotoStep(page, /make magic/i, 4000);
}

// On the story-style step, pick a style. Sprout styles are
// "Story Quest" / "Rhyme Time" / "Learning to Read" (the Read-Along mode).
export async function pickStoryStyle(page, styleRe) {
  await page.waitForTimeout(1500);
  await tapMatch(page, styleRe, 3000);
}

// The wizard's forward arrow ("Next: ...") is an unlabeled circular button.
// Find the bottom-most square button with NO accessible name and click it.
export async function tapForwardArrow(page, settle = 4000) {
  await enableSemantics(page);
  const arrow = await page.evaluate(() => {
    const cands = [...document.querySelectorAll('flt-semantics')]
      .filter(n => (n.getAttribute('role') === 'button')
        && !(n.getAttribute('aria-label') || n.textContent || '').trim())
      .map(n => { const r = n.getBoundingClientRect();
        return { x: r.x + r.width/2, y: r.y + r.height/2, w: r.width, h: r.height }; })
      // a chunky-ish square button low on the screen
      .filter(n => n.w >= 48 && n.w <= 120 && Math.abs(n.w - n.h) < 24 && n.y > 400);
    cands.sort((a, b) => b.y - a.y);
    return cands[0] || null;
  });
  if (!arrow) { console.log('  forward-arrow not found'); return false; }
  await page.mouse.click(Math.round(arrow.x), Math.round(arrow.y));
  console.log(`  forward-arrow @ (${Math.round(arrow.x)},${Math.round(arrow.y)})`);
  await page.waitForTimeout(settle);
  return true;
}

// From the Sprout GO! screen, scroll to and tap the giant "GO!" button.
export async function tapGo(page, settle = 6000) {
  for (let scroll = 0; scroll < 7; scroll++) {
    await enableSemantics(page);
    const hit = await page.evaluate(() => {
      const b = [...document.querySelectorAll('flt-semantics')]
        .filter(n => n.getAttribute('role') === 'button'
          && /^go!?$|make (my )?magic/i.test(
            (n.getAttribute('aria-label') || n.textContent || '').trim())
          && n.getBoundingClientRect().width > 150)        // wide CTA, not a dot
        .map(n => { const r = n.getBoundingClientRect();
          return { x: r.x + r.width/2, y: r.y + r.height/2 }; });
      return b[0] || null;
    });
    if (hit && hit.y > 80 && hit.y < 870) {
      await page.mouse.click(Math.round(hit.x), Math.round(hit.y));
      console.log(`  tapGo @ (${Math.round(hit.x)},${Math.round(hit.y)})`);
      await page.waitForTimeout(settle);
      return true;
    }
    await page.mouse.move(207, 450);
    await page.mouse.wheel(0, 450);
    await page.waitForTimeout(600);
  }
  console.log('  tapGo: GO button not found');
  return false;
}

// Full convenience flow: seed-boot -> wizard -> story style -> Sprout GO!
// screen. styleRe selects the story style. Returns ctx { browser, page, errors }.
export async function generateStory(opts = {}) {
  const ctx = await onboardSeeded({ age: opts.age || 3, name: opts.name || 'Darcy',
    seedStorage: opts.seedStorage });
  const { page } = ctx;
  await walkHero(page, opts);
  await pickStoryStyle(page, opts.styleRe || /story quest/i);
  await tapForwardArrow(page, 4500);          // -> Sprout GO! screen
  return ctx;
}

// Wait until a generated story page is on screen (story body text appears).
export async function waitForStory(page, timeoutMs = 90000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    await enableSemantics(page);
    const nodes = await dumpSemantics(page);
    const txt = nodes.map(n => n.label || n.text || '').join(' ');
    if (/the end|page \d|once upon|chapter|read to me|tap to read/i.test(txt)
        && !/loading|creating|weaving|magic is happening/i.test(txt)) {
      return true;
    }
    await page.waitForTimeout(2500);
  }
  return false;
}

if (process.argv[1] && process.argv[1].replace(/\\/g, '/').endsWith('drive.mjs')) {
  // standalone smoke test
  const { browser, page, errors } = await onboardA11y({ age: 3, name: 'Darcy' });
  await walkHero(page);
  await enableSemantics(page);
  const nodes = await dumpSemantics(page);
  console.log('FINAL nodes:', nodes.filter(n => n.label||n.text)
    .map(n => (n.label||n.text).replace(/\n/g,'/').slice(0,40)));
  await shot(page, 'drive-final');
  await browser.close();
  console.log('errors:', errors.length);
}

export { onboardA11y, dumpSemantics, shot, enableSemantics, clickSem, findSem, findAllSem };
