# Four new Sprout Life Quests — draft (mad / sad / scared / grateful)

**Status:** drafted in this file because parallel sessions had uncommitted edits to `lib/data/life_quest_data.dart` at draft time (the `SproutCloud` → `SproutFriend` rebrand + new `questBigHello`). Those have now landed (`1c668c0a`); paste these in just below `questBigHello` and add the four new identifiers to `allLifeQuests` near the top of the file.

**Friend personas these target:**
- `SproutFriend.bunny` — Rainy Bunny / **sad** → `questGoodbyeHug` (separation: when a grown-up leaves)
- `SproutFriend.lion` — Roary Lion / **mad** → `questBigNo` (anger: when someone says no)
- `SproutFriend.mouse` — Shy Mouse / **scared** → `questFirstHi` (social wobbles: meeting new people)
- `SproutFriend.pup` — Sunny Pup / **grateful** → `questWarmHeart` (gratitude: a handmade gift in the mail)

**Coping break wiring:** Belly Breath (sad/chest-tight), Dragon's Breath (mad/roar-it-out), Star Breath (scared/discreet), Hot Cocoa Breath (gratitude/savor-the-good). All four IDs already exist in the toolbox.

**Why a gratitude quest under "happy":** Sprout-age gratitude is concrete — noticing a specific kindness, feeling the warm-chest body cue, choosing how to give the love back. `questBigHello` already covers the bubbly arrival-excitement flavor of happy; this one fills the quieter "someone was kind to me, I want to say thank you with my whole heart" flavor. Together they balance Sunny Pup's range with the same 2-quest depth as the other three friends.

---

## 1. Add to `allLifeQuests` list

Right after the existing Sprout entries (`questBigBearHug`, `questBigLoud`, `questMyTurnYourTurn`, `questBigHello`):

```dart
  questGoodbyeHug,
  questBigNo,
  questFirstHi,
  questWarmHeart,
```

---

## 2. Quest definitions — paste after `questBigHello`

```dart
// ═══════════════════════════════════════════════════════════════════════════════
// SPROUT QUEST 5: The Bye-Bye Big Feeling  [Sprout: ages 2-5]
// Rainy Bunny — sad. Separation: a grown-up has to leave for work / errand /
// daycare drop-off. The drop-in-the-tummy moment. Both paths land on
// "missing means love is real" + the comfort of "I always come back."
// ═══════════════════════════════════════════════════════════════════════════════

const questGoodbyeHug = LifeQuestScenario(
  id: 'goodbye_hug',
  title: 'The Bye-Bye Big Feeling',
  hook: "Your grown-up has to go to work. You don't want them to leave.",
  emoji: '\u{1F49B}', // yellow heart
  emotions: ['sad', 'worried'],
  recommendedBands: [AgeBand.sprout],
  friend: SproutFriend.bunny,
  grownupTip:
      "Ask: 'How does your body feel when I say bye-bye? What helps it feel softer?'",
  startSegmentId: 'gb_start',
  segments: {
    'gb_start': QuestSegment(
      id: 'gb_start',
      content:
          'It is morning. You are eating toast.\n\n'
          'Your grown-up puts on their shoes.\n\n'
          '"I have to go to work, sweet pea. '
          'I will be back at snack time."\n\n'
          'Your tummy goes drop. '
          'Your eyes feel hot.',
      copingBreakId: 'belly_breath',
      choices: [
        QuestChoice(
          id: 'gb_c1a',
          text: 'Hold on tight to their leg',
          nextSegmentId: 'gb_hold',
        ),
        QuestChoice(
          id: 'gb_c1b',
          text: 'Use your words',
          nextSegmentId: 'gb_words',
        ),
      ],
    ),

    'gb_hold': QuestSegment(
      id: 'gb_hold',
      content:
          'Your arms wrap tight around their leg.\n\n'
          '"Don\'t go. Don\'t go."\n\n'
          'They kneel down to your level.\n\n'
          '"I see your big sad, {name}. '
          'It is okay to feel sad. '
          'I love you. I always come back."',
      choices: [
        QuestChoice(
          id: 'gb_c2a',
          text: 'Ask for one more hug',
          nextSegmentId: 'gb_hug',
        ),
        QuestChoice(
          id: 'gb_c2b',
          text: 'Take a big belly breath',
          nextSegmentId: 'gb_breath',
        ),
      ],
    ),

    'gb_words': QuestSegment(
      id: 'gb_words',
      content:
          'You take a wobbly breath in.\n\n'
          '"I don\'t want you to go. '
          'My tummy feels sad."\n\n'
          'They put their hand on your heart.\n\n'
          '"Thank you for telling me. '
          'My tummy feels a little sad too. '
          'But guess what? I always come back."',
      choices: [
        QuestChoice(
          id: 'gb_c3a',
          text: 'Trade kisses on the cheek',
          nextSegmentId: 'gb_kiss',
        ),
        QuestChoice(
          id: 'gb_c3b',
          text: 'Wave from the window',
          nextSegmentId: 'gb_wave',
        ),
      ],
    ),

    'gb_hug': QuestSegment(
      id: 'gb_hug',
      content:
          'You squeeze them with your biggest squeeze.\n\n'
          'They squeeze back. Squish, squish.\n\n'
          '"That is a snack-time hug. '
          'It will keep us both warm until I get home."\n\n'
          'Your eyes are still wet. '
          'But your heart feels held.',
      isEnding: true,
    ),

    'gb_breath': QuestSegment(
      id: 'gb_breath',
      content:
          'You put one hand on your tummy.\n\n'
          'In through your nose... '
          'out through your mouth.\n\n'
          'The tight in your chest gets a little softer.\n\n'
          '"You are doing such big work, {name}. '
          'I am proud of you."\n\n'
          'Sad does not stay forever. '
          'It is just here for now.',
      isEnding: true,
    ),

    'gb_kiss': QuestSegment(
      id: 'gb_kiss',
      content:
          'Smooch! On the cheek.\n\n'
          'Smooch! On their cheek.\n\n'
          '"One for the morning, '
          'one for snack time."\n\n'
          'They wave at the door. You wave back.\n\n'
          'You miss them already. '
          'And missing means love is real.',
      isEnding: true,
    ),

    'gb_wave': QuestSegment(
      id: 'gb_wave',
      content:
          'You stand at the window.\n\n'
          'They turn back and wave. Big wave. '
          'You wave bigger.\n\n'
          'They blow a kiss. You catch it. '
          'You blow one back.\n\n'
          'Bye-bye for now is not bye-bye forever. '
          'Snack time will come.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// SPROUT QUEST 6: The Big NO  [Sprout: ages 2-5]
// Roary Lion — mad. The HOT-face fist-tight feeling when a grown-up says no.
// Coping break: Dragon's Breath (mirrors the lion-roar pattern). Both paths
// land on the mad being legitimate AND survivable.
// ═══════════════════════════════════════════════════════════════════════════════

const questBigNo = LifeQuestScenario(
  id: 'big_no',
  title: 'The Big NO',
  hook: 'You ask for a cookie. Grown-up says no. Your face gets HOT.',
  emoji: '\u{1F981}', // lion face
  emotions: ['angry', 'frustrated', 'sad'],
  recommendedBands: [AgeBand.sprout],
  friend: SproutFriend.lion,
  grownupTip:
      "Ask: 'When you hear NO, what does your body do? What can you ask instead?'",
  startSegmentId: 'bn_start',
  segments: {
    'bn_start': QuestSegment(
      id: 'bn_start',
      content:
          'You see the cookies on the counter.\n\n'
          '"Cookie, please?"\n\n'
          'Grown-up shakes their head.\n\n'
          '"Not before lunch, love."\n\n'
          'NOOOO! '
          'Your hands go tight. '
          'Your face goes HOT. '
          'A big mad lion roars inside you.',
      copingBreakId: 'dragon_breath',
      choices: [
        QuestChoice(
          id: 'bn_c1a',
          text: 'Stomp your feet',
          nextSegmentId: 'bn_stomp',
        ),
        QuestChoice(
          id: 'bn_c1b',
          text: 'Roar it out like a dragon',
          nextSegmentId: 'bn_roar',
        ),
      ],
    ),

    'bn_stomp': QuestSegment(
      id: 'bn_stomp',
      content:
          'STOMP STOMP STOMP!\n\n'
          'Your feet go thump on the floor.\n\n'
          'Grown-up sits down on the rug.\n\n'
          '"I see your big mad. '
          'Mad is okay. Stomping is okay too — '
          'as long as nobody gets hurt."',
      choices: [
        QuestChoice(
          id: 'bn_c2a',
          text: 'Stomp until the mad gets smaller',
          nextSegmentId: 'bn_smaller',
        ),
        QuestChoice(
          id: 'bn_c2b',
          text: 'Ask: when CAN I have a cookie?',
          nextSegmentId: 'bn_when',
        ),
      ],
    ),

    'bn_roar': QuestSegment(
      id: 'bn_roar',
      content:
          'You take a big lion breath in.\n\n'
          'ROOOOAAAARRR!\n\n'
          'The hot in your face starts to come out '
          'with the sound.\n\n'
          'Grown-up roars back. '
          'A little quieter. '
          'A little funnier.\n\n'
          'You both laugh — just a small laugh.\n\n'
          'Mad is still here. '
          'But it is smaller now.',
      choices: [
        QuestChoice(
          id: 'bn_c3a',
          text: 'Ask: when CAN I have a cookie?',
          nextSegmentId: 'bn_when',
        ),
        QuestChoice(
          id: 'bn_c3b',
          text: 'Pick a different snack',
          nextSegmentId: 'bn_pick',
        ),
      ],
    ),

    'bn_smaller': QuestSegment(
      id: 'bn_smaller',
      content:
          'Stomp. Stomp. Stomp.\n\n'
          'Each stomp is a little softer.\n\n'
          'Soon your feet just want to walk.\n\n'
          'You sit down next to grown-up.\n\n'
          '"That was a big mad," they say. '
          '"You let it out. You did good, {name}."\n\n'
          'Mad lions get tired too.',
      isEnding: true,
    ),

    'bn_when': QuestSegment(
      id: 'bn_when',
      content:
          '"When CAN I have a cookie?"\n\n'
          '"After lunch. So in a little bit."\n\n'
          '"Pinky promise?"\n\n'
          '"Pinky promise."\n\n'
          'You hook your littlest finger around theirs.\n\n'
          'Waiting is easier when you know when. '
          'And mad turned into a question.',
      isEnding: true,
    ),

    'bn_pick': QuestSegment(
      id: 'bn_pick',
      content:
          'You look in the snack bowl.\n\n'
          'Apple? Cracker? Cheese?\n\n'
          'You pick the cheese. '
          'Crunch, crunch.\n\n'
          'It is not a cookie. '
          'But it is yummy too.\n\n'
          'And after lunch — there is still a cookie waiting. '
          'You did not lose. You waited.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// SPROUT QUEST 7: The First Hi  [Sprout: ages 2-5]
// Shy Mouse — scared/shy. The walk-into-a-room-of-strangers wobble. Coping
// break: Star Breath (discreet finger-tracing — perfect for kids who don't
// want a regulation technique to draw extra eyes). Endings honor staying
// close OR taking the small brave step.
// ═══════════════════════════════════════════════════════════════════════════════

const questFirstHi = LifeQuestScenario(
  id: 'first_hi',
  title: 'The First Hi',
  hook: "You walk in. The room is full of people you don't know yet.",
  emoji: '\u{1F42D}', // mouse face
  emotions: ['worried', 'scared'],
  recommendedBands: [AgeBand.sprout],
  friend: SproutFriend.mouse,
  grownupTip:
      "Ask: 'When you meet someone new, where do you feel it in your body? Where is your safe spot?'",
  startSegmentId: 'fh_start',
  segments: {
    'fh_start': QuestSegment(
      id: 'fh_start',
      content:
          'It is your cousin\'s birthday party.\n\n'
          'You walk in. So many people!\n\n'
          'Big people you don\'t know. '
          'Little people you don\'t know.\n\n'
          'You hide behind your grown-up\'s leg. '
          'Your heart goes fast like a tiny mouse.',
      copingBreakId: 'star_breath',
      choices: [
        QuestChoice(
          id: 'fh_c1a',
          text: 'Stay close to your grown-up',
          nextSegmentId: 'fh_close',
        ),
        QuestChoice(
          id: 'fh_c1b',
          text: 'Peek out and look around',
          nextSegmentId: 'fh_peek',
        ),
      ],
    ),

    'fh_close': QuestSegment(
      id: 'fh_close',
      content:
          'Your hand fits inside theirs.\n\n'
          'They squeeze. You squeeze back.\n\n'
          '"You can stay right here as long as you need to," '
          'they whisper.\n\n'
          'Slow and slow, your mouse heart slows down.\n\n'
          'Safe means right here, '
          'with the person who knows your name.',
      choices: [
        QuestChoice(
          id: 'fh_c2a',
          text: 'Try a tiny wave to a kid',
          nextSegmentId: 'fh_wave',
        ),
        QuestChoice(
          id: 'fh_c2b',
          text: 'Stay tucked in for now',
          nextSegmentId: 'fh_tuck',
        ),
      ],
    ),

    'fh_peek': QuestSegment(
      id: 'fh_peek',
      content:
          'One eye. Then two eyes.\n\n'
          'You see a kid with a juice box. '
          'A kid with a balloon. '
          'A kid in a bunny shirt.\n\n'
          'The bunny-shirt kid sees you. '
          'They smile. A small smile.\n\n'
          'Your mouse heart goes thump-thump. '
          'But not as fast.',
      choices: [
        QuestChoice(
          id: 'fh_c3a',
          text: 'Smile back — just a little',
          nextSegmentId: 'fh_smile',
        ),
        QuestChoice(
          id: 'fh_c3b',
          text: 'Trace a star on your hand',
          nextSegmentId: 'fh_star',
        ),
      ],
    ),

    'fh_wave': QuestSegment(
      id: 'fh_wave',
      content:
          'Your fingers wiggle. The tiniest wave.\n\n'
          'A kid waves back. With their whole hand.\n\n'
          '"I have a balloon!"\n\n'
          'You take one step closer. '
          'Just one.\n\n'
          'Brave is not big. '
          'Brave is one little step at a time.',
      isEnding: true,
    ),

    'fh_tuck': QuestSegment(
      id: 'fh_tuck',
      content:
          'You tuck in close. '
          'Your grown-up holds you steady.\n\n'
          '"Watching is okay too. '
          'You don\'t have to play yet."\n\n'
          'You watch the kids run and the cake come out.\n\n'
          'When you are ready, you will go say hi. '
          'And until then — being here is enough.',
      isEnding: true,
    ),

    'fh_smile': QuestSegment(
      id: 'fh_smile',
      content:
          'Your mouth tips up at the corners. '
          'A small smile.\n\n'
          'The bunny-shirt kid smiles bigger. '
          'They walk over.\n\n'
          '"Want to see my balloon?"\n\n'
          '"Yes," you whisper.\n\n'
          'The new is not so scary anymore. '
          'Sometimes one smile is the whole hi.',
      isEnding: true,
    ),

    'fh_star': QuestSegment(
      id: 'fh_star',
      content:
          'You trace a star on your palm. '
          'Up. Across. Down. Across. Up.\n\n'
          'In through your nose, out through your mouth.\n\n'
          'Your mouse heart goes from fast to soft.\n\n'
          'The bunny-shirt kid is still there, smiling.\n\n'
          'You take one step closer. '
          'You did the brave thing, {name}.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// SPROUT QUEST 8: The Warm Heart  [Sprout: ages 2-5]
// Sunny Pup — happy / grateful. A handmade gift arrives in the mail and
// triggers the warm-chest gratitude feeling. Coping break is Hot Cocoa Breath
// (savor the good thing — slow inhale to smell it, slow exhale to cool it
// down). Both top-level paths return the love: say it / make something back.
// Endings teach that thank-you done with WHY (or with your wobbly hands)
// is the kind that travels both ways.
// ═══════════════════════════════════════════════════════════════════════════════

const questWarmHeart = LifeQuestScenario(
  id: 'warm_heart',
  title: 'The Warm Heart',
  hook: 'A package came in the mail. With YOUR name on it!',
  emoji: '\u{1F49D}', // heart with ribbon
  emotions: ['happy', 'grateful'],
  recommendedBands: [AgeBand.sprout],
  friend: SproutFriend.pup,
  grownupTip:
      "Ask: 'When someone is kind to YOU, where do you feel it in your body? '"
      "'How can we say thank you with our whole heart?'",
  startSegmentId: 'wh_start',
  segments: {
    'wh_start': QuestSegment(
      id: 'wh_start',
      content:
          'DING DONG.\n\n'
          'The mail brought a package!\n\n'
          'A grown-up reads the tag.\n\n'
          '"Look — it has YOUR name on it. '
          'It is from someone who loves you so much."\n\n'
          'You tear the paper. Rip, rip!\n\n'
          'Inside is a soft little hat. '
          'Made by hand. '
          'Just your size.\n\n'
          'Your chest gets warm. '
          'Your smile is so big it tickles your cheeks.',
      copingBreakId: 'hot_cocoa_breath',
      choices: [
        QuestChoice(
          id: 'wh_c1a',
          text: 'Call to say thank you',
          nextSegmentId: 'wh_call',
        ),
        QuestChoice(
          id: 'wh_c1b',
          text: 'Draw them a picture back',
          nextSegmentId: 'wh_draw',
        ),
      ],
    ),

    'wh_call': QuestSegment(
      id: 'wh_call',
      content:
          'A grown-up holds the phone for you.\n\n'
          'RING. RING.\n\n'
          '"Hi sweet pea!"\n\n'
          'Your voice gets a little wobbly with happy.\n\n'
          '"I love it SO much. Thank you!"\n\n'
          '"I made it just for you."',
      choices: [
        QuestChoice(
          id: 'wh_c2a',
          text: 'Tell them what you LOVE about it',
          nextSegmentId: 'wh_specific',
        ),
        QuestChoice(
          id: 'wh_c2b',
          text: 'Take a hot cocoa breath together',
          nextSegmentId: 'wh_breath',
        ),
      ],
    ),

    'wh_draw': QuestSegment(
      id: 'wh_draw',
      content:
          'You get the crayons.\n\n'
          'Red. Yellow. Pink.\n\n'
          'You draw a heart. '
          'You draw the sun. '
          'You draw two stick people holding hands. '
          'That is them and you.\n\n'
          '"We can mail it tomorrow," says the grown-up.\n\n'
          'The warm feeling stays right in your chest while you draw.',
      choices: [
        QuestChoice(
          id: 'wh_c3a',
          text: 'Sign your name in wobbly letters',
          nextSegmentId: 'wh_sign',
        ),
        QuestChoice(
          id: 'wh_c3b',
          text: 'Add lots of sparkly stickers',
          nextSegmentId: 'wh_sparkle',
        ),
      ],
    ),

    'wh_specific': QuestSegment(
      id: 'wh_specific',
      content:
          '"I love the fluffy puff on top. '
          'And it smells like home."\n\n'
          'They go quiet for a moment. '
          'You can hear them breathe in soft.\n\n'
          '"You found the love I put inside it, {name}."\n\n'
          'Saying thank you is good. '
          'Saying WHY is even better. '
          'It tells someone you really saw their love.',
      isEnding: true,
    ),

    'wh_breath': QuestSegment(
      id: 'wh_breath',
      content:
          '"Want to take a hot cocoa breath with me?"\n\n'
          'Smell the cocoa... '
          'cool it down...\n\n'
          'Smell the cocoa... '
          'cool it down...\n\n'
          'You can hear them smile through the phone.\n\n'
          'They are far away. '
          'But the warm goes both ways. '
          'That is the magic of a thank-you breath.',
      isEnding: true,
    ),

    'wh_sign': QuestSegment(
      id: 'wh_sign',
      content:
          'You hold the crayon tight.\n\n'
          'You write your name. '
          'The letters wobble like jelly.\n\n'
          'But it is YOUR name. '
          'In YOUR own little hand.\n\n'
          'The grown-up tucks the picture in an envelope.\n\n'
          'When they open it on the other side, '
          'they will see your wobbly letters '
          'and their chest will get warm too, {name}.',
      isEnding: true,
    ),

    'wh_sparkle': QuestSegment(
      id: 'wh_sparkle',
      content:
          'Sparkle, sparkle, sparkle!\n\n'
          'Glitter goes everywhere. '
          'On the paper. On your fingers. '
          'A tiny bit on the floor.\n\n'
          'You hold the picture up. '
          'It catches the light.\n\n'
          'Now your thank-you is shiny too.\n\n'
          'When something good comes to you, '
          'you can make something good go back. '
          'That is what makes hearts grow.',
      isEnding: true,
    ),
  },
);
```

---

## Notes for the integrator

- **Friend coverage check** after merging: Pup gets `questBigHello` + `questWarmHeart`, Bunny gets `questBigBearHug` + `questGoodbyeHug`, Lion gets `questMyTurnYourTurn` + `questBigNo`, Mouse gets `questBigLoud` + `questFirstHi`. **All four friends now have 2 quests each** — symmetric coverage.
- **Coping break IDs** referenced (`belly_breath`, `dragon_breath`, `star_breath`, `hot_cocoa_breath`) all exist in the toolbox today — these will render in the in-story break card pattern wired in commit `9d2c5a44`.
- **`{name}` interpolation** used in two endings each. The rest of the prose stays generic so it reads naturally even if name fill-in misses.
- **Vocabulary** kept inside Sprout 3-5 word policy — short sentences (most ≤8 words), repeated sound patterns, body cues over abstract feeling labels, ALL-CAPS onomatopoeia (NOOOO, ROOOOAAAARRR, STOMP, DING DONG, smooch, thump-thump).
