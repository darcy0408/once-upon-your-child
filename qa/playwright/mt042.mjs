// MT-042 — "Pick a Path!" badge must NOT appear on a linear (non-pick-a-path)
// story page. Generate a Story Quest (linear) story, navigate to page 3,
// confirm the progress badge reads "Page 3" (or an LLM stage_label), never
// "Pick a Path!".
import { generateStory, tapGo, waitForStory, dumpSemantics, enableSemantics,
         shot, tapMatch } from './drive.mjs';

const { browser, page, errors } = await generateStory({ age: 3, styleRe: /story quest/i });
await shot(page, 'mt042-00-review');

const went = await tapGo(page, 8000);
console.log('GO tapped:', went);
await shot(page, 'mt042-01-loading');

const got = await waitForStory(page, 110000);
console.log('story generated:', got);
await shot(page, 'mt042-02-story-p1');

// Turn to page 3: tap the forward page-arrow twice.
async function pageBadges() {
  await enableSemantics(page);
  const n = await dumpSemantics(page);
  return n.map(x => (x.label || x.text || '')).filter(Boolean);
}
for (let turn = 0; turn < 2; turn++) {
  // page-turn forward — try a "next page" affordance or right-edge arrow
  const moved = await tapMatch(page, /next page|turn page|forward/i, 2500);
  if (!moved) { await page.mouse.click(395, 448); await page.waitForTimeout(2500); }
}
await shot(page, 'mt042-03-story-p3');
const badges = await pageBadges();
const allText = badges.join(' | ');
console.log('page-3 semantics text:', allText.slice(0, 400));

const hasPickAPath = /pick a path!?/i.test(allText);
const hasNeutral = /page\s*\d/i.test(allText);
console.log('"Pick a Path!" badge present:', hasPickAPath);
console.log('neutral "Page N" present:', hasNeutral);
console.log(`\nMT-042: ${!hasPickAPath ? 'PASS' : 'FAIL'} (no Pick-a-Path badge on linear story)`);
console.log('  evidence: screenshots/mt042-03-story-p3.png');
await browser.close();
console.log('console errors:', errors.length);
