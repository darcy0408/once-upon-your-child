// MT-041 — Sprout loading-screen mini-game (tap-the-stars).
// Walk a 3-year-old to GO!, then capture the loading view repeatedly during
// the ~30-60s generation window. Look for golden star targets, the
// "Tap the stars!" hint, and the sparkle counter.
import { generateStory, tapGo, dumpSemantics, enableSemantics, shot } from './drive.mjs';

const { browser, page, errors } = await generateStory({ age: 3, styleRe: /story quest/i });
const went = await tapGo(page, 1200);
console.log('GO tapped:', went);

let sawHint = false, sawSparkles = false, sawConstellation = false, sawGame = false;
const frames = [];
for (let i = 0; i < 40; i++) {
  await page.waitForTimeout(900);
  await shot(page, `mt041-frame-${String(i).padStart(2,'0')}`);
  let txt = '';
  try { await enableSemantics(page); txt = (await dumpSemantics(page))
    .map(n => n.label || n.text || '').join(' '); } catch {}
  if (/tap the stars/i.test(txt)) sawHint = true;
  if (/sparkle/i.test(txt)) sawSparkles = true;
  if (/constellation|countdown/i.test(txt)) sawConstellation = true;
  if (/weaving|creating your|magic is happening|loading|hold tight/i.test(txt)) sawGame = true;
  // tap around the companion stage to trigger star bursts
  await page.mouse.click(207, 360);
  await page.mouse.click(150, 300);
  await page.mouse.click(264, 420);
  // stop once the story page has actually rendered
  if (/^.*page \d+ of \d+/i.test(txt) || /read to me/i.test(txt)) {
    console.log(`story arrived at frame ${i}`); break;
  }
  frames.push(txt.slice(0, 60));
}
console.log('saw "Tap the stars" hint :', sawHint);
console.log('saw sparkle counter      :', sawSparkles);
console.log('saw constellation/count  :', sawConstellation);
console.log('saw loading view at all  :', sawGame);
console.log('\nMT-041: review mt041-frame-*.png for golden stars + bursts around companion');
await browser.close();
console.log('console errors:', errors.length);
