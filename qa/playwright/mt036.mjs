// MT-036 — wizard progress-indicator back-navigation from the review step.
// From MagicReviewStep, tapping a progress dot (Pick Hero/Team/Place) should
// animate the wizard BACK to HeroCreatorStep at that sub-step.
import { generateStory, dumpSemantics, enableSemantics, shot, clickSem }
  from './drive.mjs';

const { browser, page, errors } = await generateStory({ age: 3, styleRe: /story quest/i });

async function pageText() {
  await enableSemantics(page);
  const n = await dumpSemantics(page);
  return n.map(x => x.label || x.text || '').join(' | ');
}

await shot(page, 'mt036-00-review');
const onReview = /ready to go|make magic.*step 4/i.test(await pageText());
console.log('on review step:', onReview);

// Tap the 2nd progress dot ("My Buddies!") — should go back to team picker.
const r1 = { pass: false };
await clickSem(page, 'My Buddies', 'button', { settle: 3500 });
await shot(page, 'mt036-01-after-buddies-dot');
let t = await pageText();
r1.pass = /buddies|pebble|robin|mochi|sunny|companion|adventure alone/i.test(t)
  && !/ready to go/i.test(t);
console.log('TAP "My Buddies!" dot -> buddies picker:', r1.pass);

// Back to review, then tap dot 1 ("My Hero!").
await clickSem(page, 'Make Magic', 'button', { settle: 3500 });
await clickSem(page, 'My Hero', 'button', { settle: 3500 });
await shot(page, 'mt036-02-after-hero-dot');
t = await pageText();
const r2pass = /your hero|archetype|choose your look|hero's name|boy|girl|role:/i.test(t)
  && !/ready to go/i.test(t);
console.log('TAP "My Hero!" dot -> hero picker:', r2pass);

console.log(`\nMT-036: ${(r1.pass && r2pass) ? 'PASS' : 'FAIL'}`);
console.log('  evidence: screenshots/mt036-01-after-buddies-dot.png, mt036-02-after-hero-dot.png');
await browser.close();
console.log('console errors:', errors.length);
