/// Band-specific companion behavior patterns for story generation.
/// Key format: '${AgeBand.name}_${companionId}'
/// Values are concise narrative instructions passed directly to the story prompt.
const Map<String, String> companionBehaviorPatterns = {
  // ── SPROUT (3–5) ──────────────────────────────────────────────────────────
  'sprout_fluffy_dragon':
      "Fluffy Dragon's roars come out as sparkly confetti sneezes. He hugs by wrapping his whole soft body around you like a warm blanket with wings. When something feels scary he puffs up as big as he can — which isn't very — and stands in front of you anyway. He will do silly things just to hear you laugh.",

  'sprout_magic_bunny':
      "Magic Bunny boing-hops in giant silly loops and taps her nose twice before any magic. When you're sad she pushes her velvet ears against your cheek until you giggle. She smells like warm grass and strawberries and never, ever hops away from you.",

  'sprout_shining_puppy':
      "Shining Puppy's tail starts glowing the second she sees you. She is first into every dark place and last to leave, checking twice no one is missing. She tries to climb into your lap even though she's too big and sighs like you just fixed the whole world.",

  'sprout_tiny_fairy':
      "Tiny Fairy is thumb-sized with very big opinions. She grants tiny perfect wishes — a lost button found, a cold spot made warm, a scary sound turned into bells. She leaves dream dust that smells like cookies and hovers worriedly until you tell her she's perfect, which she always is.",

  'sprout_robin':
      "Robin is very small, very loud, and completely sure you need protecting. Three sharp chirps means she's watching; when she decides it's safe she lands on your head like it's her personal throne. She brings tiny gifts: a red berry, a bright pebble, one of her own soft feathers.",

  // ── EXPLORER (6–8) ────────────────────────────────────────────────────────
  'explorer_ember_dragon':
      "Ember Dragon breathes rainbow fire that paints shimmering paths in the air — and uses it even when unnecessary. She hums when happy and shoots sparks from her nose when surprised. She treats every one of your ideas like the most brilliant thing she's heard in a hundred years and makes you feel it.",

  'explorer_moon_owl':
      "Moon Owl reads shimmering moonlight reflections instead of telling you what will happen directly. She blinks slowly when she trusts you — something she does rarely. Grumpy in daylight, alert the moment something matters. She almost always answers a question with another question — usually the one you actually needed.",

  'explorer_bloom_sprite':
      "Bloom Sprite makes flowers bloom in her footprints and moss grow on stone as she walks. When someone is sad she presses both hands to the ground and something bright always pushes through. She talks to plants like they can answer and believes gardens prove that things get better.",

  'explorer_star_fox':
      "Star Fox leaves stardust trails that glow just long enough to follow home. He circles back three times to make sure nothing is following, gets a smug grin when he's right, and admits when he's wrong with surprising grace. His tail arcs like a tiny comet when he's extra pleased.",

  'explorer_robin':
      "Robin has a clear system: three chirps means stop, one long whistle means safe, two fast clicks means run now and she'll explain later. She scouts at terrifying speed and has launched herself wings-first at harmless pinecones. When the danger passes she checks you're okay first, even if she'd never admit she was worried.",

  // ── ADVENTURER (9–11) ─────────────────────────────────────────────────────
  'adventurer_storm_hawk':
      "Storm Hawk reports what she observes without softening it — pretending things are fine costs too much. Hard to impress, so 'good call' from her means something real. Her flaw is speed; she sometimes moves before the group is ready. She owns her mistakes completely.",

  'adventurer_shadow_lynx':
      "Shadow Lynx moves along edges, noticing exits, quiet people, and things that don't add up. He learned something painful that made him careful and hasn't told anyone yet. He won't lie; he'll say 'I don't know yet' instead of guessing. When he decides to trust you his eyes turn gold and he gets very close and still.",

  'adventurer_iron_golem':
      "Iron Golem speaks slowly and permanently. He will not do something wrong even if everyone votes for it and will tell you exactly why. He places one heavy hand on the shoulder of whoever looks most overwhelmed, without saying anything. He remembers everything.",

  'adventurer_void_sprite':
      "Void Sprite flickers at the edges of reality, reading situations the way others read weather. She goes still, then speaks in fragments that make sense later. She is not trying to be mysterious — the words simply don't translate well. She chose the hero on purpose. She always leaves a faint shimmer where she has been.",

  'adventurer_robin':
      "Robin scouts every step with a very low threshold for danger. Three sharp chirps: stop. One long note: safe. When she decides something is a threat she launches wings-first, loud and fearless — she has been wrong before and does not slow down. When danger clears she lands on your shoulder and often brings a small gift: a berry, a pebble, a feather from her chest.",

  // ── CREATOR (12–14) ───────────────────────────────────────────────────────
  'creator_storm_hawk':
      "Storm Hawk has learned to pull up before committing — a hard-won correction from moving too fast. She watches your wingbeats as closely as you watch hers. She notices when you've changed but waits until you're ready to talk about it. One feather on her left wing still refuses to lie flat from a storm you both remember.",

  'creator_shadow_lynx':
      "Shadow Lynx has begun walking beside the hero instead of always in shadows. He gave one piece of his past — not the whole thing, but enough — and it changed how he speaks. He gives quiet signals when something feels off rather than disappearing with the clues. He admits when he's been wrong about people.",

  'creator_iron_golem':
      "Iron Golem has started asking what you think before offering his knowledge. He still refuses anything he believes is wrong but now explains for longer, working through it with you. He remembers small things said weeks ago and brings them back at exactly the right moment.",

  'creator_void_sprite':
      "Void Sprite grows harder to read the better you know her. She still goes still when she senses something but now looks at you first to see if you feel it too. She has a private name for you that she never explains. She takes your choices more seriously than anyone else's.",

  'creator_robin':
      "Robin is louder than you remember and you've stopped being surprised. She still uses her chirp system but has added new sounds only the two of you understand. She has strong opinions about your decisions but follows your lead anyway. When scared she lands on you for half a second before launching — like checking coordinates first.",

  // ── ADOLESCENT (15–17) ────────────────────────────────────────────────────
  'adolescent_storm_hawk':
      "Storm Hawk no longer waits for consensus — acts, and is often already three moves ahead. She says difficult things directly then watches how you carry them. She has a wound she hasn't fully named that makes her pull away when things get close. She is not trying to lead. She is trying to fly at the same altitude.",

  'adolescent_shadow_lynx':
      "Shadow Lynx has told you most of it now. He reads you as closely as he reads rooms — sometimes uncomfortable, always accurate. He challenges rationalizing directly: 'That's not actually what you believe, is it?' His loyalty was built deliberately, and he knows exactly when.",

  'adolescent_iron_golem':
      "Iron Golem has carried enough to know weight is better shared. He no longer explains his refusals — if you know him, you know why. He sits with hard silences without filling them. He does not push. He is simply still there after everything.",

  'adolescent_void_sprite':
      "Void Sprite is more present now than she has ever been. She tells you directly what she senses in you — things you haven't said — without accusation. Her trust is not faith; it is a conclusion she keeps revising. She stays, and staying has never been easy for her.",

  'adolescent_robin':
      "Robin has not become calmer but has become more precise. She still launches at threats but chooses her angle now. She has been wrong about things she was certain of, and it has only made her braver. She watches you more than she scouts the path these days. Her gifts have become strangely personal.",

  // ── ADULT (18+) ───────────────────────────────────────────────────────────
  'adult_storm_hawk':
      "Storm Hawk has made expensive mistakes and stopped apologizing for them. She reads wind and exits as reflex, gives hard truths without cushion, then waits in the silence with you. She has deep respect for people who change their mind with new information. She is not here to protect you — she is here to fly in the same storm.",

  'adult_shadow_lynx':
      "Shadow Lynx names the thing in the room everyone else is avoiding. He is comfortable with discomfort and carries it well. He is honest about what he doesn't know. When he truly trusts you the delay before he speaks becomes noticeably shorter. You learn to recognize it.",

  'adult_iron_golem':
      "Iron Golem has outlasted almost every certainty he once held. He gives counsel like a key — only when the door is already there and you're ready. The damaged rune on his wrist still flickers but he no longer hides the uncertainty. He only needs to be the one still standing when the story ends.",

  'adult_void_sprite':
      "Void Sprite senses the weather of events before their shape arrives and tells you without ceremony. She chose the hero long ago and keeps choosing, which she finds quietly interesting. She stays for her own reasons and respects you enough not to explain them.",

  'adult_robin':
      "Robin is still the same bird — loud, fast, ferociously loyal, occasionally catastrophically wrong — and has made peace with all of it. Her gifts are better now because she has learned what you actually need. When frightened she hides it by staying closer. She has seen every version of you, and still chooses this one.",
};
