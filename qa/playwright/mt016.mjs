// MT-016 — Sprout launch TTS fix. Walk a Sprout-age user to the GO! screen.
// Verify (non-audio): the Sprout GO! screen is reached and shows the on-screen
// recap ("I am <name>. Going to <place>. With <companion>.").
// AUDIO half is BLOCKED — the ElevenLabs /tts/synthesize endpoint is failing
// (503/401), so the ElevenLabs-voice playback cannot be verified.
import { onboardSeeded } from './nav-a11y.mjs';
import { walkHero, pickStoryStyle, tapForwardArrow } from './drive.mjs';
import { dumpSemantics, enableSemantics, shot } from './a11y.mjs';

const { browser, page, errors } = await onboardSeeded({ age: 3, name: 'Darcy' });

// Capture TTS network traffic.
const tts = [];
page.on('response', async r => {
  if (/tts|synthesize|elevenlabs/i.test(r.url())) {
    tts.push({ url: r.url().slice(-60), status: r.status() });
  }
});

await walkHero(page);
await pickStoryStyle(page, /story quest/i);
await tapForwardArrow(page, 5000);            // -> Sprout GO! screen
await page.waitForTimeout(3000);
await enableSemantics(page);
await shot(page, 'mt016-go-screen');

const nodes = await dumpSemantics(page);
const text = nodes.map(n => (n.label || n.text || '')).join(' | ');
console.log('GO-screen text:', text.replace(/\n/g, '/').slice(0, 400));

const reachedGo = /ready to go|go!/i.test(text);
const hasName = /i am.{0,8}darcy/i.test(text.replace(/\n/g, ' '));
const hasPlace = /going to/i.test(text);
const hasWith = /with/i.test(text);
console.log('reached Sprout GO! screen :', reachedGo);
console.log('recap shows "I am Darcy"  :', hasName);
console.log('recap shows "Going to ..."  :', hasPlace);
console.log('recap shows "With ..."      :', hasWith);

console.log('\nTTS network calls observed:', JSON.stringify(tts));
const nonAudioPass = reachedGo && hasName && hasPlace && hasWith;
console.log(`\nMT-016 (non-audio): ${nonAudioPass ? 'PASS' : 'FAIL'} — Sprout GO! screen + recap`);
console.log('MT-016 (audio): BLOCKED — ElevenLabs /tts/synthesize unavailable (401/503);'
  + ' ElevenLabs-voice playback cannot be verified.');
console.log('  evidence: screenshots/mt016-go-screen.png');
await browser.close();
console.log('console errors:', errors.length);
