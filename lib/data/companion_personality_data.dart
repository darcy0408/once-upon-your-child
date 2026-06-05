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

  // ── CREATOR (12–14) ───────────────────────────────────────────────────────
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
  // ── CREATOR (12-14) ──
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
