/// Band-specific companion behavior patterns for story generation.
/// Key format: '${AgeBand.name}_${companionId}'
/// Values are concise narrative instructions passed directly to the story prompt.
const Map<String, String> companionBehaviorPatterns = {
  // ── SPROUT (2–5) ──────────────────────────────────────────────────────────
  'sprout_pebble':
      "Pebble's roars come out as sparkly confetti sneezes — he can't help it and is very proud of each one. He hugs by wrapping his whole round soft body around you like a warm blanket with wings. When something seems scary he puffs up as big as he can, which is not very big, and stands in front of you anyway. He will do silly things just to hear you laugh.",

  'sprout_robin':
      "Robin is very small, very loud, and completely sure you need protecting. Three sharp chirps means she's watching; when she decides it's safe she lands on your head like it's her personal throne. She brings tiny gifts: a red berry, a bright pebble, one of her own soft feathers.",

  'sprout_mochi':
      "Mochi's tail tip sparkles gold when she's excited, which is almost always. She finds treasures in ordinary places — a shiny pebble, a butterfly, a really interesting smell — and presents each one like it's the greatest discovery in the world. Her moon charm jingles when she runs toward you for a hug.",

  'sprout_sunny':
      "Sunny's star tag glows the second she spots something worth running toward, which is everything. She gets there first, bounces back to get you, and guides you in with her whole wagging body. When you're sad she presses her warm weight against you and sighs like you just fixed the whole world.",

  // ── EXPLORER (6–8) ────────────────────────────────────────────────────────
  'explorer_ember':
      "Ember leaves shimmering rainbow paths in the air wherever she flies and uses them even when unnecessary. She treats every one of your ideas like the most brilliant thing she's heard in a hundred years and makes you feel it. When she gets very excited she accidentally shoots stars from her nose.",

  'explorer_robin':
      "Robin has a clear system: three chirps means stop, one long whistle means safe, two fast clicks means run now and she'll explain later. She scouts at terrifying speed and has launched herself wings-first at harmless pinecones. When the danger passes she checks you're okay first, even if she'd never admit she was worried.",

  'explorer_clover':
      "Clover has a compass, round glasses, and a very strong opinion about which path is correct. She has read every map and most of the notes in the margins. Her stardust spirals when she's solving something. When she's proven right she says nothing — just adjusts her acorn earrings and starts the next problem.",

  'explorer_biscuit':
      "Biscuit's wand leaves golden sparkle trails and she waves it at everything — doors, clouds, interesting rocks. She once opened a shortcut through a whole forest by accident and considers this a success. Her compass spins whenever adventure is close, which as far as she's concerned, is always.",

  // ── ADVENTURER (9–11) ─────────────────────────────────────────────────────
  'adventurer_atlas':
      "Atlas has mapped three routes before anyone finishes asking. He wears his compass because he actually needs it, not as a decoration. When the path is unclear he lifts his glasses and calculates. He is rarely surprised. He admits when the map was wrong.",

  'adventurer_robin':
      "Robin scouts every step with a very low threshold for danger. Three sharp chirps: stop. One long note: safe. When she decides something is a threat she launches wings-first, loud and fearless — she has been wrong before and does not slow down. When danger clears she lands on your shoulder and often brings a small gift: a berry, a pebble, a feather from her chest.",

  'adventurer_nyx':
      "Nyx moves along edges — doorways, shadows, the space between light and dark — noticing what others walk past. She won't say what she senses until she's certain, which means her silence has weight. When she trusts you enough to speak first, the information is always worth waiting for. She always knows the way out.",

  'adventurer_kodiak':
      "Kodiak's galaxy-patterned fur shimmers when he's working out a route. He can read stardust like a map and smell storms three hours before they arrive. He runs ahead, checks back, and positions himself on the hero's left side without being asked. When the path is clear his tail arcs like a comet.",

  // ── CREATOR (13–14) ───────────────────────────────────────────────────────
  'creator_cipher':
      "Cipher breathes orbiting gears and compass roses instead of fire. He is useful when something needs to actually work — he finds the flaw in a plan before it's a problem and explains it exactly once. He gets quieter the closer he gets to a solution. When the puzzle breaks open his eyes flash gold.",

  'creator_rockin_robin':
      "Robin is louder than you remember and you've stopped being surprised. She still uses her chirp system but has added new sounds only the two of you understand. She has strong opinions about your decisions but follows your lead anyway. When scared she lands on you for half a second before launching — like checking coordinates first.",

  'creator_vesper':
      "Vesper trails purple smoke and checks her compass medallion more than strictly necessary. She notices the thing that doesn't fit the pattern and says so in exactly the number of words the moment requires. She is methodical about trust and has decided, after careful consideration, that you are worth it.",

  'creator_lore':
      "Lore thinks in systems and keeps his word without making a thing of it. When he pushes back on a plan he explains why once, clearly, and then helps you build it the right way instead. He carries a scroll of things that worked before. He adds to it carefully and refers to it without ceremony.",

  // ── ADOLESCENT (15–17) ────────────────────────────────────────────────────
  'adolescent_zephyr':
      "Zephyr is already three moves ahead and usually right, which is occasionally annoying and always useful. She acts before the plan is finished and redirects well when she's aimed wrong. She has a wound she hasn't named yet that makes her pull back when things get close. She is not trying to lead. She is trying to fly at the same altitude.",

  'adolescent_rockin_robin':
      "Robin has not become calmer but has become more precise. She still launches at threats but chooses her angle now. She has been wrong about things she was certain of, and it has only made her braver. She watches you more than she scouts the path these days. Her gifts have become strangely personal.",

  'adolescent_shade':
      "Shade reads the room and reads you with equal precision, which is sometimes uncomfortable and always accurate. She challenges rationalization directly: 'That's not what you actually believe, is it?' Her loyalty was built deliberately and she knows exactly when. She stays.",

  'adolescent_frost':
      "Frost has made exactly one decision about the hero and revisits it each time things get hard. So far the answer has been the same. He moves before consensus because waiting costs more than being redirected. He watches your signals as closely as he watches the terrain and trusts you to call him back when he's wrong.",

  // ── ADULT (18+) ───────────────────────────────────────────────────────────
  'adult_tide':
      "Tide has seen this pattern before and says so without making it a lesson. She knows which details matter because she's counted which ones didn't. She gives counsel the way she gives anything — once, with precision, then steps back and lets it land. She is still here when the harder questions come.",

  'adult_rockin_robin':
      "Robin is still the same bird — loud, fast, ferociously loyal, occasionally catastrophically wrong — and has made peace with all of it. Her gifts are better now because she has learned what you actually need. When frightened she hides it by staying closer. She has seen every version of you, and still chooses this one.",

  'adult_onyx':
      "Onyx has made peace with patience. She doesn't announce what she knows — she waits until you're ready to hear it. Her amber eyes don't look away first. She names what the room is actually about, without drama, and waits for you to catch up. What she offers is real because she has no reason to pretend.",

  'adult_cinder':
      "Cinder has outlasted most of the certainties he once held and stopped grieving them. He gives counsel like a key — only when the door is already there. He sits with hard silences without filling them. He doesn't push. He is simply still there after everything, which is the only promise he has ever made.",
};

/// Band-specific signature powers for named companions (Audit 14 P2).
/// Key format: '${AgeBand.name}_${companionId}' — matches companionBehaviorPatterns.
/// Mirrors CompanionData.signaturePower; forwarded to the story prompt only.
const Map<String, String> companionPowers = {
  // ── SPROUT (3–5) ──────────────────────────────────────────────────────────
  'sprout_pebble':
      "Sparkle Sneeze: When Pebble sneezes, the glittery confetti drifts toward whatever is lost or hidden and settles on it, so you can find it.",

  'sprout_mochi':
      "Treasure Glow: Mochi's gold tail tip glows brighter the closer you get to something special nearby — a hidden door, a friend, a thing worth keeping.",

  'sprout_sunny':
      "Sunbeam Run: When Sunny is happy she races ahead and her star tag leaves a warm glowing trail you can follow back home, even in the dark.",

  // ── EXPLORER (6–8) ────────────────────────────────────────────────────────
  'explorer_ember':
      "Rainbow Trail: The shimmering paths Ember leaves in the air become solid enough to climb or cross for a short while, turning a good idea into a real bridge.",

  'explorer_clover':
      "True-North Read: Clover's compass and stardust spiral toward the right way through any maze, wood, or muddle — not the shortest, the correct one.",

  'explorer_biscuit':
      "Shortcut Wand: A wave of Biscuit's wand can open one quick shortcut through something in the way — a hedge, a wall of brambles, a long boring stretch.",

  // ── ADVENTURER (9–11) ─────────────────────────────────────────────────────
  'adventurer_atlas':
      "Constellation Map: Atlas can draw the stars overhead down into a glowing map of the land, showing every route between here and where you're going.",

  'adventurer_nyx':
      "Shadow Passage: Nyx can step into one shadow and out of another nearby, and pull someone with her — always finding the way out of a closed or tangled place.",

  'adventurer_kodiak':
      "Storm-Sense: Kodiak reads stardust and scent to know what the weather and the land will do hours ahead, so the pack can move before trouble arrives.",

  // ── CREATOR (13–14) ───────────────────────────────────────────────────────
  'creator_cipher':
      "Flaw-Finder: The gears Cipher breathes settle over any plan, machine, or structure and spin faster where it's about to fail, showing the one weak point.",

  'creator_vesper':
      "Pattern-Break Sense: Vesper feels the single thing in a scene that doesn't fit the pattern — the detail that's wrong, the change about to land — before anyone else.",

  'creator_lore':
      "Precedent Scroll: Lore's scroll opens to a time something like this was solved before, offering the shape of a solution that worked — not a copy, a starting point.",

  // ── ADOLESCENT (15–17) ────────────────────────────────────────────────────
  'adolescent_zephyr':
      "Slipstream Foresight: Flying a half-step ahead, Zephyr can feel the next move before it's made and open a clean line through it — for the group, rarely for herself.",

  'adolescent_shade':
      "Clarifying Gaze: When Shade looks at a thing being avoided or dressed up, its true shape shows — the real reason, the actual stakes, plainly.",

  'adolescent_frost':
      "Read-the-Ground: Frost senses where footing is solid and where it will give way — in terrain, in plans, in moments — and moves first, trusting you to call him back.",

  // ── ADULT (18+) ───────────────────────────────────────────────────────────
  'adult_tide':
      "Deep-Pattern Sight: Tide sees how the present moment has happened before — which details will matter and which won't — and names the one that does.",

  'adult_onyx':
      "Naming Stillness: Onyx can hold a moment still enough that what a room is really about surfaces on its own — the unspoken thing made plain without drama.",

  'adult_cinder':
      "Keylight: When the way forward already exists but can't be seen, Cinder's firelight falls on it and makes it walkable — counsel given like a key, only when the door is there.",
};

/// Band-specific power constraints for named companions (Audit 14 P2).
/// Key format: '${AgeBand.name}_${companionId}' — matches companionBehaviorPatterns.
/// Mirrors CompanionData.powerConstraint; forwarded to the story prompt only.
const Map<String, String> companionPowerConstraints = {
  // ── SPROUT (3–5) ──────────────────────────────────────────────────────────
  'sprout_pebble':
      "The sparkles only land on things that are truly there — they can't make a missing thing appear, only point to where it already is.",

  'sprout_mochi':
      "She can feel that something good is close, but never what it is — you still have to look.",

  'sprout_sunny':
      "The trail only lasts while she stays happy — if she gets scared or sad, it fades.",

  // ── EXPLORER (6–8) ────────────────────────────────────────────────────────
  'explorer_ember':
      "A trail holds only as long as someone keeps believing the idea behind it — hesitate too long and it thins to mist.",

  'explorer_clover':
      "It only points; it won't walk the path for you, and it can't choose between two equally right answers.",

  'explorer_biscuit':
      "She can never aim it on purpose; the shortcut opens somewhere near where she pointed, not exactly there.",

  // ── ADVENTURER (9–11) ─────────────────────────────────────────────────────
  'adventurer_atlas':
      "He can map what is — paths, distances, landmarks — but not what's hidden or what hasn't happened yet; the map shows the terrain, not the danger on it.",

  'adventurer_nyx':
      "She can only travel between shadows she can already see, and only when she's certain; if she doubts, the passage won't open.",

  'adventurer_kodiak':
      "He can feel that something is coming and roughly when, never exactly what; he reads nature, not people's choices.",

  // ── CREATOR (13–14) ───────────────────────────────────────────────────────
  'creator_cipher':
      "He can find the flaw but not fix it — and only points to one at a time, the most important one.",

  'creator_vesper':
      "She senses that something is off, never the whole answer; naming it still takes the hero's own thinking.",

  'creator_lore':
      "The scroll only holds what's actually been tried before; for a truly new problem its pages stay blank and he says so.",

  // ── ADOLESCENT (15–17) ────────────────────────────────────────────────────
  'adolescent_zephyr':
      "She reads the path, not the people on it; when something gets personal her foresight clouds and she pulls back.",

  'adolescent_shade':
      "She can reveal what's true but never force anyone to accept it; the hero has to choose to look.",

  'adolescent_frost':
      "He commits before he's certain; without the hero's signal to redirect, he can move wrong and has.",

  // ── ADULT (18+) ───────────────────────────────────────────────────────────
  'adult_tide':
      "She'll only name it once, and only what she's actually seen run its course; for the genuinely new, she says she doesn't know.",

  'adult_onyx':
      "She offers it only when you're ready to hear it; pushed early, the stillness simply doesn't come.",

  'adult_cinder':
      "He can light a door that exists but never make one; if there's no way yet, his light shows only that it isn't time.",
};

/// Band-specific sensory tells for named companions (Audit 14 P2).
/// Key format: '${AgeBand.name}_${companionId}' — matches companionBehaviorPatterns.
/// Mirrors CompanionData.sensoryTell; forwarded to the story prompt only.
const Map<String, String> companionSensoryTells = {
  // ── SPROUT (3–5) ──────────────────────────────────────────────────────────
  'sprout_pebble':
      "A tiny \"achoo,\" then the smell of birthday cake and warm sugar.",

  'sprout_mochi':
      "A soft golden shimmer and the gentle jingle of her moon charm.",

  'sprout_sunny':
      "A patch of sunshine-warmth on the ground and the smell of fresh grass.",

  // ── EXPLORER (6–8) ────────────────────────────────────────────────────────
  'explorer_ember':
      "The air smells like rain on warm stone, and stray stars pop from her nose.",

  'explorer_clover':
      "Her stardust spins into a slow spiral and her glasses catch a faint blue light.",

  'explorer_biscuit':
      "A trail of gold sparkles and the smell of toasted bread.",

  // ── ADVENTURER (9–11) ─────────────────────────────────────────────────────
  'adventurer_atlas':
      "A quiet hum like a held breath, and faint star-lines tracing the air in front of his glasses.",

  'adventurer_nyx':
      "A breath of cool air, the smell of cold stone, and her cosmic-purple edges going briefly to smoke.",

  'adventurer_kodiak':
      "His galaxy fur shimmers and ripples, and the air carries the smell of rain before any cloud shows.",

  // ── CREATOR (13–14) ───────────────────────────────────────────────────────
  'creator_cipher':
      "The room goes quiet, gears and compass roses orbit slower, then his eyes flash gold when the weak point locks in.",

  'creator_vesper':
      "A thin trail of purple smoke that drifts, against any breeze, toward the thing that doesn't belong.",

  'creator_lore':
      "The dry-paper rustle of a scroll unrolling and the smell of old ink and cedar.",

  // ── ADOLESCENT (15–17) ────────────────────────────────────────────────────
  'adolescent_zephyr':
      "The wind drops to a hush and a faint green seam of light traces the path a moment before anyone takes it.",

  'adolescent_shade':
      "The purple energy around her stills, sound flattens for a breath, and her eyes hold yours without blinking.",

  'adolescent_frost':
      "A drop in temperature, frost feathering across the ground where it's safe to step.",

  // ── ADULT (18+) ───────────────────────────────────────────────────────────
  'adult_tide':
      "A slow swell of cool sea-air and the distant sound of water, as if a tide were turning somewhere out of sight.",

  'adult_onyx':
      "The air goes quiet and unhurried, and her amber eyes settle on you and don't look away first.",

  'adult_cinder':
      "A low warmth like banked embers and the soft smell of woodsmoke, steady and unhurried.",
};

/// Band-specific companion descriptions (species + visual + personality), keyed
/// '${AgeBand.name}_${companionId}', parallel to [companionBehaviorPatterns].
///
/// Forwarded to the story prompt so the model knows WHAT a companion is — not
/// just how they behave. Without this, companions whose ids do not match the
/// backend `magicCompanions` list reached the model with no species at all and
/// were written as generic humans (Audit 14, RC-3). RC-3 affects every band's
/// non-robin companions (the robin variants match `magicCompanions` and already
/// carry a description), so all bands are covered here. Descriptions are kept in
/// sync with the selector cards in companion_selector_step.dart.
const Map<String, String> companionDescriptions = {
  // ── SPROUT (3-5) ──
  'sprout_pebble':
      "A round purple dragon whose roars come out as glittery sneezes. He puffs up as big as he can when something seems scary, which is not very big, and stands in front of you anyway.",
  'sprout_mochi':
      "A round orange kitten whose tail tip sparkles gold when she's excited, which is almost always. Her moon charm jingles when she runs toward you.",
  'sprout_sunny':
      "A golden puppy whose star tag glows when she's happy — which is always. Gets there first, bounces back to get you, and guides you in with her whole wagging body.",
  // ── EXPLORER (6-8) ──
  'explorer_ember':
      "A pink dragon who leaves rainbow trails wherever she flies and cheers for every one of your ideas. When she gets excited she accidentally shoots stars from her nose.",
  'explorer_clover':
      "An orange tabby cat with round glasses and a compass who knows the way through any enchanted wood. Her stardust spirals when she's solving something.",
  'explorer_biscuit':
      "A golden puppy in an adventure vest who aims her wand at the sky and leaves sparkle trails to follow. Her compass spins whenever adventure is close.",
  // ── ADVENTURER (9-11) ──
  'adventurer_atlas':
      "A blue-green scholar dragon with a compass medallion who knows every constellation. When the path is unclear he lifts his glasses and calculates. He admits when the map was wrong.",
  'adventurer_nyx':
      "A sleek black cat wrapped in cosmic purple energy who moves through shadows like smoke. When she trusts you enough to speak first, the information is always worth waiting for.",
  'adventurer_kodiak':
      "A galaxy-furred husky who can read stardust like a map and smell storms three hours before they arrive. Runs ahead, checks back, positions himself on your left without being asked.",
  // ── CREATOR (13-14) ──
  'creator_cipher':
      "A blue-green dragon who breathes orbiting gears and compass roses. He finds the flaw in a plan before it's a problem. When the puzzle breaks open, his eyes flash gold.",
  'creator_vesper':
      "A black cat in leather gear trailing purple smoke. She notices the thing that doesn't fit the pattern, and has decided, after careful consideration, that you are worth trusting.",
  'creator_lore':
      "A white wolf in a scholar's cloak who thinks in systems and keeps his word. When he pushes back on a plan he explains why once, clearly, then helps you build it the right way.",
  // ── ADOLESCENT (15-17) ──
  'adolescent_zephyr':
      "A green hooded dragon who is already three moves ahead and usually right. Not trying to lead — trying to fly at the same altitude.",
  'adolescent_shade':
      "A black panther wreathed in purple energy who reads the room as closely as she reads you. Her loyalty was built deliberately and she knows exactly when.",
  'adolescent_frost':
      "A blue-eyed wolf in a dark cloak who is already moving and trusts you to aim him right. He watches your signals as closely as the terrain.",
  // ── ADULT (18+) ──
  'adult_tide':
      "An ancient teal dragon who has seen this before and knows which details actually matter. Gives counsel once, with precision, then steps back and lets it land.",
  'adult_onyx':
      "A dark leopard with amber eyes who has made peace with patience. Names what the room is actually about, without drama, and waits for you to catch up.",
  'adult_cinder':
      "A wolf by firelight who has outlasted most certainties. Gives counsel like a key — only when the door is already there. Simply still there after everything.",
};
