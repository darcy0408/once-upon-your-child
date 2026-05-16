// MT-040 — phrase-per-line layout for Read Along / Learning-to-Read stories.
// Pick "Easy Reader" (sets learningToReadMode=true), generate a story, and
// confirm the page body renders as several SHORT lines (one sentence/phrase
// per line) rather than one wrapped paragraph.
import { generateStory, tapGo, waitForStory, dumpSemantics, enableSemantics, shot }
  from './drive.mjs';

const { browser, page, errors } = await generateStory({ age: 4, styleRe: /learning to read/i });
await shot(page, 'mt040-00-review');

const went = await tapGo(page, 8000);
console.log('GO tapped:', went);
const got = await waitForStory(page, 120000);
console.log('story generated:', got);
await page.waitForTimeout(2500);
await shot(page, 'mt040-01-story-p1');

// Pull the story body text node and inspect its line structure.
await enableSemantics(page);
const body = await page.evaluate(() => {
  // The page body is a large text node — find the longest text content node.
  const nodes = [...document.querySelectorAll('flt-semantics')]
    .map(n => (n.getAttribute('aria-label') || n.textContent || '').trim())
    .filter(t => t.length > 40
      && !/reading settings|favorites|new story|read to me|page \d/i.test(t));
  nodes.sort((a, b) => b.length - a.length);
  return nodes[0] || '';
});
console.log('story body (semantics text):', JSON.stringify(body.slice(0, 300)));

// Phrase-per-line means many short sentence fragments. The semantics text is
// flattened, so instead measure visually: count distinct text rows by
// scanning the rendered canvas region is unreliable — use sentence count as
// a proxy plus a screenshot for the human-visible line breaks.
const sentences = body.split(/(?<=[.!?])\s+/).filter(s => s.trim().length > 2);
console.log('sentence count in body:', sentences.length);
console.log('avg sentence length:', Math.round(body.length / Math.max(1, sentences.length)));

console.log('\nMT-040: layout is VISUAL — see screenshot mt040-01-story-p1.png');
console.log('  expect ~6-10 short lines (one phrase per line), line-height ~2.1');
await browser.close();
console.log('console errors:', errors.length);
