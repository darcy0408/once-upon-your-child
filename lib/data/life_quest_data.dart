// lib/data/life_quest_data.dart
//
// Data model and static content for pre-built Life Quest scenarios.
//
// ignore_for_file: unused_import
import '../theme/age_band_theme.dart' show AgeBand;
// Choose-your-own-adventure stories about real-life situations that
// work WITHOUT any AI generation (no BYOK required).
//
// String interpolation slots:
//   {name}       — character's name (used in dialogue/address by others)
//   {companion}  — companion name, or empty string
//   {pronoun}    — "she"/"he"/"they"
//   {Pronoun}    — "She"/"He"/"They"
//   {possessive} — "her"/"his"/"their"
//
// Companion-conditional text: wrap in «» — stripped entirely when companion
// is empty, markers removed when companion is present.
//   e.g. «{companion} nudges your arm. »

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

/// Sprout-band cloud personas. Each cloud "guides" a family of feeling
/// stories and is the entry point in the Big Feelings section. Older bands
/// don't use clouds — they see a flat quest list.
enum SproutCloud {
  sunny,   // happy / excited
  rain,    // sad
  storm,   // mad / frustrated
  wobbly,  // scared / worried
}

/// A complete pre-built Life Quest scenario with branching paths.
class LifeQuestScenario {
  final String id;
  final String title;
  final String hook; // one-line teaser shown on quest card
  final String emoji;
  /// Which emotions this quest is relevant for (matches badge grid ids).
  final List<String> emotions;
  /// Which age bands this quest is appropriate for.
  final List<AgeBand> recommendedBands;
  /// All segments in this quest, keyed by segment id.
  final Map<String, QuestSegment> segments;
  /// The id of the first segment.
  final String startSegmentId;
  /// Sprout-band cloud persona this quest belongs to. Null for non-Sprout
  /// quests — they appear in a flat list under the older-band "Life Quest" UI.
  final SproutCloud? cloud;
  /// One-sentence prompt for a grown-up to read aloud after the story ends.
  /// Surfaced as a soft callout on the ending screen — not the kid's content.
  final String? grownupTip;

  const LifeQuestScenario({
    required this.id,
    required this.title,
    required this.hook,
    required this.emoji,
    required this.emotions,
    this.recommendedBands = const [AgeBand.adventurer, AgeBand.creator, AgeBand.adolescent],
    required this.segments,
    required this.startSegmentId,
    this.cloud,
    this.grownupTip,
  });
}

/// A single narrative segment in a quest.
class QuestSegment {
  final String id;
  final String content; // story prose with interpolation slots
  final List<QuestChoice> choices; // empty = ending segment
  final bool isEnding;

  /// Optional coping technique to offer alongside this segment. When set,
  /// the quest player renders a "Try it with {name}!" card between the
  /// prose and the choices — tapping launches the animated practice sheet.
  /// Use sparingly: at moments where the character is using a coping skill
  /// in-narrative (e.g. a deep-breath beat), so the offer feels earned.
  /// Value is a CopingTechnique id from coping_techniques.dart.
  final String? copingBreakId;

  const QuestSegment({
    required this.id,
    required this.content,
    this.choices = const [],
    this.isEnding = false,
    this.copingBreakId,
  });
}

/// A choice the reader can make.
class QuestChoice {
  final String id;
  final String text;
  final String nextSegmentId;

  const QuestChoice({
    required this.id,
    required this.text,
    required this.nextSegmentId,
  });
}

/// Applies string interpolation to quest text.
/// Companion-conditional blocks «...» are removed when companion is empty,
/// or unwrapped (markers stripped) when companion is present.
String interpolateQuest(
  String text, {
  required String name,
  String companion = '',
  String pronoun = 'they',
  String pronounCap = 'They',
  String possessive = 'their',
}) {
  var result = text
      .replaceAll('{name}', name)
      .replaceAll('{Pronoun}', pronounCap)
      .replaceAll('{pronoun}', pronoun)
      .replaceAll('{possessive}', possessive);

  if (companion.isEmpty) {
    // Strip companion-conditional blocks entirely
    result = result.replaceAll(RegExp(r'«[^»]*»'), '');
    result = result.replaceAll('{companion}', '');
  } else {
    // Keep content, just remove the markers
    result = result.replaceAll('«', '').replaceAll('»', '');
    result = result.replaceAll('{companion}', companion);
  }

  // Clean up any double spaces left by removal
  return result.replaceAll(RegExp(r'  +'), ' ').trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// Quest library
// ─────────────────────────────────────────────────────────────────────────────

const allLifeQuests = <LifeQuestScenario>[
  // Sprout band (ages 2-5)
  questBigBearHug,
  questBigLoud,
  questMyTurnYourTurn,
  // Explorer band (ages 6-8)
  questWobblyDay,
  questSorryStuck,
  questThreeCrowd,
  questBrokenThing,
  questNotFair,
  questSleepover,
  questMyTurnTalk,
  questSiblingShine,
  questLostPet,
  questMissingGrownup,
  questFirstHardThing,
  // Adventurer + Creator (ages 9-14)
  questTryout,
  questLeftOut,
  questSiblingConflict,
  questBeingTeased,
  // All three bands (ages 9-17)
  questSchoolStress,
  // Creator + Adolescent (ages 12-17)
  questPeerPressure,
  questFamilyStress,
  questFeelingDifferent,
  questLosingFriendship,
  // Creator only (ages 12-14)
  questGroupChat,
  questMyWorkMyWay,
  questMirrorMirror,
  // Adolescent only (ages 15-17)
  questSomeoneNeedsHelp,
  questThingIDidntSay,
  questWhereAreYouGoing,
  questFightAtHome,
  questAfterTheBreakup,
  questScreenshotSpreading,
  questBurningOut,
  questWhoAmIBecoming,
  questFirstPaycheck,
];

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 1: The Empty Seat
// ═══════════════════════════════════════════════════════════════════════════════

const questLeftOut = LifeQuestScenario(
  id: 'left_out',
  title: 'The Empty Seat',
  hook: 'The whole group went somewhere. Nobody told you.',
  emoji: '\u{1F494}',
  emotions: ['sad', 'worried', 'angry', 'embarrassed'],
  recommendedBands: [AgeBand.adventurer, AgeBand.creator],
  startSegmentId: 'lo_start',
  segments: {
    'lo_start': QuestSegment(
      id: 'lo_start',
      content:
          'The cafeteria smells like Tuesday — burned pizza and cold milk. '
          'You spot your usual table by habit, the same way you always do, '
          'and then you stop dead in the lunch line.\n\n'
          'It\'s packed. Two extra chairs wedged in, shoulder-to-shoulder, '
          'phones trading hands, everyone leaning in to see something bright '
          'on someone\'s screen. A water slide. A group selfie with matching '
          'wet hair and sunburned noses. The waterpark. The whole weekend, '
          'happening in someone\'s camera roll.\n\n'
          'You weren\'t there.\n\n'
          'Your stomach drops the way it does when you miss a stair in the '
          'dark — sudden, hollow, instant. You stand in the lunch line holding '
          'your tray while your brain catches up to what your gut already '
          'knows: nobody told you.\n\n'
          '«{companion} appears at your shoulder with their lunch. '
          '"You okay? You look like you\'ve seen a ghost."»\n\n'
          'You don\'t answer yet. You\'re still working out whether '
          'this is a mistake or something else entirely.',
      choices: [
        QuestChoice(
          id: 'lo_c1a',
          text: 'Slide into the empty chair — act like everything\'s normal',
          nextSegmentId: 'lo_sit',
        ),
        QuestChoice(
          id: 'lo_c1b',
          text: 'Find a seat by the windows — eat alone',
          nextSegmentId: 'lo_alone',
        ),
        QuestChoice(
          id: 'lo_c1c',
          text: 'Walk straight up and ask what you missed',
          nextSegmentId: 'lo_confront',
        ),
      ],
    ),

    'lo_sit': QuestSegment(
      id: 'lo_sit',
      content:
          'You slide into the only open gap — a folding chair wedged at '
          'the end of the table. Someone says hey. You say hey back. The '
          'conversation keeps rolling without a pause: the slide that was '
          'terrifying, the nachos that were overpriced, the sunburn Jayden '
          'got on his ears. Nobody asks what you did this weekend.\n\n'
          'Being invisible in a room full of people you know is a specific '
          'kind of awful.\n\n'
          'You pick at your food. Your fork scrapes the tray. Your throat '
          'feels tight in a way that makes swallowing complicated. Inside '
          'you\'re cycling through two thoughts on a loop: '
          'Maybe they didn\'t mean it — and — But nobody told me.\n\n'
          '«{companion} catches your eye from across the table '
          'and raises an eyebrow. A silent are you okay?»\n\n'
          'The conversation is still going. Jayden\'s showing the '
          'sunburned-ear close-up and everyone\'s groaning and laughing. '
          'You could jump in. You could say something honest. You could '
          'pull out your phone and pretend something more interesting '
          'is happening somewhere else.',
      choices: [
        QuestChoice(
          id: 'lo_c2a',
          text: 'Jump in — ask about the slide',
          nextSegmentId: 'lo_join_convo',
        ),
        QuestChoice(
          id: 'lo_c2b',
          text: 'Text someone under the table',
          nextSegmentId: 'lo_text',
        ),
        QuestChoice(
          id: 'lo_c2c',
          text: '"Sounds fun. Wish I\'d known."',
          nextSegmentId: 'lo_honest',
        ),
      ],
    ),

    'lo_alone': QuestSegment(
      id: 'lo_alone',
      content:
          'You walk to the far end of the cafeteria, near the windows, '
          'and sit down at an empty table. Nobody follows. Nobody calls '
          'your name.\n\n'
          'The food doesn\'t taste like anything. Outside the window '
          'the parking lot is just the parking lot. You keep your eyes '
          'on the middle distance — not focused on anything, not meeting '
          'any faces — and breathe through the hot feeling that\'s '
          'collecting behind your eyes.\n\n'
          'You\'re not going to cry here. You\'re just going to eat '
          'your lunch and not give this moment any more than it already '
          'has.\n\n'
          '«{companion} sees you from across the room and comes over '
          'without being asked, setting their tray across from yours. '
          'Nothing said. Just there.»\n\n'
          'A kid from your science class — Alex — stops at the edge of '
          'the table. "Mind if I sit? My usual table got weird today." '
          'You gesture at the open chair. Alex sits down and immediately '
          'starts explaining the thing that happened in lab last period. '
          'The knot in your chest loosens, just slightly.',
      choices: [
        QuestChoice(
          id: 'lo_c3a',
          text: 'Tell Alex what happened',
          nextSegmentId: 'lo_tell_alex',
        ),
        QuestChoice(
          id: 'lo_c3b',
          text: 'Keep it to yourself — just enjoy the company',
          nextSegmentId: 'lo_enjoy_alex',
        ),
      ],
    ),

    'lo_confront': QuestSegment(
      id: 'lo_confront',
      content:
          'You walk straight up to the table. The laughter cuts out '
          'faster than a light switch.\n\n'
          '"You all went to the waterpark this weekend?"\n\n'
          'Maya shifts in her seat. Jayden looks at the table. Riley '
          'says, "Yeah — it was kind of last minute." The silence '
          'stretches. Someone puts down their phone.\n\n'
          '"There was only room for five in my mom\'s car," Jayden '
          'finally says.\n\n'
          'You stand there with your lunch tray, feeling every single '
          'pair of eyes at that table. Your face is hot — you can feel '
          'the heat in your cheeks, your ears, down the back of your '
          'neck. You have no idea what your expression is doing.\n\n'
          'There\'s a real answer here and there isn\'t one. '
          '"Last minute" doesn\'t explain why no one sent a text. '
          '"Five in the car" doesn\'t explain the group chat with '
          'twenty-three messages since Saturday and not one of them '
          'was hey, sorry you can\'t come.\n\n'
          'You have to decide what to do with the next thirty seconds.',
      choices: [
        QuestChoice(
          id: 'lo_c4a',
          text: '"I just wish someone had told me."',
          nextSegmentId: 'lo_calm_honest',
        ),
        QuestChoice(
          id: 'lo_c4b',
          text: '"Whatever. Doesn\'t matter." — walk away',
          nextSegmentId: 'lo_walk_away',
        ),
        QuestChoice(
          id: 'lo_c4c',
          text: '"Five in the car. Really?"',
          nextSegmentId: 'lo_push_back',
        ),
      ],
    ),

    // ── Endings from lo_sit ──────────────────────────────────────────────────

    'lo_join_convo': QuestSegment(
      id: 'lo_join_convo',
      content:
          '"Was the big slide actually scary?" you ask.\n\n'
          'Maya turns — surprised, then relieved to have a normal '
          'question to answer. "Oh my GOD. I screamed the entire way '
          'down." She holds out her phone. The video is her, both hands '
          'up, making a sound that isn\'t quite human. Jayden\'s dying '
          'in the background.\n\n'
          'You laugh. Actually laugh.\n\n'
          'It still stings, sitting there. You weren\'t in that video. '
          'You weren\'t at the park. That part is true and it doesn\'t '
          'un-true itself just because Maya\'s impression of the slide '
          'is sending the whole table into chaos. But you\'re here now, '
          'in this moment, and that\'s real too.\n\n'
          '«{companion} catches your eye and gives you a small nod '
          'from across the table.»\n\n'
          'Later, walking to your next class, Maya falls into step '
          'beside you. "Hey — next time, I\'m making the group chat. '
          'Promise." She looks like she means it.\n\n'
          'You nod. The tight feeling has loosened to something '
          'you can carry. Your phone buzzes. Someone has already '
          'added you. The notification blinks, steady and quiet.',
      isEnding: true,
    ),

    'lo_text': QuestSegment(
      id: 'lo_text',
      content:
          'Under the table, you open your messages and text your cousin: '
          'Having the worst lunch. The cousin writes back immediately — '
          'a string of memes, increasingly unhinged, each one slightly '
          'less appropriate than the last.\n\n'
          'You try not to laugh. You fail.\n\n'
          'Jayden looks over. "What?" You flip your phone around and '
          'show him. His face does something complicated, then he starts '
          'losing it. He shows it to Maya. Maya shows it to Riley. '
          'The waterpark conversation evaporates.\n\n'
          'For a few minutes, you\'re the one who brought something '
          'to the table. Literally.\n\n'
          '«Later, {companion} walks out with you. '
          '"Quick thinking back there," {companion} says.»\n\n'
          'You don\'t know if it counts as handling it. The sting is '
          'still there — it didn\'t go anywhere. But sitting in the '
          'quiet hallway after the bell, you realize: you changed the '
          'room. You showed up with something when you had every '
          'reason not to.\n\n'
          'Your footsteps echo down the empty hall. Outside the '
          'windows, the sky is doing something bright and careless.',
      isEnding: true,
    ),

    'lo_honest': QuestSegment(
      id: 'lo_honest',
      content:
          '"Sounds fun," you say, carefully. "Wish someone had told me."\n\n'
          'The words land like a stone in still water. Rings spreading.\n\n'
          'Maya\'s face changes. "Oh — wait. I thought Jayden '
          'invited you." She turns to Jayden. His eyebrows go up. '
          '"I thought YOU did." They stare at each other.\n\n'
          'And then the answer is just there, sitting right on '
          'the surface.\n\n'
          'Nobody meant to leave you out. Nobody was conspiring. '
          'It fell through a crack in the middle, the way things do '
          'when everyone assumes someone else is handling it.\n\n'
          '"Next time I\'m making the group chat," Maya says, '
          'already reaching for her phone.\n\n'
          '«{companion} squeezes your arm once, under the table.»\n\n'
          'You sit down. Someone passes the chips. The tight fist '
          'behind your sternum unclenches, slowly, one finger at a '
          'time. It still hurt. The weekend still happened without you. '
          'But saying the real thing, calmly, turned out to be '
          'enough to fix it.\n\n'
          'The chips are salt and vinegar. Your favorite.',
      isEnding: true,
    ),

    // ── Endings from lo_alone ────────────────────────────────────────────────

    'lo_tell_alex': QuestSegment(
      id: 'lo_tell_alex',
      content:
          'You look at your sandwich, not at Alex. "My whole friend '
          'group went to the waterpark this weekend and nobody told me."\n\n'
          'Alex is quiet. You wait for the advice — have you tried '
          'talking to them, maybe they just forgot — but it doesn\'t '
          'come.\n\n'
          '"That sucks," Alex says finally. "Like, genuinely. '
          'That\'s a really sucky feeling."\n\n'
          'That\'s it. No solution. No silver lining. Just someone '
          'saying yeah, that\'s bad, and meaning it.\n\n'
          'Something releases in your chest.\n\n'
          '«{companion} texts you from across the school ten minutes '
          'later: You okay? You send back a thumbs up. It\'s enough.»\n\n'
          'You and Alex talk about other things after — the science '
          'project, the movie that\'s apparently terrible but also '
          'amazing, the inexplicable cafeteria phenomenon of mystery '
          'meat Thursdays. By the time the bell rings, the hollow '
          'thing in your chest is smaller. Not gone. Smaller.\n\n'
          'You leave the table feeling lighter than when you sat down.',
      isEnding: true,
    ),

    'lo_enjoy_alex': QuestSegment(
      id: 'lo_enjoy_alex',
      content:
          'You decide not to bring it up. Today the waterpark doesn\'t '
          'exist. Just this table, this window, Alex\'s very detailed '
          'description of how the frog escaped from the science lab '
          'and why Mr. Torres\'s reaction violated at least three '
          'laws of physics.\n\n'
          '"He knocked over the entire terrarium," Alex says, '
          'demonstrating with both hands. "He panicked."\n\n'
          'You snort-laugh so hard you have to put down your juice.\n\n'
          '«{companion} appears at the end of the table with their '
          'tray. "What did I miss?" "Everything," you say, and mean it.»\n\n'
          'By the bell, your cheeks hurt from laughing. You and Alex '
          'walk to class together, still picking apart the physics of '
          'the frog situation. The hollow feeling from earlier is still '
          'there, somewhere in the background — but right now it\'s '
          'very quiet, like a radio two rooms away.\n\n'
          'You realize, walking through the door to your next class, '
          'that this turned out to be one of the better lunches '
          'you\'ve had all month. You didn\'t plan it. '
          'It just happened.',
      isEnding: true,
    ),

    // ── Endings from lo_confront ─────────────────────────────────────────────

    'lo_calm_honest': QuestSegment(
      id: 'lo_calm_honest',
      content:
          '"I just wish someone had let me know." You keep your voice '
          'level. It wants to wobble. You don\'t let it.\n\n'
          'Jayden looks at the table. Maya looks at Jayden. The silence '
          'has a different quality now — not tense, just thinking.\n\n'
          '"You\'re right," Maya says. "That was crappy. I\'m sorry."\n\n'
          'Jayden nods. "Yeah. My bad. For real."\n\n'
          'It doesn\'t erase the weekend. There\'s no version of this '
          'conversation that puts you in the waterpark video with everyone '
          'else. But something has shifted — you said the real thing, '
          'the true thing, without making it a weapon, and the people '
          'on the other side actually heard you.\n\n'
          '«{companion} catches your eye across the table '
          'and gives you the smallest nod.»\n\n'
          'You sit down. Someone makes room. The table rearranges itself '
          'around you the way it always has, and the conversation moves '
          'on, and you eat your lunch, and outside the cafeteria windows '
          'the sky is the same grey it was twenty minutes ago.\n\n'
          'But your hands have stopped shaking.',
      isEnding: true,
    ),

    'lo_walk_away': QuestSegment(
      id: 'lo_walk_away',
      content:
          '"Whatever. Doesn\'t matter." You turn and go, tray in both '
          'hands, shoulders straight, looking at the floor so you '
          'don\'t have to look at anyone.\n\n'
          'It does matter. You both know it.\n\n'
          'You find a table near the windows and eat alone. The anger '
          'runs hot for a while, burning clean, and then it fades into '
          'something heavier and harder to name. You eat without '
          'tasting anything.\n\n'
          '«Halfway through lunch, {companion} slides their tray '
          'across from you and sits down without asking. Neither of '
          'you says anything for a minute.»\n\n'
          'Later that afternoon, your phone buzzes. Maya: '
          'Hey, are you okay? I feel really bad about today.\n\n'
          'You read it once. You read it again. The words are small '
          'on the screen but they\'re something — she knows something '
          'went wrong and cared enough to say so.\n\n'
          'You sit with the message for a long time, '
          'watching the cursor blink.',
      choices: [
        QuestChoice(
          id: 'lo_c5a',
          text: 'Reply honestly: "Yeah, that hurt."',
          nextSegmentId: 'lo_reply_honest',
        ),
        QuestChoice(
          id: 'lo_c5b',
          text: 'Leave it on read for now',
          nextSegmentId: 'lo_leave_read',
        ),
      ],
    ),

    'lo_reply_honest': QuestSegment(
      id: 'lo_reply_honest',
      content:
          'You type: Yeah, that hurt.\n\n'
          'Three dots. They disappear. Then: I\'m really sorry. I '
          'genuinely thought Jayden had told you. That\'s not an excuse — '
          'I should have checked. Do you want to hang out this weekend? '
          'Just us?\n\n'
          'You read it twice.\n\n'
          'It doesn\'t undo the weekend. It doesn\'t undo the walk-away '
          'at lunch or the sitting alone or the way the tray felt '
          'too heavy. But it opens something — a door that swings in, '
          'not out.\n\n'
          'You type: Yeah. That would be good.\n\n'
          '«{companion} texts thirty seconds later: Did you two sort it '
          'out? You send back a small yeah.»\n\n'
          'You put your phone face-down on your bed and stare at '
          'the ceiling. The tight feeling in your chest loosens — not '
          'all at once, not completely. But enough that you can '
          'breathe around it. Enough that you can reach over and '
          'turn out the light and actually sleep.',
      isEnding: true,
    ),

    'lo_leave_read': QuestSegment(
      id: 'lo_leave_read',
      content:
          'You put the phone face-down.\n\n'
          'Not to be cruel. Just because you don\'t have the words yet, '
          'and sending the wrong words feels worse than sending nothing. '
          'You lie on your bed and stare at the ceiling and let the '
          'feeling be exactly what it is for a while — big, tangled, '
          'a little bit like grief.\n\n'
          '«{companion} texts an hour later. You don\'t open that '
          'either. Not yet.»\n\n'
          'In the morning you wake up and the feeling is smaller. '
          'Still there, just smaller. More like something you\'re '
          'carrying than something that\'s carrying you.\n\n'
          'You get dressed. You go to school. When you walk into the '
          'cafeteria, Maya is already at the table, and she looks up '
          'and finds your face across the room and does this thing '
          'with her mouth — not quite a smile, not quite an apology, '
          'just: I see you.\n\n'
          'You sit down. Nobody says anything about it. The conversation '
          'runs alongside you, and outside the window the sky has '
          'finally gone blue.\n\n'
          'It\'s not fixed. But it\'s enough for right now.',
      isEnding: true,
    ),

    'lo_push_back': QuestSegment(
      id: 'lo_push_back',
      content:
          '"Five in the car." You say it back like a question — except '
          'it\'s not really a question and everyone can hear that.\n\n'
          'Jayden\'s jaw tightens. "It was last minute. My mom '
          'organized it."\n\n'
          '"But someone could have texted."\n\n'
          'The table has gone very quiet. Maya is looking at her phone '
          'like it has suddenly become the most interesting object '
          'in the room.\n\n'
          'You can feel the moment balancing on its edge. One more '
          'word in either direction and this tips into a real fight — '
          'the kind that gets remembered. You have the option to '
          'pull it back. You also have the option to push.\n\n'
          'What do you want the next five minutes to look like?',
      choices: [
        QuestChoice(
          id: 'lo_c6a',
          text: 'Pull it back: "Sorry. I\'m just hurt."',
          nextSegmentId: 'lo_deescalate',
        ),
        QuestChoice(
          id: 'lo_c6b',
          text: 'Double down: "You could have texted."',
          nextSegmentId: 'lo_double_down',
        ),
      ],
    ),

    'lo_deescalate': QuestSegment(
      id: 'lo_deescalate',
      content:
          'You take a breath. The slow kind — the kind you actually '
          'have to work for, pulling the air all the way in.\n\n'
          '"Sorry. I\'m just hurt. I get that it was last minute."\n\n'
          'The tension breaks. Not shatters — just softens. Jayden\'s '
          'shoulders come down half an inch. "Yeah. We\'ll figure '
          'out a better system."\n\n'
          'Maya nods. "Group chat. I\'m making it today."\n\n'
          '«Beside you, {companion} lets out a slow breath too.»\n\n'
          'You sit down at the table. Someone passes the chips. '
          'The conversation resumes, quieter and more careful than '
          'before, and you eat your lunch, and the anger is still '
          'there — a live ember somewhere in your chest — but it\'s '
          'not in control of anything.\n\n'
          'The cafeteria smells like Tuesday. Burned pizza, cold milk. '
          'The same as always.\n\n'
          'You\'re still here. That\'s something you chose.',
      isEnding: true,
    ),

    'lo_double_down': QuestSegment(
      id: 'lo_double_down',
      content:
          '"You could have texted." Your voice is flat.\n\n'
          'Jayden unfolds his arms. "Okay, {name}. Sorry we didn\'t '
          'plan our whole weekend around your schedule." The words '
          'land like a slap. Someone at the table makes a small sound. '
          'Maya says "okay, can we just—" but you\'re already gone, '
          'tray in hand, walking toward the far wall with your jaw '
          'locked and your eyes fixed on nothing.\n\n'
          'You sit alone. The anger runs hot and then burns out, and '
          'what\'s underneath is worse — tired, heavy, hollow.\n\n'
          'You were right. Nobody invited you and nobody explained why, '
          'and that was bad and real and worth being upset about.\n\n'
          'But you pushed past the point where any of it could be fixed '
          'in the moment, and now Jayden\'s words are stuck in your '
          'head alongside all the others.\n\n'
          '«{companion} finds you by the door as the bell rings. '
          'Neither of you says anything.»\n\n'
          'Tomorrow. You\'ll figure out tomorrow.\n\n'
          'Outside, the sky is going grey at the edges.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 2: The Dare
// ═══════════════════════════════════════════════════════════════════════════════

const questPeerPressure = LifeQuestScenario(
  id: 'peer_pressure',
  title: 'The Dare',
  hook: 'The can is in your hand. So is the choice.',
  emoji: '\u{1F62C}',
  emotions: ['worried', 'frustrated', 'embarrassed'],
  recommendedBands: [AgeBand.creator, AgeBand.adolescent],
  startSegmentId: 'pp_start',
  segments: {
    'pp_start': QuestSegment(
      id: 'pp_start',
      content:
          'Tuesday afternoon at the creek path behind the park. The air '
          'smells like cut grass and something electrical — the way it '
          'smells right before a thunderstorm, or right before '
          'something you\'re not sure about.\n\n'
          'Tyler pulls a spray can from his backpack. Red. The kind '
          'for writing on things. He shakes it, and the marble inside '
          'rattles.\n\n'
          '"Who wants to tag the bridge?"\n\n'
          'Some kids look at each other with that particular grin — '
          'half nervous, half daring each other to say no. Riley '
          'grabs the can first, shakes it the way she\'s seen it done '
          'in movies, and sprays a lopsided smiley face on the concrete '
          'arch. It\'s smaller than you expected. More permanent.\n\n'
          'Everyone cheers. Tyler takes the can back and holds it '
          'out toward you. "Your turn."\n\n'
          '«{companion} is somewhere behind you — you can\'t see '
          'their face without turning around, and you don\'t want '
          'to turn around right now.»\n\n'
          'The can is red. The bridge is grey. The sun is warm on '
          'the back of your neck. Everyone is watching.',
      choices: [
        QuestChoice(
          id: 'pp_c1a',
          text: '"Nah, I\'m good."',
          nextSegmentId: 'pp_decline',
        ),
        QuestChoice(
          id: 'pp_c1b',
          text: 'Take it — just a small one',
          nextSegmentId: 'pp_take',
        ),
        QuestChoice(
          id: 'pp_c1c',
          text: 'Deflect with a joke',
          nextSegmentId: 'pp_joke',
        ),
      ],
    ),

    'pp_decline': QuestSegment(
      id: 'pp_decline',
      content:
          '"Nah, I\'m good."\n\n'
          'Tyler raises one eyebrow. The can is still extended toward '
          'you, arm straight, like the offer doesn\'t expire. '
          '"Seriously? It\'s just paint."\n\n'
          '"Yep." You keep your voice flat. Not aggressive. Just done.\n\n'
          'Riley says "don\'t be lame" in a sing-song that isn\'t '
          'quite mean and isn\'t quite friendly.\n\n'
          'The word lands. You feel it — that specific sting of lame, '
          'which isn\'t really about the paint and everyone knows it. '
          'It\'s about whether you\'re someone who does things or '
          'someone who watches.\n\n'
          '«{companion} shifts slightly behind you. Not away. '
          'Just watching.»\n\n'
          'The group is balanced on a pause. Tyler\'s still holding '
          'the can. Riley\'s waiting to see which way this goes. '
          'The creek is running at the bottom of the bank and the '
          'birds don\'t care about any of this.\n\n'
          'What do you do with this next moment?',
      choices: [
        QuestChoice(
          id: 'pp_c2a',
          text: '"Call me lame. I don\'t care."',
          nextSegmentId: 'pp_stand_firm',
        ),
        QuestChoice(
          id: 'pp_c2b',
          text: '"My mom just texted. Gotta go." — leave',
          nextSegmentId: 'pp_excuse',
        ),
      ],
    ),

    'pp_take': QuestSegment(
      id: 'pp_take',
      content:
          'You take the can. It\'s heavier than it looks — a solid '
          'weight in your palm. You shake it once, hear the ball '
          'bearing rattle. Everyone is quiet in that particular way '
          'of a crowd holding its breath.\n\n'
          'You press the nozzle. A star comes out, small and red, '
          'slightly lopsided, done in about three seconds.\n\n'
          'Everyone cheers.\n\n'
          'For exactly three seconds, you feel the fizz of it — '
          'the approval, the laughing faces, the way Riley says yeah! '
          'like you did something real. Three seconds is fast. Then '
          'you step back and look at what you did.\n\n'
          'The star is on a city bridge. It doesn\'t wash off. And '
          'there is, now that you\'re actually looking, a security '
          'camera on the light post twenty feet away. It\'s pointed '
          'right at the bridge.\n\n'
          'Your stomach drops.\n\n'
          '«{companion} appears at your shoulder and says, low: '
          '"Is that a camera?"»\n\n'
          'The good feeling curdles into something cold. Nobody else '
          'has noticed yet. You have about thirty seconds.',
      choices: [
        QuestChoice(
          id: 'pp_c3a',
          text: '"Guys — there\'s a camera." Warn everyone',
          nextSegmentId: 'pp_warn',
        ),
        QuestChoice(
          id: 'pp_c3b',
          text: 'Set the can down and back away quietly',
          nextSegmentId: 'pp_step_back',
        ),
      ],
    ),

    'pp_joke': QuestSegment(
      id: 'pp_joke',
      content:
          '"I can\'t even draw on paper," you say, and do your '
          'best smile. "You don\'t want me on the bridge. '
          'I\'d make it worse."\n\n'
          'Some kids laugh. The real kind — surprised-out-of-them. '
          'Tyler grins and takes the can back. "Fair enough." The '
          'focus shifts to someone else, then someone else after '
          'that, and the moment where all the attention was on '
          'you quietly closes itself.\n\n'
          'You drift to the edge of the group.\n\n'
          '«{companion} slides over to stand next to you, close '
          'enough that your shoulders are almost touching. '
          '"Nice one," {companion} says, just under the noise.»\n\n'
          'You didn\'t say no. You didn\'t say yes either. The joke '
          'slid between the two like a letter under a door.\n\n'
          'Now the question is what you do next — stay and watch, '
          'or find your exit before this becomes something you have '
          'to explain later. The creek runs below. A cardinal lands '
          'on the railing and takes off again.',
      choices: [
        QuestChoice(
          id: 'pp_c4a',
          text: 'Stick around and watch',
          nextSegmentId: 'pp_watch',
        ),
        QuestChoice(
          id: 'pp_c4b',
          text: 'Make your exit — head home',
          nextSegmentId: 'pp_leave_clean',
        ),
      ],
    ),

    // ── Endings ──────────────────────────────────────────────────────────────

    'pp_stand_firm': QuestSegment(
      id: 'pp_stand_firm',
      content:
          '"Call me lame. I really don\'t care."\n\n'
          'You say it even. Not loud. Not showing your teeth. '
          'Just a statement of fact.\n\n'
          'Tyler blinks. He puts the can down by his side. Something '
          'in the air shifts — not dramatic, not a movie moment, '
          'just a deflation. A shrug. "Whatever, man." And like '
          'that, the focus moves somewhere else.\n\n'
          '«{companion} falls into step beside you as the group '
          'rearranges. "You know what that was?" {companion} says. '
          '"A spine. You grew one."»\n\n'
          'You laugh. It\'s a little shaky — your hands are still '
          'doing that faint tremor things do after adrenaline — '
          'but it\'s a real laugh.\n\n'
          'Walking home, the day starts going gold at the edges. '
          'You replay the moment a few times, the way you do when '
          'something actually went the way you wanted. Your voice '
          'came out the way you meant it to. Your feet stayed '
          'where you put them.\n\n'
          'The next day at school, Riley catches up to you in the '
          'hall. "I kind of wish I hadn\'t done it either," she says, '
          'not quite looking at you. You don\'t say anything. '
          'You just nod.',
      isEnding: true,
    ),

    'pp_excuse': QuestSegment(
      id: 'pp_excuse',
      content:
          'You pull out your phone with the practiced efficiency of '
          'someone who has done this before — the quick glance down, '
          'the slight look of obligation.\n\n'
          '"My mom just texted. I have to go."\n\n'
          'Nobody argues with a mom text. It\'s one of the immutable '
          'laws of middle school. Tyler waves you off. You wave back, '
          'already walking.\n\n'
          'The path curves behind the trees and you\'re alone with '
          'the sound of the creek and your own footsteps and the '
          'sky going orange above the park.\n\n'
          'Relief settles over you like a dropped coat.\n\n'
          '«{companion} catches up on the corner, slightly out of '
          'breath. "Good call," {companion} says. That\'s all. '
          'Good call.»\n\n'
          'You think about it on the walk home — the exit, whether '
          'it was right, whether the mom-text excuse was worse than '
          'just saying no outright. You land somewhere in the middle: '
          'it worked. The instinct was right. The execution was yours.\n\n'
          'The street is quiet. Your house is three blocks away. '
          'You count your footsteps and don\'t think about the bridge.',
      isEnding: true,
    ),

    'pp_warn': QuestSegment(
      id: 'pp_warn',
      content:
          '"Guys." You keep your voice flat. "There\'s a camera."\n\n'
          'Everyone stops. Heads turn. It takes a moment to find it — '
          'the light post, the little black dome angled down at the '
          'bridge. When Riley sees it, she swears and steps back. '
          'Tyler stuffs the can into his bag, fast.\n\n'
          'The group scatters without a word. No countdown, no '
          'dramatic exit — just everyone deciding at the same moment '
          'that they have somewhere else to be. In forty-five seconds '
          'the bridge is empty.\n\n'
          'You walk home alone.\n\n'
          'The red star is still there on the arch. You put it there. '
          'That part isn\'t going anywhere.\n\n'
          '«{companion} texts you from somewhere on the path: '
          'that was the right thing. You read it twice and don\'t '
          'know how to respond, so you walk.»\n\n'
          'At home, you sit on the edge of your bed and let the '
          'afternoon land on you all at once. You made a mistake — '
          'quick, small, painted red on a bridge. And then you made '
          'a better choice right after.\n\n'
          'Both of those things are true. You let them be true.',
      isEnding: true,
    ),

    'pp_step_back': QuestSegment(
      id: 'pp_step_back',
      content:
          'You set the can down on the concrete railing. No '
          'announcement. No drama. Just a can on a railing.\n\n'
          'Nobody notices — they\'re too busy cheering for whatever '
          'Tyler just tagged. You drift backward, one step, two, '
          'until you\'re at the edge of the group, and then a little '
          'further, and then you\'re walking down the path toward '
          'home without anyone calling after you.\n\n'
          'The star is on the bridge. You can\'t un-spray it. '
          'But you can stop. You stopped.\n\n'
          '«{companion} catches up to you at the first fork. '
          'Neither of you says anything about the bridge. Instead '
          '{companion} says, "Want to get a slushie?" '
          'and you say yes.»\n\n'
          'You think, walking, about how fast it happened — the can '
          'in your hand before you\'d decided anything, the star '
          'there before you\'d thought it through. Pressure doesn\'t '
          'always announce itself. Sometimes it feels like fun, and '
          'you don\'t notice the weight until you\'re already holding '
          'something you didn\'t mean to pick up.\n\n'
          'You get a blue slushie. It\'s very cold. The evening is warm.',
      isEnding: true,
    ),

    'pp_watch': QuestSegment(
      id: 'pp_watch',
      content:
          'You stay.\n\n'
          'The group keeps going — another tag, and another, until '
          'the underside of the bridge looks like every surface in a '
          'city you\'ve seen in movies. Up close it\'s messier than '
          'it looks in pictures. The paint drips. Someone\'s tag is '
          'spelled wrong.\n\n'
          '«{companion} stands beside you, arms folded. '
          '"Are we just... watching?" {companion} says. '
          '"Yeah," you say. "Yeah, we are."»\n\n'
          'When they\'re done, Tyler high-fives everyone. You do a '
          'modified version — more of a hand-touch, less of '
          'a commitment.\n\n'
          'Walking home, your brain keeps returning to one question: '
          'Is watching the same as participating? You didn\'t touch '
          'the can. You also didn\'t leave. You kept your hands clean '
          'and stayed around to see what happened.\n\n'
          'You don\'t have a clean answer by the time you reach your '
          'front door. The question is still there the next morning — '
          'smaller, but not gone. A pebble in your shoe you haven\'t '
          'decided to shake out yet.',
      isEnding: true,
    ),

    'pp_leave_clean': QuestSegment(
      id: 'pp_leave_clean',
      content:
          '"Catch you later." You say it easily, the casual wave of '
          'someone with a destination.\n\n'
          'And then you walk.\n\n'
          'Nobody calls after you. Nobody says wait up. You just '
          'leave, and the path curves and the park is behind you and '
          'you\'re in the ordinary street with its ordinary houses and '
          'ordinary cars, and it\'s so quiet after the buzz of the '
          'group that you take a whole breath and hold it.\n\n'
          '«{companion} catches up at the corner and bumps '
          'your shoulder. "That was smooth," {companion} says.»\n\n'
          'You get home, drop your bag, sit on the kitchen floor '
          'for a second for no particular reason. The slant of '
          'afternoon light comes through the window at an angle '
          'that makes everything look like a photograph.\n\n'
          'You didn\'t make a big declaration. You didn\'t start '
          'a thing. You just declined, made a small joke, and '
          'walked away, and now you\'re here in your kitchen '
          'with clean hands and the whole evening ahead of you.\n\n'
          'Tomorrow, someone might have a story about the bridge. '
          'Your story is different. It goes like this: you went '
          'to the park and then you came home.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 3: The Big Test
// ═══════════════════════════════════════════════════════════════════════════════

const questSchoolStress = LifeQuestScenario(
  id: 'school_stress',
  title: 'The Big Test',
  hook: 'It\'s 9 PM. The test is at 8 AM.',
  emoji: '\u{1F4DA}',
  emotions: ['worried', 'frustrated', 'sad'],
  startSegmentId: 'ss_start',
  segments: {
    'ss_start': QuestSegment(
      id: 'ss_start',
      content:
          '8:47 PM.\n\n'
          'The test is in eleven hours and the textbook has been open '
          'on your desk for the past forty minutes, but the words '
          'haven\'t moved from the page to your brain. Fractions '
          'go blurry in the middle. Word problems read like a foreign '
          'language that uses familiar letters. Your stomach is doing '
          'that clenching thing it does when something important is '
          'tomorrow and you are nowhere near ready.\n\n'
          'The cursor blinks in the school portal. Your grade in math: '
          '71%. Barely passing.\n\n'
          'Your phone lights up — the group chat, everyone apparently '
          'fine, apparently not drowning in this exact panic. Or maybe '
          'they are and they\'re just not saying it.\n\n'
          '«{companion} sent a voice memo thirty minutes ago '
          'that you still haven\'t opened.»\n\n'
          'The clock on your wall ticks. It has always ticked. '
          'Right now it sounds extremely loud.\n\n'
          'You\'ve got tonight. Just tonight. '
          'The question is how you use it.',
      choices: [
        QuestChoice(
          id: 'ss_c1a',
          text: 'Put the phone down and power through',
          nextSegmentId: 'ss_power',
        ),
        QuestChoice(
          id: 'ss_c1b',
          text: 'Go ask a parent for help',
          nextSegmentId: 'ss_ask_parent',
        ),
        QuestChoice(
          id: 'ss_c1c',
          text: 'Text a friend — study together',
          nextSegmentId: 'ss_text_friend',
        ),
      ],
    ),

    'ss_power': QuestSegment(
      id: 'ss_power',
      content:
          'You flip your phone face-down. The chat goes silent. '
          'You stare at the textbook.\n\n'
          'Ten minutes pass. Then fifteen. The fraction section slowly '
          'starts making a kind of sense — not confident sense, but '
          'I\'ve seen this before sense, the recognition that\'s the '
          'first cousin of understanding. You work through four '
          'problems and only get one actually wrong.\n\n'
          'Then you hit the word problems.\n\n'
          'They\'re written in a language where every sentence requires '
          'you to translate three times before you can start solving. '
          'Your pencil scratches and stops. Scratches and stops. '
          'Your eyes are getting heavy. The room is warm. Your brain '
          'has that specific texture of wrung-out cloth.\n\n'
          '«{companion} texts: studying? You send back a single '
          'period. {companion} sends: same.»\n\n'
          'You could take a break. You could skip the hard stuff '
          'entirely. Both feel like giving up — but maybe one '
          'of them is actually a strategy.',
      choices: [
        QuestChoice(
          id: 'ss_c2a',
          text: 'Take a 10-minute break, then come back',
          nextSegmentId: 'ss_break',
        ),
        QuestChoice(
          id: 'ss_c2b',
          text: 'Skip the hard stuff — focus on what you know',
          nextSegmentId: 'ss_focus_strengths',
        ),
      ],
    ),

    'ss_ask_parent': QuestSegment(
      id: 'ss_ask_parent',
      content:
          'You close the textbook and walk to the kitchen.\n\n'
          'Your mom is cleaning up after dinner, shoulders tight with '
          'her own kind of tired. You stand in the doorway.\n\n'
          '"Can you help me? I\'m kind of freaking out about tomorrow."\n\n'
          'She turns around. Looks at you. Dries her hands.\n\n'
          '"Show me what you\'ve got."\n\n'
          'You sit at the kitchen table together. She doesn\'t do it '
          'the way your teacher does — she uses the leftover dinner '
          'as props. If there are sixteen pieces of pasta and you eat '
          'three-quarters of them, how many pieces are left? She makes '
          'you count actual pasta.\n\n'
          'It\'s slightly embarrassing and it completely works.\n\n'
          '«Later you text {companion}: my mom used actual pasta. '
          '{companion}: did it help? You: yeah actually.»\n\n'
          'By 9:30 you understand word problems better than you have '
          'all semester. Not everything — but enough. You close the '
          'textbook with something that feels, against all odds, '
          'a little like confidence. You set two alarms. The pasta '
          'is still on the table when you turn off the kitchen light.',
      isEnding: true,
    ),

    'ss_text_friend': QuestSegment(
      id: 'ss_text_friend',
      content:
          'You text Jordan: are you studying? I\'m completely lost.\n\n'
          'Jordan: YES omg. Facetime? We can quiz each other.\n\n'
          'You spend the next hour in a corner of your room with '
          'Jordan\'s face small on your screen, talking your way '
          'through problems. Something weird happens when you try '
          'to explain the fraction thing to Jordan — you understand '
          'it better after saying it out loud. Putting it into words, '
          'going slowly, checking if it makes sense — it makes it '
          'make sense to you too.\n\n'
          '«{companion} joins the call for the last twenty minutes. '
          'Three people turns out to be better than two.»\n\n'
          'By 9:30, your brain is somewhere between exhausted and solid. '
          'Not confident. Not 100%. But you can see the shape of the '
          'test now instead of just the dark.\n\n'
          'You hang up and turn off your lamp and lie there for a '
          'minute, looking at the ceiling. Tomorrow you\'ll take the '
          'test. Tonight you didn\'t do it alone.\n\n'
          'There\'s a little glow-star sticker up there from when you '
          'were seven that you never took down. You forgot it was there.',
      isEnding: true,
    ),

    'ss_break': QuestSegment(
      id: 'ss_break',
      content:
          'You set a ten-minute timer on your phone and get up.\n\n'
          'You get a glass of water. You stand at the kitchen window '
          'and look at the dark street. You do one of those standing '
          'stretches where you reach your arms over your head and feel '
          'every vertebra pop in sequence. A neighbor\'s cat walks '
          'along the fence line with the specific dignity of a '
          'small predator.\n\n'
          'When the timer goes off, something has reset.\n\n'
          'You go back to your room and read the first word problem '
          'again. It\'s still hard. But it\'s hard in a different way '
          'now — not impossible-hard, just needs-work-hard. You get '
          'through three more problems before your eyes go heavy. '
          'Three is three more than zero.\n\n'
          '«{companion} texts at 9:48: still up? You write: just '
          'finishing. night. {companion}: you got this.»\n\n'
          'You close the book. You set two alarms. You turn off the '
          'light.\n\n'
          'Somewhere outside, the neighbor\'s cat reaches the end '
          'of the fence and drops into the dark below.\n\n'
          'You\'re asleep before you know it.',
      isEnding: true,
    ),

    'ss_focus_strengths': QuestSegment(
      id: 'ss_focus_strengths',
      content:
          'You flip past the word problems without ceremony.\n\n'
          'Fractions: you drill until they\'re automatic. Decimals: '
          'every practice problem, twice. Operations: you can do '
          'these almost without looking. You build a floor of things '
          'you know under the things you don\'t, and it holds.\n\n'
          'The next day in class, you start the test and something '
          'unexpected happens: the first three problems are exactly '
          'what you drilled. Your pencil moves. Not fast — careful, '
          'deliberate — but it moves.\n\n'
          'The word problems are rough. You get partial credit on two '
          'of them because you showed your work even though the answer '
          'was wrong. That counts for something.\n\n'
          '«{companion} passes you in the hall after. "How\'d it go?" '
          '"Not terrible," you say.»\n\n'
          'The grade comes back three days later: 78%. Not amazing. '
          'Not a disaster. You fold the test into quarters and put it '
          'in your bag. Then you take it out again and look at the '
          'fractions section — every one right — and fold it back up.\n\n'
          'You knew what you knew. You used it.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 4: The Last Straw
// ═══════════════════════════════════════════════════════════════════════════════

const questSiblingConflict = LifeQuestScenario(
  id: 'sibling_conflict',
  title: 'The Last Straw',
  hook: 'Your sibling\'s back again. Fourth time.',
  emoji: '\u{1F4A2}',
  emotions: ['angry', 'frustrated'],
  recommendedBands: [AgeBand.adventurer, AgeBand.creator],
  startSegmentId: 'sc_start',
  segments: {
    'sc_start': QuestSegment(
      id: 'sc_start',
      content:
          'You\'re in the middle of the good part.\n\n'
          'It doesn\'t matter what — homework, a drawing, a show '
          'you\'re three episodes into — but the point is you\'re '
          'in it. The kind of focused where the rest of the world '
          'goes soft and the thing you\'re doing is the only thing '
          'that exists. Your bedroom door has been closed for twenty '
          'minutes. That is supposed to mean something.\n\n'
          'It doesn\'t.\n\n'
          'The door swings open for the fourth time. Your younger '
          'sibling stands in the frame, looking at you with that '
          'specific expression of someone who has absolutely no idea '
          'what they\'ve interrupted.\n\n'
          '"Can I use your markers?"\n\n'
          'The same markers you said no to twenty minutes ago. '
          'And ten minutes ago. And five minutes ago.\n\n'
          'The anger is already there — it\'s been building since '
          'request one, like steam in a kettle, slow and pressurized. '
          'You can feel it behind your sternum, hot and certain.\n\n'
          '«{companion} is somewhere in the house. You think about '
          'texting them. You don\'t.»\n\n'
          'Your sibling is still standing there. Waiting. '
          'Innocent. Impossible.',
      choices: [
        QuestChoice(
          id: 'sc_c1a',
          text: '"GET OUT OF MY ROOM!" — just yell it',
          nextSegmentId: 'sc_yell',
        ),
        QuestChoice(
          id: 'sc_c1b',
          text: 'Take a breath: "I need 30 minutes alone."',
          nextSegmentId: 'sc_boundary',
        ),
        QuestChoice(
          id: 'sc_c1c',
          text: 'Go find a parent',
          nextSegmentId: 'sc_parent',
        ),
      ],
    ),

    'sc_yell': QuestSegment(
      id: 'sc_yell',
      content:
          '"GET OUT!"\n\n'
          'It comes out louder than you meant — louder than you knew '
          'you had — and for one sharp second the whole house '
          'holds its breath.\n\n'
          'Your sibling\'s face does that crumpling thing. The slow '
          'collapse, the wobbling lip, the eyes going shiny. Then '
          'the crying starts: big, full-body, the kind that carries '
          'down the hall and through closed doors.\n\n'
          'Footsteps. A parent appears in your doorway. '
          '"What happened?"\n\n'
          'Here\'s the unfair part: you were the one being bothered, '
          'four separate times, and now you\'re the one in trouble. '
          'You know how the math works. You know how it looks from '
          'the hallway. The anger is still hot inside you but it\'s '
          'got nowhere useful to go.\n\n'
          '«{companion} texts you. You don\'t look at your phone.»\n\n'
          'Your parent is waiting. Your sibling is in the hall '
          'still crying. The markers are on your desk.\n\n'
          'You can keep pushing, or you can say the thing that might '
          'actually change something.',
      choices: [
        QuestChoice(
          id: 'sc_c2a',
          text: 'Explain yourself — stay calm this time',
          nextSegmentId: 'sc_explain',
        ),
        QuestChoice(
          id: 'sc_c2b',
          text: '"This is SO unfair!" — push back',
          nextSegmentId: 'sc_unfair',
        ),
      ],
    ),

    'sc_boundary': QuestSegment(
      id: 'sc_boundary',
      content:
          'One breath. You take it slowly, all the way in, like you\'re '
          'filling something up.\n\n'
          '"I need thirty minutes alone," you say. "After that, '
          'you can come in."\n\n'
          'Your sibling blinks. You watch the disappointment move '
          'across their face — not the wound of being yelled at, '
          'just the ordinary disappointment of not yet. Their '
          'shoulders drop half an inch.\n\n'
          '"Okay," they say. "Thirty minutes?"\n\n'
          '"Thirty minutes." You close the door.\n\n'
          'You sit on the floor with your back against the bed and '
          'let the anger finish burning off. It takes about four '
          'minutes. The steam runs out and what\'s left is quieter, '
          'and then it\'s quiet enough to think.\n\n'
          '«You text {companion}: I did the breathing thing. '
          '{companion} texts back: and? You send a thumbs up.»\n\n'
          'You go back to your work. In thirty minutes your sibling '
          'knocks once, politely, and waits.\n\n'
          'You open the door.\n\n'
          'Outside, the light has gone orange and soft. '
          'You got the time you needed without burning anything down.',
      isEnding: true,
    ),

    'sc_parent': QuestSegment(
      id: 'sc_parent',
      content:
          'You walk past your sibling without a word and down the '
          'hall to find a parent.\n\n'
          'Your dad is in the living room, phone in hand, looking '
          'tired in the specific way of someone who has mediated '
          'this exact argument approximately forty times this year. '
          'You explain it anyway.\n\n'
          '"I\'ve asked them to leave me alone four separate times. '
          'I just need some help."\n\n'
          'Dad sighs — the long, resigned sigh of a referee — and '
          'puts his phone down. He goes back to the hall, redirects '
          'your sibling with a snack and the remote control, and '
          'waves you back to your room.\n\n'
          '«{companion} texts you later: you survived? '
          '"Barely," you write back.»\n\n'
          'You sit at your desk. The thirty minutes of peace are '
          'real, even if they came via the circuitous route of '
          'adult intervention. Tomorrow will probably be the same. '
          'But right now the room is quiet — just the hum of the '
          'heater, the late-afternoon light on the wall, and the '
          'thing you were making, right where you left it.\n\n'
          'You pick it up. You keep going.',
      isEnding: true,
    ),

    'sc_explain': QuestSegment(
      id: 'sc_explain',
      content:
          'You take a breath. Not for drama — just to make sure '
          'what comes out is words and not just noise.\n\n'
          '"They came in four times," you say. "I asked them to '
          'stop every time. I shouldn\'t have yelled — but I was '
          'really frustrated."\n\n'
          'Your parent looks at you. Really looks — the evaluating '
          'kind, trying to figure out the shape of what happened.\n\n'
          '"I hear you," they say. "The yelling wasn\'t okay. But '
          'I understand how you got there."\n\n'
          'In the hallway, your sibling has gotten quieter. Not '
          'happy. But quieter.\n\n'
          'You know you still have to apologize for the volume. '
          'That part isn\'t going away. But explaining your side '
          'first — calmly, specifically, after you\'d already blown '
          'it — changed something about how the room felt. '
          'Your parent heard you.\n\n'
          '«{companion} texts: how bad? You write back: manageable. '
          'You mean it.»\n\n'
          'The apology, when it comes, is easier. Not easy. Easier. '
          'Like the words have somewhere to land.\n\n'
          'Your sibling says "okay" in a small voice and goes '
          'back to their room. You close your door. '
          'The air in the room is still.',
      isEnding: true,
    ),

    'sc_unfair': QuestSegment(
      id: 'sc_unfair',
      content:
          '"This is SO unfair! They bother me all day and I\'M the '
          'one who gets in trouble?"\n\n'
          'Your parent\'s face goes flat. "We don\'t raise our '
          'voices in this house."\n\n'
          '"But—"\n\n'
          '"That\'s enough."\n\n'
          'And now the conversation is about your tone, not about '
          'what your sibling did. The original thing — the four '
          'times, the ignoring, the slow buildup — is buried under '
          'new layers. You end up in your room anyway, door closed, '
          'but it feels like losing.\n\n'
          'Your sibling is quiet in their room. Your parent is quiet '
          'in theirs. The whole house has gone into that pressurized '
          'stillness that comes after a fight nobody won.\n\n'
          '«Your phone buzzes. {companion}. You don\'t pick up.»\n\n'
          'You lie on your bed and stare at the ceiling and let the '
          'whole afternoon replay. The unfairness was real — you were '
          'right about that part. But the delivery buried the message.\n\n'
          'The ceiling has a water stain near the window you\'ve '
          'never noticed before. You stare at it for a while.\n\n'
          'Tomorrow is there, waiting, on the other side of the dark.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 5: The Comment
// ═══════════════════════════════════════════════════════════════════════════════

const questBeingTeased = LifeQuestScenario(
  id: 'being_teased',
  title: 'The Comment',
  hook: 'Someone said something in the hallway. It\'s still in your head.',
  emoji: '\u{1F62A}',
  emotions: ['sad', 'angry', 'embarrassed'],
  recommendedBands: [AgeBand.adventurer, AgeBand.creator],
  startSegmentId: 'bt_start',
  segments: {
    'bt_start': QuestSegment(
      id: 'bt_start',
      content:
          'The hallway between second and third period is pure noise — '
          'lockers slamming, sneakers squeaking, two hundred separate '
          'conversations layered on top of each other.\n\n'
          'You\'re walking through it the way you always do, keeping '
          'pace, when you hear it.\n\n'
          'Loud enough to cut through the noise. Designed to cut '
          'through it — that\'s what gives it its shape. A comment '
          'about your shoes. Your hair. The way you answered something '
          'in class. The words themselves aren\'t the worst words '
          'in the world. It\'s the laugh that follows them — three '
          'or four kids cracking up like it\'s the funniest thing '
          'since forever — that makes your face go hot.\n\n'
          'Your face goes hot anyway, even when you tell it not to.\n\n'
          '«Somewhere behind you, {companion} hears it too. '
          'You can feel that without turning around.»\n\n'
          'You have about five seconds before your face tells the '
          'whole hallway what the comment did to you. Five seconds '
          'of looking like you didn\'t hear it, like it bounced off, '
          'like you\'re someone it can\'t reach.\n\n'
          'What do you do with five seconds?',
      choices: [
        QuestChoice(
          id: 'bt_c1a',
          text: 'Keep walking — don\'t give them the reaction',
          nextSegmentId: 'bt_keep_walking',
        ),
        QuestChoice(
          id: 'bt_c1b',
          text: 'Fire back — say something sharp',
          nextSegmentId: 'bt_fire_back',
        ),
        QuestChoice(
          id: 'bt_c1c',
          text: 'Find a trusted adult after class',
          nextSegmentId: 'bt_tell_adult',
        ),
      ],
    ),

    'bt_keep_walking': QuestSegment(
      id: 'bt_keep_walking',
      content:
          'You keep walking.\n\n'
          'Shoulders level. Jaw loose. Eyes on the door at the end '
          'of the hall. You pass through the noise and out the other '
          'side and into the relative quiet of the bathroom, where '
          'you stand at the sink and run the water and look at '
          'yourself in the mirror.\n\n'
          'Your face is red. You knew it would be.\n\n'
          'The comment is still running on a loop inside your head '
          'with the sound design of the laugh — the specific rhythm '
          'of it, who laughed louder, the beat before it died out.\n\n'
          '«{companion} appears in the doorway, checks no one\'s '
          'following, and comes in. "I heard that," {companion} says. '
          'You nod. "I know."»\n\n'
          'You splash cold water on your face. The red fades a little.\n\n'
          'The comment is still there. It\'s going to be there for '
          'a while, probably. The question is what you do with it '
          'now — whether you carry it quietly or hand it to someone '
          'or set it somewhere it can\'t follow you to class.',
      choices: [
        QuestChoice(
          id: 'bt_c2a',
          text: 'Text a friend about it',
          nextSegmentId: 'bt_text_friend',
        ),
        QuestChoice(
          id: 'bt_c2b',
          text: 'Let it go — they\'re not worth the energy',
          nextSegmentId: 'bt_let_go',
        ),
      ],
    ),

    'bt_fire_back': QuestSegment(
      id: 'bt_fire_back',
      content:
          'You stop. You turn around.\n\n'
          'The comeback is already forming — something quick, '
          'specific, aimed at exactly the thing that will puncture '
          'the most — and it comes out clean and sharp and '
          'right on target.\n\n'
          'The hallway does that collective intake, the OOOH that '
          'means the shot landed. The kid who said it blinks. '
          'The smirk disappears. For one bright second, it feels '
          'like winning.\n\n'
          'Then you notice the teacher at the far end of the hall. '
          'She\'s looking.\n\n'
          'The crowd is looking. The teacher is looking. Your face '
          'is still hot, but for a different reason — not the '
          'original comment but what comes after it, the attention '
          'that cuts both ways.\n\n'
          '«{companion} is right behind you. Too close to this now.»\n\n'
          'You won the moment. The moment has maybe fifteen more '
          'seconds before it becomes something else.',
      choices: [
        QuestChoice(
          id: 'bt_c3a',
          text: 'Walk away before it escalates',
          nextSegmentId: 'bt_walk_away_after',
        ),
        QuestChoice(
          id: 'bt_c3b',
          text: 'Keep going — they started it',
          nextSegmentId: 'bt_escalate',
        ),
      ],
    ),

    'bt_tell_adult': QuestSegment(
      id: 'bt_tell_adult',
      content:
          'After class, you find Ms. Chen in her room — the one who '
          'keeps the door open during lunch on purpose, who notices '
          'things.\n\n'
          '"Something happened in the hallway and I need to '
          'talk about it."\n\n'
          'She closes her laptop and turns to face you. Full '
          'attention — not the distracted kind, not the I\'m '
          'listening while also grading kind.\n\n'
          'You tell her what happened. Exactly. Without exaggerating, '
          'without minimizing.\n\n'
          'She nods through it. At the end she says: "That wasn\'t '
          'okay. I\'m glad you told me."\n\n'
          '«{companion} is waiting outside the door. '
          '"Did it help?" {companion} asks when you come out. '
          '"Yeah," you say. "I think so."»\n\n'
          'She doesn\'t make a public thing of it. You don\'t want '
          'a public thing. You want someone who has your back '
          'and knows what happened, and now that person exists.\n\n'
          'The next morning she checks in with you in the hall — '
          'not conspicuously, just a nod, a small acknowledgment. '
          'She remembered.\n\n'
          'The hallway is the same hallway. But it feels slightly '
          'less like a place where things can happen to you '
          'without anyone noticing.',
      isEnding: true,
    ),

    'bt_text_friend': QuestSegment(
      id: 'bt_text_friend',
      content:
          'You text Sam: someone just made fun of me in the hall.\n\n'
          'Sam replies in about forty-five seconds: WHO. I will '
          'fight them.\n\n'
          'You have to cover your face to not laugh out loud. '
          'The specificity of it, the immediate loyalty, the '
          'complete absence of "well maybe they didn\'t mean it" — '
          'it breaks through the bad feeling like a rock through ice.\n\n'
          'You and Sam spend the next ten minutes cataloging exactly '
          'why the kid was wrong and specifically uncool. It\'s petty. '
          'It helps enormously.\n\n'
          '«You text {companion} too: did you hear that? '
          '{companion}: yeah. you okay? Getting there, you write.»\n\n'
          'By lunch the comment is smaller. Not gone — you can still '
          'hear the laugh if you look for it. But it doesn\'t have '
          'the same square footage in your head that it did at 9:47.\n\n'
          'Having two people immediately, unreservedly on your side '
          'doesn\'t fix it. It just makes the hallway feel like it '
          'belongs to more people than just the one who laughed.',
      isEnding: true,
    ),

    'bt_let_go': QuestSegment(
      id: 'bt_let_go',
      content:
          'You splash cold water on your face, take one more look '
          'in the mirror, and go to class.\n\n'
          'The comment runs on a loop for the next hour. '
          'Forty-five minutes. Thirty. By the time you\'re two-thirds '
          'through third period, it\'s moved from the front of your '
          'mind to somewhere behind your shoulder — still there, '
          'but further away.\n\n'
          'By lunch: background noise. By the end of the day: almost '
          'gone. It\'s still there if you look for it, but it\'s lost '
          'the sharp edge it had in the hallway. Time did that, '
          'and the normal afternoon did that.\n\n'
          '«{companion} catches you at the end of the day. '
          '"You okay?" "Yeah," you say. "I think I\'m okay."»\n\n'
          'You didn\'t fight back. You didn\'t report it. You didn\'t '
          'make it into a thing. Sometimes that\'s also a choice — '
          'deciding that someone\'s comment doesn\'t get permanent '
          'residency in your head.\n\n'
          'Walking home, you notice the light doing something good '
          'with the trees. You stop for a second and look at it.',
      isEnding: true,
    ),

    'bt_walk_away_after': QuestSegment(
      id: 'bt_walk_away_after',
      content:
          'You turn and walk.\n\n'
          'Your hands are shaking slightly — the kind that happens '
          'when adrenaline finds nowhere to go. The hallway noise '
          'closes behind you like water. You don\'t look back.\n\n'
          'The comeback landed. You know it landed. You also stopped '
          'before the teacher came all the way over, before it became '
          'an official incident, before everyone had to pick sides. '
          'That line exists somewhere between winning and stopping, '
          'and maybe you found it.\n\n'
          '«{companion} falls into step beside you without a word.»\n\n'
          'In the bathroom you run the water and let your hands '
          'steady out. In the mirror your face looks almost normal.\n\n'
          'The kid will probably remember what you said. You\'ll '
          'remember it too — the way it felt to fire back and the '
          'way it felt to walk away after. Both feelings, accurate '
          'and complete.\n\n'
          'You dry your hands. The paper towel is rough against '
          'your palms. You\'re late for class. You go anyway.',
      isEnding: true,
    ),

    'bt_escalate': QuestSegment(
      id: 'bt_escalate',
      content:
          'The back-and-forth goes up, and up, and then the teacher '
          'is right there with both of you and the hallway is '
          'a crowd.\n\n'
          '"Both of you. My classroom. Now."\n\n'
          'You sit in the hallway outside while she talks to each '
          'of you separately. Your stomach is doing something '
          'complicated. You were right — they started it. That\'s '
          'still true. But you kept going after it was already going, '
          'and now you\'re both here, and the difference between who '
          'started it and who continued it is very small from '
          'the outside.\n\n'
          'Warning. Both of you.\n\n'
          '«{companion} texts you that afternoon. You take a '
          'long time to answer.»\n\n'
          'You walk home and replay it. The original comment. Your '
          'comeback. The OOOH. The moment it went past what it needed '
          'to be. The warning sitting in your student file.\n\n'
          'The satisfaction lasted maybe ten seconds. '
          'The consequence lasted all day. '
          'Tomorrow is there, waiting.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 6: Behind Closed Doors
// ═══════════════════════════════════════════════════════════════════════════════

const questFamilyStress = LifeQuestScenario(
  id: 'family_stress',
  title: 'Behind Closed Doors',
  hook: 'The voices downstairs aren\'t quite yelling.',
  emoji: '\u{1F3E0}',
  emotions: ['sad', 'worried', 'angry'],
  recommendedBands: [AgeBand.creator, AgeBand.adolescent],
  startSegmentId: 'fs_start',
  segments: {
    'fs_start': QuestSegment(
      id: 'fs_start',
      content:
          'Your room should be a safe place. You\'ve got the door '
          'closed, the lamp on, the homework spread out on the bed '
          'in an optimistic way.\n\n'
          'But the voices downstairs aren\'t loud enough to understand '
          'and just loud enough to not ignore. Mom and Dad — not '
          'exactly yelling, but not not-yelling either. The tight, '
          'clipped kind of voices that carry differently from normal '
          'talking. The kind that make the walls feel thin.\n\n'
          'This has been happening more lately. You\'ve gotten good '
          'at counting the length of the silences between rounds '
          'instead of actually counting the rounds.\n\n'
          'Your homework is open on the bed. The words aren\'t moving '
          'from the page to your brain.\n\n'
          '«{companion} texted you an hour ago about something funny. '
          'You wrote back with a period and never explained why.»\n\n'
          'You\'re in your room with the door closed and everything '
          'that matters is downstairs, loud enough to hear the '
          'shape of it if not the words.\n\n'
          'What do you do with the rest of tonight?',
      choices: [
        QuestChoice(
          id: 'fs_c1a',
          text: 'Put on headphones — block it out',
          nextSegmentId: 'fs_headphones',
        ),
        QuestChoice(
          id: 'fs_c1b',
          text: 'Text a friend — just need something normal',
          nextSegmentId: 'fs_text',
        ),
        QuestChoice(
          id: 'fs_c1c',
          text: 'Go downstairs and ask them to stop',
          nextSegmentId: 'fs_intervene',
        ),
      ],
    ),

    'fs_headphones': QuestSegment(
      id: 'fs_headphones',
      content:
          'You put them on. Volume up. The music goes all the way '
          'around you — bass through your chest, a wall of sound '
          'between you and the house.\n\n'
          'For thirty minutes, nothing reaches you. The walls stop '
          'being thin. Your room becomes its own country.\n\n'
          'You don\'t do the homework. You lie on your bed and stare '
          'at the ceiling and let the music do what it does.\n\n'
          'When you take the headphones off — they go warm after a '
          'while — the house is quiet. The voices have stopped. '
          'You don\'t know what that means. You don\'t go find out.\n\n'
          '«You text {companion}: hey. {companion}: hey. '
          'Nothing else. Just knowing someone\'s there.»\n\n'
          'You didn\'t fix anything. There\'s nothing downstairs you '
          'could have fixed anyway. But you protected something — '
          'your own ability to breathe for thirty minutes, the small '
          'country of your room, the fact that their fight didn\'t '
          'become your fight.\n\n'
          'You do the math homework after. It\'s easier now, '
          'for no reason that makes sense.',
      isEnding: true,
    ),

    'fs_text': QuestSegment(
      id: 'fs_text',
      content:
          'You open your messages and text Kai: what are you up to?\n\n'
          'You don\'t explain. You don\'t say my parents are arguing '
          'downstairs and I can\'t focus on anything. You just '
          'ask what they\'re up to.\n\n'
          'Kai sends a video of their dog doing something improbable '
          'with a water bottle. Then a meme. Then a question about '
          'the weekend. For twenty minutes you\'re in that conversation '
          'instead — smaller, warmer, normal-sized instead of '
          'house-sized.\n\n'
          '«{companion} texts too, somehow. You have two conversations '
          'going. The house downstairs goes quiet.»\n\n'
          'You exhale. You hadn\'t noticed you were holding your breath.\n\n'
          'The voices have stopped — when, you\'re not sure. The '
          'homework is still there. The lamp is warm. Outside the '
          'window the street is the regular dark of an ordinary night.\n\n'
          'Kai doesn\'t know they threw you a rope. You\'ll tell them '
          'someday, maybe. For now you write goodnight and put '
          'your phone face-up on the bed.\n\n'
          'It\'s easier to breathe than it was an hour ago.',
      isEnding: true,
    ),

    'fs_intervene': QuestSegment(
      id: 'fs_intervene',
      content:
          'You put down your pencil and walk downstairs.\n\n'
          'Both of them stop when you appear. Your mom\'s face changes '
          'first — going careful, the way it does when she\'s trying '
          'to figure out what you\'ve heard.\n\n'
          '"Can you guys not do this right now?"\n\n'
          'Silence. The specific silence of two people deciding how '
          'to respond to being interrupted.\n\n'
          '"Honey, I\'m sorry you heard that," your mom says. '
          '"We\'re just having a conversation."\n\n'
          '"About what?" you ask, and immediately know it was '
          'the wrong question.\n\n'
          '"About grown-up things," your dad says. Tired. Not unkind. '
          'Just tired.\n\n'
          'You go back upstairs. The voices start again maybe five '
          'minutes later, quieter this time — you\'re not sure if '
          'that\'s for your benefit or just because they burned '
          'through the hot part.\n\n'
          '«{companion} texts you. You\'re not ready to explain '
          'it yet. You don\'t answer.»\n\n'
          'You sit on the floor of your room with your back against '
          'the bed. Your options haven\'t changed. '
          'But you had to try.',
      choices: [
        QuestChoice(
          id: 'fs_c2a',
          text: 'Write it down — just for yourself',
          nextSegmentId: 'fs_journal',
        ),
        QuestChoice(
          id: 'fs_c2b',
          text: 'Call someone who gets it',
          nextSegmentId: 'fs_grandma',
        ),
      ],
    ),

    'fs_journal': QuestSegment(
      id: 'fs_journal',
      content:
          'You find a notebook — not a pretty one, just a spiral-bound '
          'thing — and you write.\n\n'
          'Not in sentences. Not for anyone. Just the inside of your '
          'head on paper: I hate when this happens. I feel like I\'m '
          'supposed to fix it but I can\'t. I just want it to stop. '
          'I want everything to be regular.\n\n'
          'The words look strange when they\'re outside your head. '
          'More real and also less powerful. Like draining water '
          'out of something.\n\n'
          '«You write about {companion} too — about normal things, '
          'easier things, until the hard stuff gets smaller on the '
          'page.»\n\n'
          'When you put the pen down, the weight hasn\'t gone '
          'anywhere. It\'s just been redistributed — some of it '
          'on the page now instead of only in your chest.\n\n'
          'Downstairs, it\'s gone quiet. You don\'t know if that\'s '
          'good or just a pause.\n\n'
          'You close the notebook. You don\'t re-read it. '
          'It\'s not for re-reading.\n\n'
          'The lamp on your desk makes a small warm circle. '
          'You sit inside it for a while.',
      isEnding: true,
    ),

    'fs_grandma': QuestSegment(
      id: 'fs_grandma',
      content:
          'She picks up on the second ring.\n\n'
          '"Hey, sweetie." Just her voice — warm and certain in '
          'that way that doesn\'t change no matter how old you get — '
          'makes your eyes sting. You weren\'t expecting that.\n\n'
          '"Are you okay?"\n\n'
          '"I don\'t know," you say. Which is the most honest thing '
          'you\'ve said all day.\n\n'
          'You tell her some of it. Not everything. Enough. '
          'Grandma goes quiet for a moment — the thinking kind '
          'of quiet. Then:\n\n'
          '"That\'s not your job to fix. You understand that? '
          'Grown-up problems are for grown-ups."\n\n'
          'Something releases in your chest.\n\n'
          '"Your job right now is to be okay. Go get a snack. '
          'Watch something dumb. I\'ll call your mom tomorrow." '
          'She says it like a plan, like she\'s already mapped '
          'the route.\n\n'
          '«"Tell {companion} I say hi," she says, for no particular '
          'reason. It makes you laugh.»\n\n'
          'You hang up. The house is still loud below you. But the '
          'size of it has changed — you\'ve been reminded that it '
          'isn\'t yours to carry, and you can feel exactly which '
          'muscles were holding it, now that they\'ve let go.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 7: The Only One
// ═══════════════════════════════════════════════════════════════════════════════

const questFeelingDifferent = LifeQuestScenario(
  id: 'feeling_different',
  title: 'The Only One',
  hook: 'Everyone has a matching outfit. You have a regular day.',
  emoji: '\u{1F30D}',
  emotions: ['sad', 'worried', 'embarrassed'],
  recommendedBands: [AgeBand.creator, AgeBand.adolescent],
  startSegmentId: 'fd_start',
  segments: {
    'fd_start': QuestSegment(
      id: 'fd_start',
      content:
          'Spirit week. The word alone produces a specific texture '
          'of dread.\n\n'
          'Today is Twin Day, which means the hallways are full of '
          'matching pairs — coordinated shirts, color-blocked sets, '
          'identical sneakers — and everywhere you look there\'s '
          'someone who planned something with someone else. A best '
          'friend. A cousin. A whole group in matching hoodies.\n\n'
          'You\'re wearing regular clothes.\n\n'
          'Not because you forgot. You remembered. You just didn\'t '
          'have anyone to ask, and asking a stranger to be your twin '
          'felt worse than showing up alone, and now you\'re walking '
          'through the hallway feeling like a puzzle piece from '
          'the wrong box.\n\n'
          'You\'ve felt this before. Not just today — the general '
          'version of it. The way certain rooms make you feel like '
          'you got the casting wrong.\n\n'
          '«Beside you, {companion} says: "I could have been your '
          'twin." "Would\'ve been a good one," you say. '
          '"Next year," {companion} says. But that\'s next year.»\n\n'
          'Right now you\'re in this hallway in your regular clothes, '
          'and the question is what you do with today as it actually is.',
      choices: [
        QuestChoice(
          id: 'fd_c1a',
          text: 'Own it — walk through the hallway exactly as you are',
          nextSegmentId: 'fd_own_it',
        ),
        QuestChoice(
          id: 'fd_c1b',
          text: 'Find someone else flying solo',
          nextSegmentId: 'fd_find_solo',
        ),
        QuestChoice(
          id: 'fd_c1c',
          text: 'Skip the chaos — head to the library',
          nextSegmentId: 'fd_library',
        ),
      ],
    ),

    'fd_own_it': QuestSegment(
      id: 'fd_own_it',
      content:
          'You square your shoulders and walk.\n\n'
          'When someone asks — and someone does ask, inevitably, a kid '
          'from your English class with the bright curiosity of someone '
          'who genuinely wants to know — you say:\n\n'
          '"Going as myself."\n\n'
          'A beat. Two. Then she laughs — not at you, the surprised '
          'kind, the I didn\'t see that coming kind. '
          '"That\'s kind of perfect," she says.\n\n'
          'By third period, you\'ve said it twice more. By lunch, it '
          'has taken on a life of its own — three kids have ditched '
          'their twin gear on the grounds that "yours is actually '
          'cooler." You didn\'t mean to start anything. You were just '
          'doing the only thing available to you.\n\n'
          '«{companion} high-fives you in the hall after lunch. '
          '"I knew you\'d figure it out," {companion} says. '
          'You didn\'t. But it doesn\'t matter now.»\n\n'
          'Walking home, the day hangs in a particular light — late '
          'afternoon, golden, trees not quite decided on their colors. '
          'You think about how things can turn without you engineering '
          'them. How sometimes the only thing to do is be exactly '
          'what you are, without apology.',
      isEnding: true,
    ),

    'fd_find_solo': QuestSegment(
      id: 'fd_find_solo',
      content:
          'You find them by accident.\n\n'
          'Dev is on a bench by the water fountain, reading a book, '
          'resolutely not dressed as anyone\'s twin. You sit down next '
          'to them without quite planning to.\n\n'
          '"Twin Day reject?" you ask.\n\n'
          'Dev looks up. Considers this. "Proudly," they say.\n\n'
          'You spend the next twenty minutes inventing alternative '
          'spirit days: Mismatched Sock Day, Invisible Hat Day, Speak '
          'Only in Questions Day. By lunch you\'ve recruited three '
          'more people who\'d rather build something new than feel '
          'bad about what they missed.\n\n'
          '«{companion} finds you at the table. "What is this?" '
          '{companion} asks, looking at the group. '
          '"Counter-spirit-week," Dev says. {companion} sits down. '
          '"I\'m in."»\n\n'
          'Walking home, you think about how the day started — that '
          'tight, isolated feeling in the hallway — and where it ended. '
          'You didn\'t change Twin Day. You found the people for whom '
          'Twin Day was also wrong, and you made something else.\n\n'
          'The puzzle pieces from the wrong box were all there. '
          'You just had to sit down on the right bench.',
      isEnding: true,
    ),

    'fd_library': QuestSegment(
      id: 'fd_library',
      content:
          'The library is warm in the way of rooms that take their '
          'temperature from old books — a specific kind of warmth, '
          'like tea.\n\n'
          'Mr. Park nods when you come in. No questions. He has that '
          'particular gift of librarians who know when someone needs '
          'to just exist somewhere for a while.\n\n'
          'You find a spot by the window and sit down. Outside, '
          'through the glass, the world continues doing Twin Day. '
          'In here it\'s quiet enough to hear the heater and someone '
          'turning pages.\n\n'
          'The ache is still there. The not-fitting-in feeling doesn\'t '
          'leave because you moved rooms. It just gets a little '
          'less loud.\n\n'
          '«{companion} texts: where are you? You write: library. '
          'I\'m okay. {companion}: ok. find me at lunch? '
          'Yeah, you write.»\n\n'
          'You\'re not sure if you came here to hide or to breathe. '
          'Maybe both. Maybe they\'re the same thing sometimes.\n\n'
          'The question is whether you stay here or go back out there, '
          'and which one feels like a choice and which one feels '
          'like surrender.',
      choices: [
        QuestChoice(
          id: 'fd_c2a',
          text: 'Actually read — get lost in a story',
          nextSegmentId: 'fd_read',
        ),
        QuestChoice(
          id: 'fd_c2b',
          text: 'Go back out — hiding doesn\'t feel right',
          nextSegmentId: 'fd_go_back',
        ),
      ],
    ),

    'fd_read': QuestSegment(
      id: 'fd_read',
      content:
          'You pick up a book at random — the one on the end of the '
          'display shelf, spine-out, a kid on the cover standing on '
          'some kind of alien landscape.\n\n'
          'Ten pages in, you\'re somewhere else entirely.\n\n'
          'The character is from a place that isn\'t theirs. Everything '
          'in the world they landed in is different — the rules, '
          'what counts as polite, what counts as cool. And yet they\'re '
          'figuring it out. Not by becoming something else. By being '
          'exactly what they are, which turns out to be specifically '
          'useful on this particular planet.\n\n'
          '«You forget to text {companion} back.»\n\n'
          'The bell rings and startles you. You\'ve been here an hour. '
          'The story isn\'t done.\n\n'
          'You put the book back on the shelf and write the title '
          'down in your phone.\n\n'
          'Walking to your next class, something has shifted — not '
          'fixed, just reframed. The different-ness that felt like '
          'a flaw an hour ago feels a little more like a feature. '
          'Not because a book told you so. Because the character '
          'showed you. There\'s a difference.',
      isEnding: true,
    ),

    'fd_go_back': QuestSegment(
      id: 'fd_go_back',
      content:
          'You stand up.\n\n'
          'Staying in the library doesn\'t feel right. It feels like '
          'letting the hallway win. And the hallway is just a hallway '
          '— people and lockers and noise, nothing more.\n\n'
          'You push through the doors.\n\n'
          'The Twin Day chaos is still going — matching outfits, '
          'matching laughs, someone\'s phone playing music out of '
          'a speaker. But something is different: you chose to come '
          'back. That changes the shape of it. Not dramatically, not '
          'forever. Just right now, it\'s your choice, not '
          'the day\'s.\n\n'
          '«{companion} is just past the door, leaning against '
          'the lockers. "Hey," {companion} says. "Hey," you say. '
          'You walk together.»\n\n'
          'In art class you sit next to someone you\'ve never sat '
          'next to before. She\'s drawing something complicated and '
          'small and when she catches you looking she turns it toward '
          'you so you can see better.\n\n'
          'You tell her it\'s good. She says thanks. You start '
          'drawing your own thing. The afternoon keeps going, '
          'ordinary and specific, full of exactly the right '
          'amount of small things.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 8: The Drift
// ═══════════════════════════════════════════════════════════════════════════════

const questLosingFriendship = LifeQuestScenario(
  id: 'losing_friendship',
  title: 'The Drift',
  hook: 'Your best friend is becoming someone else\'s best friend.',
  emoji: '\u{1F494}',
  emotions: ['sad', 'worried', 'angry', 'embarrassed'],
  recommendedBands: [AgeBand.creator, AgeBand.adolescent],
  startSegmentId: 'lf_start',
  segments: {
    'lf_start': QuestSegment(
      id: 'lf_start',
      content:
          'Since second grade.\n\n'
          'That\'s how long you and Morgan have been the kind of '
          'friends where it didn\'t require any maintenance — you '
          'just were, the way some things just are.\n\n'
          'This year, something shifted. You can\'t point to exactly '
          'when. Morgan started sitting at the soccer table at lunch. '
          'Inside jokes you weren\'t there for appeared. Weekend plans '
          'you heard about on Monday morning. Small things, then '
          'slightly less small things.\n\n'
          'Today you walked past the soccer table and Morgan looked '
          'up, saw you, and went back to their conversation. Not mean. '
          'Not deliberate. Just... not noticing. Or noticing and '
          'deciding the conversation mattered more.\n\n'
          'Your chest feels hollow. The specific hollowness of '
          'something you didn\'t realize you were holding '
          'until it wasn\'t there anymore.\n\n'
          '«{companion} is walking beside you. "You okay?" '
          '"Yeah," you say. Which is approximately true.»\n\n'
          'You used to be Morgan\'s first call. You\'re not sure what '
          'you are now — and not knowing is the part that\'s '
          'hard to name.',
      choices: [
        QuestChoice(
          id: 'lf_c1a',
          text: 'Text tonight: "Are we okay?"',
          nextSegmentId: 'lf_text',
        ),
        QuestChoice(
          id: 'lf_c1b',
          text: 'Start building elsewhere — don\'t wait around',
          nextSegmentId: 'lf_new_friends',
        ),
        QuestChoice(
          id: 'lf_c1c',
          text: 'Say it face to face',
          nextSegmentId: 'lf_face_to_face',
        ),
      ],
    ),

    'lf_text': QuestSegment(
      id: 'lf_text',
      content:
          'You draft it six times.\n\n'
          'Hey are we okay — too blunt. I feel like we haven\'t talked '
          'in forever — too sad. What\'s going on with you — too '
          'casual. Finally you send: Hey, I feel like we don\'t hang '
          'out anymore. Are we okay?\n\n'
          'Three dots. They stop. They start again. They stop '
          'for a long time.\n\n'
          'Then: Of course!! I\'ve just been super busy with soccer '
          'stuff. I\'m sorry.\n\n'
          'You read it twice. Of course!! Two exclamation points. '
          'I\'m sorry. She sounds like she means it. She also sounds '
          'like someone who hadn\'t thought about it until this text.\n\n'
          '«{companion} is on the couch across from you. You hold up '
          'your phone. {companion} reads it. "What do you think?" '
          '{companion} asks. "I don\'t know," you say. Which is true.»\n\n'
          'Busy and drifting away can look exactly the same from '
          'outside. They can also be the same. You don\'t know which '
          'one this is. The next message you send will probably '
          'tell you something.',
      choices: [
        QuestChoice(
          id: 'lf_c2a',
          text: '"Can we hang out this weekend? Just us?"',
          nextSegmentId: 'lf_plan',
        ),
        QuestChoice(
          id: 'lf_c2b',
          text: '"Okay. Just wanted to check." — leave it',
          nextSegmentId: 'lf_leave_it',
        ),
      ],
    ),

    'lf_new_friends': QuestSegment(
      id: 'lf_new_friends',
      content:
          'Instead of hovering at the edge of the soccer table or '
          'sitting alone, you walk to the art kids.\n\n'
          'You\'ve watched them from a distance all year — the group '
          'that always seems to be in the middle of an argument about '
          'something specific and ridiculous. Today it\'s whether the '
          'villain in some animated movie is actually the hero. Strong '
          'feelings on multiple sides.\n\n'
          'You sit down. You have an opinion about this particular '
          'movie. You share it.\n\n'
          'Two kids immediately defend the opposing view with alarming '
          'intensity and also a lot of joy. You argue back. Someone '
          'quotes a scene. Someone else quotes a different scene. '
          'The lunch period ends without you noticing it ending.\n\n'
          '«{companion} finds you after. "What was that?" '
          '"Honestly?" you say. "Pretty good." '
          '"Yeah," {companion} says. "You looked happy."»\n\n'
          'Walking to your next class, the hollow feeling is still '
          'there, somewhere. But it has a roommate now — something '
          'lighter, something new, something that didn\'t exist '
          'this morning.\n\n'
          'You don\'t know what it\'s going to be yet. But it showed '
          'up, and that\'s enough for today.',
      isEnding: true,
    ),

    'lf_face_to_face': QuestSegment(
      id: 'lf_face_to_face',
      content:
          'You catch Morgan at the lockers — the five-minute window '
          'before last period when the hall is almost empty.\n\n'
          '"Hey. Can we talk for a sec?"\n\n'
          'Morgan\'s face does something complicated. Surprised, a '
          'little nervous, a little guilty. "Yeah. What\'s up?"\n\n'
          'You take a breath. "I feel like we\'re kind of drifting. '
          'And I miss you."\n\n'
          'The words are out. You feel the air in your lungs go '
          'out with them.\n\n'
          'Morgan\'s face goes through at least four expressions — '
          'recognition, something that might be guilt, something that '
          'is definitely sadness. "I didn\'t realize," Morgan says. '
          '"I\'m sorry. I think I just got caught up in '
          'the soccer stuff."\n\n'
          'The awkwardness is real and so is the honesty.\n\n'
          '"Can we get pizza after school Friday? Like old times?" '
          'Morgan asks.\n\n'
          '«{companion} is at the end of the hall, not listening, '
          'giving you space. You\'ll tell {companion} later.»\n\n'
          'You nod. It might not be what it was. But it\'s a door '
          'cracked open, and you were the one who knocked.',
      isEnding: true,
    ),

    'lf_plan': QuestSegment(
      id: 'lf_plan',
      content:
          'Yes!! Movie night? Your place? Morgan texts back immediately.\n\n'
          'Saturday happens. Popcorn, the specific bad movie you both '
          'like, Morgan laughing so hard they snort apple juice — '
          'which then makes you laugh, which makes them laugh harder.\n\n'
          'It\'s almost like before. Not quite. Morgan talks about '
          'the soccer kids in a way that signals they\'re real friends '
          'now, not just a lunch table. There are inside jokes '
          'you still don\'t get.\n\n'
          '«{companion} texts you Sunday: "how was it?" You think '
          'about how to answer. Different, you write. '
          'Good different? I think so.»\n\n'
          'Lying in bed Sunday night, you think about friendships '
          'as chapters. The second-grade chapter — the one where you '
          'just were friends, effortlessly, the way children are — '
          'that chapter is done. It ended while you weren\'t watching.\n\n'
          'But done isn\'t the same as over.\n\n'
          'You reach over and turn off the light. Morgan texted you '
          'a meme at 11 PM and you didn\'t even hear your phone. '
          'You\'ll answer in the morning.',
      isEnding: true,
    ),

    'lf_leave_it': QuestSegment(
      id: 'lf_leave_it',
      content:
          'Okay. Just wanted to check.\n\n'
          'You put the phone down. The response was honest. Morgan '
          'sounded like she meant it. Of course we\'re okay. '
          'The exclamation point was real, probably.\n\n'
          'But the distance is still there. Honesty doesn\'t always '
          'close distance. Sometimes it just names it.\n\n'
          'Over the next few weeks, something slowly becomes clear: '
          'Morgan isn\'t being mean. You\'re not being dramatic. '
          'People change direction. Friendships can follow people '
          'or they can stay where they were — and you can\'t always '
          'tell which is happening until you\'re looking back at it.\n\n'
          'It hurts. The dull, specific ache of something that used '
          'to fit and doesn\'t quite anymore.\n\n'
          '«{companion} notices. Doesn\'t push. Just sits with you '
          'when you need sitting-with.»\n\n'
          'But you start paying attention to who\'s around. The girl '
          'from art class who always has something interesting to say. '
          'Jordan, who you\'ve been texting about the project and who '
          'is actually pretty funny. The world is made of more '
          'than one best friend.\n\n'
          'You don\'t lose Morgan. You just start making room '
          'for other things. The spring comes. You\'re okay.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 9: The Wobbly Day  [Explorer: ages 6-8]
// ═══════════════════════════════════════════════════════════════════════════════

const questWobblyDay = LifeQuestScenario(
  id: 'wobbly_day',
  title: 'The Wobbly Day',
  hook: 'New place. New people. Butterflies doing backflips.',
  emoji: '🦋',
  emotions: ['worried', 'excited', 'scared'],
  recommendedBands: [AgeBand.explorer],
  startSegmentId: 'wd_start',
  segments: {
    'wd_start': QuestSegment(
      id: 'wd_start',
      content:
          'Your tummy has butterflies this morning.\n\n'
          'Today is your first day — new classroom, new teacher, new everything. '
          'You\'ve been thinking about it all week.\n\n'
          '«{companion} walks beside you. "{companion} says: \'You\'ve got this.\'"»\n\n'
          'You stop just outside the door. Through the little window you can see '
          'kids already at their desks. Some are laughing. Some look as '
          'nervous as you feel.\n\n'
          'You take a big breath. What do you do?',
      choices: [
        QuestChoice(
          id: 'wd_c1a',
          text: 'Walk straight in with your head up',
          nextSegmentId: 'wd_brave',
        ),
        QuestChoice(
          id: 'wd_c1b',
          text: 'Wait by the door a little longer',
          nextSegmentId: 'wd_peek',
        ),
      ],
    ),

    'wd_brave': QuestSegment(
      id: 'wd_brave',
      content:
          'You walk right in — and guess what? Nobody even notices at first. '
          'Everyone is busy with their own butterflies.\n\n'
          'You find a seat near the front. A kid with a green pencil case '
          'looks over at you and gives you a small smile.\n\n'
          'Just a small smile. But it feels like a lot.',
      choices: [
        QuestChoice(
          id: 'wd_c2a',
          text: 'Smile back and say "Hi, I\'m {name}."',
          nextSegmentId: 'wd_hi',
        ),
        QuestChoice(
          id: 'wd_c2b',
          text: 'Smile back and look at your desk — maybe later',
          nextSegmentId: 'wd_quiet',
        ),
      ],
    ),

    'wd_peek': QuestSegment(
      id: 'wd_peek',
      content:
          'You watch through the window for a moment.\n\n'
          'Then the teacher opens the door — and almost walks right into you! '
          '{pronoun} laughs. A nice laugh. "Oh! Are you coming in?"\n\n'
          'Your cheeks go warm. But {pronoun} holds the door open wide '
          'and says, "We\'re so glad you\'re here."',
      choices: [
        QuestChoice(
          id: 'wd_c3a',
          text: 'Step inside and say thank you',
          nextSegmentId: 'wd_thanks',
        ),
        QuestChoice(
          id: 'wd_c3b',
          text: 'Step inside quietly and find a spot by the window',
          nextSegmentId: 'wd_window',
        ),
      ],
    ),

    'wd_hi': QuestSegment(
      id: 'wd_hi',
      content:
          '"Hi, I\'m {name}," you say.\n\n'
          'The kid with the green pencil case says their name back. '
          'Then: "Do you like stickers?"\n\n'
          'You laugh — you didn\'t expect that. But yeah, actually, '
          'you do like stickers.\n\n'
          'The butterflies are still there. But they\'re flying in '
          'formation now.\n\n'
          'Sometimes being brave is just saying two words.',
      isEnding: true,
    ),

    'wd_quiet': QuestSegment(
      id: 'wd_quiet',
      content:
          'You smile back but stay quiet for now. That\'s okay too.\n\n'
          'At lunch, the same kid taps your shoulder. '
          '"Is this seat taken?"\n\n'
          'You shake your head. They sit down.\n\n'
          'You didn\'t say a word all morning — and somehow you still '
          'made a friend by the afternoon.\n\n'
          'Butterflies don\'t last forever.',
      isEnding: true,
    ),

    'wd_thanks': QuestSegment(
      id: 'wd_thanks',
      content:
          '"Thank you," you say, and step inside.\n\n'
          'The teacher shows you your desk. There\'s a little name card '
          'on it — with your name spelled perfectly.\n\n'
          'Someone already knew you were coming. '
          'Someone already made space for you.\n\n'
          'That\'s a good feeling to hold onto.',
      isEnding: true,
    ),

    'wd_window': QuestSegment(
      id: 'wd_window',
      content:
          'You find a seat by the window and look outside for a moment.\n\n'
          'Everything familiar, and far away at the same time.\n\n'
          'The teacher starts talking and you turn back to the room.\n\n'
          'New doesn\'t have to mean worse. It just means different. '
          'And different... you can handle.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 10: The Sorry Stuck in Your Throat  [Explorer: ages 6-8]
// ═══════════════════════════════════════════════════════════════════════════════

const questSorryStuck = LifeQuestScenario(
  id: 'sorry_stuck',
  title: 'The Sorry Stuck in Your Throat',
  hook: 'You said something wrong. Now you have to fix it.',
  emoji: '🤐',
  emotions: ['sad', 'angry', 'embarrassed', 'worried'],
  recommendedBands: [AgeBand.explorer],
  startSegmentId: 'ss_start',
  segments: {
    'ss_start': QuestSegment(
      id: 'ss_start',
      content:
          'It was just a game.\n\n'
          'You were losing and you got really frustrated. The words came '
          'out before you could stop them — something mean, something '
          'you didn\'t totally mean.\n\n'
          'Your friend stopped playing. They looked at you like they '
          'didn\'t quite know who you were for a second.\n\n'
          'Now they\'re sitting across the room with their back to you.\n\n'
          '«{companion} sits down next to you. '
          '"That was pretty rough," {pronoun} says quietly.»\n\n'
          'Your face feels hot. You didn\'t mean it — or you did '
          'in that moment, but you don\'t now.',
      choices: [
        QuestChoice(
          id: 'ss_c1a',
          text: 'Go over and say sorry right now',
          nextSegmentId: 'ss_sorry_now',
        ),
        QuestChoice(
          id: 'ss_c1b',
          text: 'Wait — maybe they\'ll cool down on their own',
          nextSegmentId: 'ss_wait',
        ),
      ],
    ),

    'ss_sorry_now': QuestSegment(
      id: 'ss_sorry_now',
      content:
          'You walk over. Your heart is going fast.\n\n'
          '"Hey," you say. Your friend doesn\'t turn around yet.\n\n'
          'You take a breath. "I\'m sorry. What I said was mean. '
          'I was frustrated but that\'s not an excuse."\n\n'
          'Silence. Then your friend turns around. Their eyes are '
          'still a little pink.\n\n'
          '"It really hurt," they say.',
      choices: [
        QuestChoice(
          id: 'ss_c2a',
          text: '"I know. I\'m really sorry. Is there anything I can do?"',
          nextSegmentId: 'ss_do_something',
        ),
        QuestChoice(
          id: 'ss_c2b',
          text: '"I know. I\'m sorry." — and give them some space',
          nextSegmentId: 'ss_space',
        ),
      ],
    ),

    'ss_wait': QuestSegment(
      id: 'ss_wait',
      content:
          'You wait. The minutes feel long.\n\n'
          'Your friend doesn\'t come over. Lunch ends. The bell rings.\n\n'
          'Walking to class, they\'re ahead of you. The sorry is still '
          'stuck in your throat, getting heavier.\n\n'
          'Sorrys don\'t get easier the longer you hold them.',
      choices: [
        QuestChoice(
          id: 'ss_c3a',
          text: 'Run to catch up before the bell',
          nextSegmentId: 'ss_sorry_late',
        ),
        QuestChoice(
          id: 'ss_c3b',
          text: 'Send a message from home tonight',
          nextSegmentId: 'ss_text',
        ),
      ],
    ),

    'ss_do_something': QuestSegment(
      id: 'ss_do_something',
      content:
          '"Is there anything I can do?" you ask.\n\n'
          'Your friend thinks for a second. "Let me win the next game," '
          'they say — but then they smile. A wobbly, still-a-little-hurt smile.\n\n'
          'You laugh. Relief-laugh. Like letting out a breath '
          'you\'ve been holding all day.\n\n'
          '"Deal," you say.\n\n'
          'Saying sorry is scary. But it makes room for the good stuff to come back.',
      isEnding: true,
    ),

    'ss_space': QuestSegment(
      id: 'ss_space',
      content:
          'You step back and give them room.\n\n'
          'It\'s hard not to keep apologising — but sometimes sorry '
          'needs a moment to settle in.\n\n'
          'By the time recess is over, your friend comes and sits next to you.\n\n'
          '"Thanks for saying it," they say simply.\n\n'
          'Sometimes the best thing after sorry is just... quiet.',
      isEnding: true,
    ),

    'ss_sorry_late': QuestSegment(
      id: 'ss_sorry_late',
      content:
          'You run to catch up. "Hey — wait."\n\n'
          'Your friend stops.\n\n'
          '"I\'m really sorry," you say, a little out of breath. '
          '"I should have said it sooner."\n\n'
          'They look at you. "Yeah, you should have."\n\n'
          'It stings — but they\'re right. '
          'Then: "But okay. Thanks."\n\n'
          'Late is better than never. '
          'Sorrys don\'t expire. They just need to get out.',
      isEnding: true,
    ),

    'ss_text': QuestSegment(
      id: 'ss_text',
      content:
          'That night, you type it out. Delete it. Type it again.\n\n'
          'Finally you send it: "I\'m really sorry about what I said. '
          'I didn\'t mean it like that. Are we okay?"\n\n'
          'You watch the little dots appear. Disappear. Appear again.\n\n'
          '"Yeah. It hurt though."\n\n'
          '"I know. I\'m sorry."\n\n'
          'Sometimes sorry is easier when you\'re not face to face. '
          'That\'s okay. What matters is that you said it.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 11: The Tryout  [Adventurer / Creator / Adolescent: ages 9+]
// ═══════════════════════════════════════════════════════════════════════════════

const questTryout = LifeQuestScenario(
  id: 'the_tryout',
  title: 'The Tryout',
  hook: 'You\'ve practised a hundred times. None of that matters right now.',
  emoji: '🎭',
  emotions: ['worried', 'excited', 'scared', 'embarrassed'],
  recommendedBands: [AgeBand.adventurer, AgeBand.creator],
  startSegmentId: 'tt_start',
  segments: {
    'tt_start': QuestSegment(
      id: 'tt_start',
      content:
          'The sign-up sheet went up three weeks ago and you stared at it '
          'for four days before you wrote your name. Your handwriting looked '
          'wrong — too small, like part of you was already trying to take it back.\n\n'
          '«{companion} saw you do it. "Finally," {pronoun} said, '
          'and you weren\'t sure if that was encouraging or terrifying.»\n\n'
          'Now it\'s the day. The room smells the way high-stakes places always do: '
          'floor wax, nervous breath, and the particular silence of people '
          'trying to act casual.\n\n'
          'Everyone waiting has the same expression — the one that says '
          'I\'m fine while their knee bounces.\n\n'
          'They\'ll call your name. You\'ll stand up and show them '
          'what you\'ve been practising in your room at night '
          'when you were sure nobody was watching.\n\n'
          '{possessive} hands won\'t stop sweating.',
      choices: [
        QuestChoice(
          id: 'tt_c1a',
          text: 'Find a corner and run through it in your head one more time',
          nextSegmentId: 'tt_mental',
        ),
        QuestChoice(
          id: 'tt_c1b',
          text: 'Watch the people going before you — study them',
          nextSegmentId: 'tt_watch',
        ),
        QuestChoice(
          id: 'tt_c1c',
          text: 'Talk to someone else waiting — break the silence',
          nextSegmentId: 'tt_connect',
        ),
      ],
    ),

    'tt_mental': QuestSegment(
      id: 'tt_mental',
      content:
          'You close your eyes and run through it. Every beat, every word, '
          'every moment you\'ve rehearsed. It flows perfectly in your head — '
          'it always does in your head.\n\n'
          'Then they call your name.\n\n'
          'You stand up. The room is smaller than you remembered from the doorway '
          'and bigger once you\'re standing in it. '
          'You can feel everyone\'s eyes like a physical thing.\n\n'
          'The first moment is the hardest. Your throat closes '
          'and for one terrible second you can\'t remember how it starts.',
      choices: [
        QuestChoice(
          id: 'tt_c2a',
          text: 'Breathe, find the beginning, and begin',
          nextSegmentId: 'tt_through',
        ),
        QuestChoice(
          id: 'tt_c2b',
          text: 'Ask for a second to collect yourself',
          nextSegmentId: 'tt_pause',
        ),
      ],
    ),

    'tt_watch': QuestSegment(
      id: 'tt_watch',
      content:
          'You watch. One person goes too fast, nerves running away with them. '
          'Another is so polished they seem barely human.\n\n'
          'And then there\'s someone who stumbles in the middle — '
          'stops, breathes, starts again — and somehow that\'s the one '
          'you can\'t look away from. That one felt real.\n\n'
          'They call your name. You\'ve learned something '
          'watching all of them: being perfect isn\'t the same as being good.',
      choices: [
        QuestChoice(
          id: 'tt_c3a',
          text: 'Go in aiming for real, not perfect',
          nextSegmentId: 'tt_through',
        ),
        QuestChoice(
          id: 'tt_c3b',
          text: 'Try to be flawless — you\'ve seen what mistakes look like',
          nextSegmentId: 'tt_overcontrol',
        ),
      ],
    ),

    'tt_connect': QuestSegment(
      id: 'tt_connect',
      content:
          'You lean over to the person next to you. '
          '"Have you done one of these before?"\n\n'
          'They shake their head. "First time. You?"\n\n'
          '"Same."\n\n'
          'That\'s all. But the silence after it is different — '
          'easier, shared. Two people in the same boat, '
          'both pretending they\'re not terrified.\n\n'
          'When they call your name, you feel slightly less alone going up there.',
      choices: [
        QuestChoice(
          id: 'tt_c4a',
          text: 'Go in carrying that feeling — you\'re not the only one',
          nextSegmentId: 'tt_through',
        ),
        QuestChoice(
          id: 'tt_c4b',
          text: 'Go in trying to forget everything and just focus',
          nextSegmentId: 'tt_through',
        ),
      ],
    ),

    'tt_through': QuestSegment(
      id: 'tt_through',
      content:
          'You get through it.\n\n'
          'Not perfectly. There\'s a moment somewhere in the middle '
          'where you feel the wobble — the catch, the half-second '
          'where the whole thing almost unravels. '
          'But you breathe through it. You keep going.\n\n'
          'When you finish, the room is quiet for a beat '
          'before the polite applause.\n\n'
          'You don\'t know if it was enough. That\'s the thing '
          'about tryouts — you never know in the room.',
      choices: [
        QuestChoice(
          id: 'tt_c5a',
          text: 'Walk out with your head up — you showed up, that\'s real',
          nextSegmentId: 'tt_end_good',
        ),
        QuestChoice(
          id: 'tt_c5b',
          text: 'Replay every mistake in your head on the way out',
          nextSegmentId: 'tt_end_spiral',
        ),
      ],
    ),

    'tt_overcontrol': QuestSegment(
      id: 'tt_overcontrol',
      content:
          'You go in tight. Everything controlled. No mistakes.\n\n'
          'And you\'re right — there are no mistakes. '
          'But there\'s also no breath in it, no risk. '
          'You can feel yourself holding back, playing it safe, '
          'choosing the version that can\'t fail rather than '
          'the version that could be great.\n\n'
          'When you finish, the judges smile and make a note. '
          'You can\'t read it.',
      choices: [
        QuestChoice(
          id: 'tt_c6a',
          text: 'Tell yourself it was the right call — safety first',
          nextSegmentId: 'tt_end_safe',
        ),
        QuestChoice(
          id: 'tt_c6b',
          text: 'Wish you\'d taken the risk — file it away for next time',
          nextSegmentId: 'tt_end_learn',
        ),
      ],
    ),

    'tt_pause': QuestSegment(
      id: 'tt_pause',
      content:
          '"Could I have just a second?" you ask.\n\n'
          'The judge nods. A beat of silence, longer than a heartbeat, '
          'shorter than it felt.\n\n'
          'You breathe. Find the beginning. Begin.\n\n'
          'The pause cost you three seconds. What it gave you was '
          'the ability to actually be present for what came after.\n\n'
          'That was the right call.',
      choices: [
        QuestChoice(
          id: 'tt_c7a',
          text: 'Walk out knowing you handled that like a professional',
          nextSegmentId: 'tt_end_good',
        ),
      ],
    ),

    'tt_end_good': QuestSegment(
      id: 'tt_end_good',
      content:
          'The waiting is its own thing. A different kind of hard.\n\n'
          'But here\'s what you know for certain, regardless of what comes back: '
          'three weeks ago you were standing in front of a sign-up sheet '
          'that you almost didn\'t touch. Today you stood in the room.\n\n'
          'That\'s not a small thing. That\'s the whole thing, really. '
          'Everything else is just outcome.',
      isEnding: true,
    ),

    'tt_end_spiral': QuestSegment(
      id: 'tt_end_spiral',
      content:
          'You replay it. The wobble. The half-second catch. '
          'What you should have done instead.\n\n'
          'You could do that for the rest of the afternoon, or you could '
          'notice that you actually got through it — '
          'that the wobble happened and the world didn\'t end.\n\n'
          'Every person who gets good at something has a long list '
          'of moments exactly like the one you just had. '
          'They\'re not evidence that you can\'t do this. '
          'They\'re the doing of it.',
      isEnding: true,
    ),

    'tt_end_safe': QuestSegment(
      id: 'tt_end_safe',
      content:
          'Maybe. Or maybe you\'ll never know.\n\n'
          'The thing about playing it safe is that you don\'t fail — '
          'but you also don\'t find out what you\'re actually capable of.\n\n'
          'There\'ll be another tryout. Another room. '
          'Another chance to find out what happens '
          'when you let it be a little less controlled.\n\n'
          'You don\'t have to decide today.',
      isEnding: true,
    ),

    'tt_end_learn': QuestSegment(
      id: 'tt_end_learn',
      content:
          'Good. File it.\n\n'
          'The fact that you know the difference — between the version '
          'that can\'t fail and the version that could be great — '
          'means you\'re already further along than you think.\n\n'
          'Most people spend years before they can even '
          'name what they held back.\n\n'
          'Next time, you\'ll know what to reach for.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// EXPLORER QUEST 3: Three's a Crowd
// ═══════════════════════════════════════════════════════════════════════════════

const questThreeCrowd = LifeQuestScenario(
  id: 'three_crowd',
  title: "Three's a Crowd",
  hook: 'Your best friend is playing with someone else.',
  emoji: '\u{1F641}',
  emotions: ['sad', 'worried', 'angry'],
  recommendedBands: [AgeBand.explorer],
  startSegmentId: 'tc_start',
  segments: {
    'tc_start': QuestSegment(
      id: 'tc_start',
      content:
          'You walk out to the playground and look for your best friend.\n\n'
          'You spot {pronoun} over by the climbing frame — '
          'but {pronoun}\'s not alone. '
          'There\'s a new kid laughing next to {pronoun}, '
          'and they\'re already doing some kind of silly handshake '
          'you\'ve never seen before.\n\n'
          'Your tummy feels tight. '
          'That was supposed to be YOUR spot. '
          'YOUR friend.\n\n'
          '«{companion} walks up beside you. '
          '"You okay?" {companion} asks quietly. »\n\n'
          'What do you do?',
      copingBreakId: 'belly_breath',
      choices: [
        QuestChoice(
          id: 'tc_go_over',
          text: 'Walk over and say hi.',
          nextSegmentId: 'tc_go_over',
        ),
        QuestChoice(
          id: 'tc_hang_back',
          text: 'Stay where you are and wait.',
          nextSegmentId: 'tc_hang_back',
        ),
      ],
    ),

    'tc_go_over': QuestSegment(
      id: 'tc_go_over',
      content:
          'You take a big breath and walk over.\n\n'
          '"Hi," you say. Your voice comes out smaller than you wanted.\n\n'
          'Your friend\'s face lights up. '
          '"Oh! This is {name}!" {Pronoun} turns to the new kid. '
          '"This is my best friend!"\n\n'
          'The new kid smiles at you. "Cool. Want to see the handshake?"\n\n'
          'You\'re still a little wobbly inside — '
          'but a tiny bit of the tight feeling starts to loosen.',
      choices: [
        QuestChoice(
          id: 'tc_join',
          text: 'Try to learn the handshake.',
          nextSegmentId: 'tc_end_join',
        ),
        QuestChoice(
          id: 'tc_ask_alone',
          text: 'Ask your friend if you can talk privately for a sec.',
          nextSegmentId: 'tc_end_ask_alone',
        ),
      ],
    ),

    'tc_hang_back': QuestSegment(
      id: 'tc_hang_back',
      content:
          'You stay back and watch.\n\n'
          'They\'re laughing a lot. '
          'Your friend doesn\'t look over, not even once.\n\n'
          'The tight feeling gets a bit bigger. '
          'You wonder if {pronoun} even notices you\'re not there.\n\n'
          '«{companion} gently bumps your arm. »\n\n'
          'Waiting isn\'t really working. What do you do?',
      choices: [
        QuestChoice(
          id: 'tc_go_over_late',
          text: 'Walk over now.',
          nextSegmentId: 'tc_end_go_over_late',
        ),
        QuestChoice(
          id: 'tc_find_someone',
          text: 'Find something else to do for now.',
          nextSegmentId: 'tc_end_find_someone',
        ),
      ],
    ),

    'tc_end_join': QuestSegment(
      id: 'tc_end_join',
      content:
          'You mess up the handshake three times, '
          'and on the fourth try you finally get it.\n\n'
          'You all cheer. Your friend squeezes your arm.\n\n'
          'It still feels a little strange — '
          'like the playground got rearranged while you weren\'t looking. '
          'But strange doesn\'t always mean bad.\n\n'
          'Sometimes your circle just gets a little bigger.',
      isEnding: true,
    ),

    'tc_end_ask_alone': QuestSegment(
      id: 'tc_end_ask_alone',
      content:
          'You and your friend step a little bit away.\n\n'
          '"I just felt kind of left out," you say.\n\n'
          'Your friend looks surprised. "I didn\'t mean to do that. '
          'I was going to find you at lunch!"\n\n'
          'It helps to hear that. '
          'You didn\'t know what {pronoun} was thinking — '
          'but now you do.\n\n'
          'Saying the hard thing out loud made it smaller.',
      isEnding: true,
    ),

    'tc_end_go_over_late': QuestSegment(
      id: 'tc_end_go_over_late',
      content:
          'You walk over, and your friend immediately waves you in.\n\n'
          '"Where were you? I kept looking for you!"\n\n'
          'Oh. {Pronoun} was looking.\n\n'
          'You just couldn\'t tell from far away.\n\n'
          'Sometimes things look different up close '
          'than they do from across the playground.',
      isEnding: true,
    ),

    'tc_end_find_someone': QuestSegment(
      id: 'tc_end_find_someone',
      content:
          'You find something else to do — '
          'a ball game, a book, a quiet spot by the fence.\n\n'
          'It\'s okay. Not every playtime has to be with the same person.\n\n'
          'At the end of lunch, your friend runs over. '
          '"Are you mad at me?"\n\n'
          '"A little," you say honestly.\n\n'
          '{Pronoun} smiled. '
          '"Let\'s sit together after school. Just us."\n\n'
          'That helps.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// EXPLORER QUEST 4: I Didn't Mean To
// ═══════════════════════════════════════════════════════════════════════════════

const questBrokenThing = LifeQuestScenario(
  id: 'broken_thing',
  title: "I Didn't Mean To",
  hook: 'You broke something. Now you have to decide what to do.',
  emoji: '\u{1F625}',
  emotions: ['scared', 'worried', 'sad'],
  recommendedBands: [AgeBand.explorer],
  startSegmentId: 'bt_start',
  segments: {
    'bt_start': QuestSegment(
      id: 'bt_start',
      content:
          'It happened so fast.\n\n'
          'One second you were just reaching for something, '
          'and then there was a crash, and now there\'s a broken thing '
          'on the floor in front of you.\n\n'
          'Your heart is going really fast.\n\n'
          'You didn\'t mean to. It was an accident. '
          'But it\'s still broken.\n\n'
          '«{companion} freezes beside you. »\n\n'
          'What do you do?',
      copingBreakId: 'hot_cocoa_breath',
      choices: [
        QuestChoice(
          id: 'bt_tell',
          text: 'Go and tell a grown-up right now.',
          nextSegmentId: 'bt_tell',
        ),
        QuestChoice(
          id: 'bt_hide',
          text: "Try to hide it or pretend it didn't happen.",
          nextSegmentId: 'bt_hide',
        ),
      ],
    ),

    'bt_tell': QuestSegment(
      id: 'bt_tell',
      content:
          'Your legs feel shaky as you walk over.\n\n'
          '"I broke something," you say. '
          '"It was an accident. I\'m really sorry."\n\n'
          'The grown-up looks at the broken thing. '
          'Then they look at you.\n\n'
          '"Thank you for telling me," they say.\n\n'
          'That\'s it? You were expecting something much worse.\n\n'
          'How does it feel?',
      choices: [
        QuestChoice(
          id: 'bt_end_relief',
          text: 'A huge wave of relief.',
          nextSegmentId: 'bt_end_relief',
        ),
        QuestChoice(
          id: 'bt_end_still_bad',
          text: 'Still bad — even though they were kind about it.',
          nextSegmentId: 'bt_end_still_bad',
        ),
      ],
    ),

    'bt_hide': QuestSegment(
      id: 'bt_hide',
      content:
          'You push the pieces out of sight and walk away.\n\n'
          'But the bad feeling doesn\'t go away. '
          'It follows you all morning, sitting in your stomach like a stone.\n\n'
          'At lunch you can\'t really eat. '
          'You keep thinking someone is about to find out.\n\n'
          '«{companion} looks at you. "You seem really worried." »\n\n'
          'What do you do?',
      choices: [
        QuestChoice(
          id: 'bt_tell_late',
          text: "Go tell the truth — even though it's late.",
          nextSegmentId: 'bt_end_tell_late',
        ),
        QuestChoice(
          id: 'bt_keep_hiding',
          text: 'Try to keep it secret.',
          nextSegmentId: 'bt_end_keep_hiding',
        ),
      ],
    ),

    'bt_end_relief': QuestSegment(
      id: 'bt_end_relief',
      content:
          'You breathe out the longest breath.\n\n'
          'The whole thing was still scary — '
          'but it was over in two minutes '
          'instead of sitting in your tummy all day.\n\n'
          'Telling the truth when something goes wrong '
          'is one of the hardest things. '
          'You did it.\n\n'
          'That matters.',
      isEnding: true,
    ),

    'bt_end_still_bad': QuestSegment(
      id: 'bt_end_still_bad',
      content:
          'Sometimes even when things go okay, '
          'it still takes a while for the wobbly feeling to calm down.\n\n'
          'That\'s normal.\n\n'
          'Your body was ready for something scary, '
          'and it needs a little time to notice the scary part didn\'t come.\n\n'
          'You told the truth. That was brave.',
      isEnding: true,
    ),

    'bt_end_tell_late': QuestSegment(
      id: 'bt_end_tell_late',
      content:
          'It takes a lot of courage to walk back and say it.\n\n'
          '"I broke something earlier," you say. '
          '"I was scared to tell you. I\'m sorry I waited."\n\n'
          'The grown-up nods. '
          '"It means a lot that you came back and told me."\n\n'
          'Late is not the same as never.\n\n'
          'You did the right thing.',
      isEnding: true,
    ),

    'bt_end_keep_hiding': QuestSegment(
      id: 'bt_end_keep_hiding',
      content:
          'Keeping a secret like this is really hard work.\n\n'
          'It takes up a lot of brain space that could be used for '
          'things that are actually fun.\n\n'
          'The thing is — it\'s never too late to tell the truth. '
          'Even tomorrow. Even next week.\n\n'
          'When you\'re ready, the option is still there.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// EXPLORER QUEST 5: It's Not Fair
// ═══════════════════════════════════════════════════════════════════════════════

const questNotFair = LifeQuestScenario(
  id: 'not_fair',
  title: "It's Not Fair",
  hook: 'Someone else got picked. Why not you?',
  emoji: '\u{1F621}',
  emotions: ['angry', 'frustrated', 'sad'],
  recommendedBands: [AgeBand.explorer],
  startSegmentId: 'nf_start',
  segments: {
    'nf_start': QuestSegment(
      id: 'nf_start',
      content:
          'The teacher says the name — and it isn\'t yours.\n\n'
          'It should have been yours. You worked hard. '
          'You had your hand up. '
          'You\'ve been waiting for this all week.\n\n'
          'Hot angry feelings rush up into your face.\n\n'
          'It\'s not fair.\n\n'
          '«{companion} glances over at you. »\n\n'
          'What do you do with all that feeling?',
      copingBreakId: 'dragon_breath',
      choices: [
        QuestChoice(
          id: 'nf_say_it',
          text: "Say \"That's not fair!\" out loud.",
          nextSegmentId: 'nf_say_it',
        ),
        QuestChoice(
          id: 'nf_swallow',
          text: 'Push the feeling down and say nothing.',
          nextSegmentId: 'nf_swallow',
        ),
      ],
    ),

    'nf_say_it': QuestSegment(
      id: 'nf_say_it',
      content:
          'The words come out before you can stop them.\n\n'
          '"That\'s not fair!"\n\n'
          'The room goes a little quiet. '
          'Everyone is looking at you now. '
          'Your face gets even hotter.\n\n'
          'The teacher looks at you steadily. '
          '"Can you tell me more about why you feel that way?"\n\n'
          'What do you say?',
      choices: [
        QuestChoice(
          id: 'nf_explain',
          text: "Explain calmly that you've been waiting and worked hard.",
          nextSegmentId: 'nf_end_explain',
        ),
        QuestChoice(
          id: 'nf_embarrassed',
          text: 'Go quiet — you feel embarrassed now.',
          nextSegmentId: 'nf_end_embarrassed',
        ),
      ],
    ),

    'nf_swallow': QuestSegment(
      id: 'nf_swallow',
      content:
          'You press your lips together and look at your desk.\n\n'
          'The hot feeling is still there. '
          'It doesn\'t go away just because you didn\'t say it.\n\n'
          'It sort of... sits there.\n\n'
          'By the end of the lesson you still feel bad, '
          'and now you also feel tired from holding it all in.\n\n'
          'What do you do next?',
      choices: [
        QuestChoice(
          id: 'nf_tell_someone',
          text: "Tell a friend or a grown-up how you're feeling.",
          nextSegmentId: 'nf_end_tell_someone',
        ),
        QuestChoice(
          id: 'nf_let_go',
          text: 'Try to let it go and think about something else.',
          nextSegmentId: 'nf_end_let_go',
        ),
      ],
    ),

    'nf_end_explain': QuestSegment(
      id: 'nf_end_explain',
      content:
          'You take a breath. '
          '"I\'ve had my hand up a lot, and I\'ve been practising. '
          'I just really wanted this one."\n\n'
          'The teacher nods. '
          '"I hear you. I\'ll make sure you get a turn soon."\n\n'
          'That\'s not everything you wanted. '
          'But it\'s something.\n\n'
          'Saying what you need, calmly, is a very hard skill. '
          'You\'re getting better at it.',
      isEnding: true,
    ),

    'nf_end_embarrassed': QuestSegment(
      id: 'nf_end_embarrassed',
      content:
          'You shake your head and look down.\n\n'
          'The big feeling came out and now you wish it hadn\'t.\n\n'
          'That\'s okay. It happens to everyone.\n\n'
          'Big feelings are strong — '
          'they\'re faster than the thinking part of your brain sometimes.\n\n'
          'Next time, you\'ll have a tiny bit more practice '
          'catching them before they get out.',
      isEnding: true,
    ),

    'nf_end_tell_someone': QuestSegment(
      id: 'nf_end_tell_someone',
      content:
          '"It wasn\'t fair," you say. "I\'m really annoyed."\n\n'
          'The person you\'re talking to nods. "That sounds really frustrating."\n\n'
          'Just having someone understand makes the feeling smaller.\n\n'
          'Feelings don\'t always need to be fixed — '
          'sometimes they just need to be heard.',
      isEnding: true,
    ),

    'nf_end_let_go': QuestSegment(
      id: 'nf_end_let_go',
      content:
          'You think about something you\'re looking forward to. '
          'Lunch. Home time. A game you want to play.\n\n'
          'Little by little, the hot feeling cools.\n\n'
          'Not every unfair thing can be fixed right away. '
          'Sometimes letting it settle is the best move you\'ve got.\n\n'
          'And that\'s okay too.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// EXPLORER QUEST 6: Goodnight from Far Away
// ═══════════════════════════════════════════════════════════════════════════════

const questSleepover = LifeQuestScenario(
  id: 'sleepover',
  title: 'Goodnight from Far Away',
  hook: 'Everyone else seems fine. You just want to go home.',
  emoji: '\u{1F319}',
  emotions: ['sad', 'scared', 'worried'],
  recommendedBands: [AgeBand.explorer],
  startSegmentId: 'gf_start',
  segments: {
    'gf_start': QuestSegment(
      id: 'gf_start',
      content:
          'The lights go off. '
          'Sleeping bags rustle. '
          'Someone giggles in the dark.\n\n'
          'Everyone else seems fine.\n\n'
          'You are not fine.\n\n'
          'The missing feeling has been creeping in since dinner — '
          'something that feels like homesick, '
          'something that feels like you just want your own bed '
          'and your own things and maybe a hug '
          'from someone who knows you really well.\n\n'
          '«{companion} is in the sleeping bag next to yours. »\n\n'
          'What do you do?',
      choices: [
        QuestChoice(
          id: 'gf_try',
          text: 'Try to go to sleep and see if the feeling passes.',
          nextSegmentId: 'gf_try',
        ),
        QuestChoice(
          id: 'gf_tell_friend',
          text: "Whisper to the friend whose house it is.",
          nextSegmentId: 'gf_tell_friend',
        ),
      ],
    ),

    'gf_try': QuestSegment(
      id: 'gf_try',
      content:
          'You squeeze your eyes shut and try to make your brain be quiet.\n\n'
          'It doesn\'t really work. '
          'You think about your bedroom. '
          'You think about your mum or dad or whoever tucks you in. '
          'You think about your pet, '
          'or your favourite corner of the sofa.\n\n'
          'The missing feeling gets bigger, not smaller.\n\n'
          '«{companion} whispers, "You okay?" »\n\n'
          'What do you do now?',
      copingBreakId: 'star_breath',
      choices: [
        QuestChoice(
          id: 'gf_call',
          text: 'Ask a grown-up if you can call home.',
          nextSegmentId: 'gf_end_call',
        ),
        QuestChoice(
          id: 'gf_keep_trying',
          text: 'Keep trying — you want to stay the whole night.',
          nextSegmentId: 'gf_end_keep_trying',
        ),
      ],
    ),

    'gf_tell_friend': QuestSegment(
      id: 'gf_tell_friend',
      content:
          '"I feel a bit homesick," you whisper.\n\n'
          'There\'s a pause. '
          'Then your friend whispers back: '
          '"I felt like that at my cousin\'s house once. '
          'It went away after a bit."\n\n'
          'You didn\'t know that. '
          'It helps to know you\'re not the only one.\n\n'
          'How are you feeling?',
      choices: [
        QuestChoice(
          id: 'gf_talk',
          text: "Talk quietly for a little while — it's helping.",
          nextSegmentId: 'gf_end_talk',
        ),
        QuestChoice(
          id: 'gf_call_from_friend',
          text: 'Ask your friend to help you find a grown-up.',
          nextSegmentId: 'gf_end_call',
        ),
      ],
    ),

    'gf_end_call': QuestSegment(
      id: 'gf_end_call',
      content:
          'A grown-up passes you the phone.\n\n'
          'You hear the voice you needed to hear. '
          'It\'s just a few words — '
          '"We love you. You\'re doing great." — '
          'but something in your chest untwists.\n\n'
          'You hand the phone back and get into your sleeping bag.\n\n'
          'It\'s still not home. But it feels a little more okay now.\n\n'
          'Asking for help isn\'t giving up. '
          'It\'s knowing what you need.',
      isEnding: true,
    ),

    'gf_end_keep_trying': QuestSegment(
      id: 'gf_end_keep_trying',
      content:
          'You stay curled up and keep breathing slowly.\n\n'
          'Slowly, slowly, the room feels a tiny bit less strange. '
          'The sounds around you start to feel like background, not alarm.\n\n'
          'You don\'t know exactly when it happened, '
          'but at some point you fell asleep.\n\n'
          'In the morning, someone passes you a pancake '
          'and you feel like yourself again.\n\n'
          'You made it.',
      isEnding: true,
    ),

    'gf_end_talk': QuestSegment(
      id: 'gf_end_talk',
      content:
          'You talk quietly about small things — '
          'favourite animals, weird dreams, what you want for breakfast.\n\n'
          'The homesick feeling doesn\'t disappear, '
          'but it gets softer and smaller '
          'as the talking fills up the quiet dark.\n\n'
          'You drift off mid-sentence.\n\n'
          'Sometimes the best cure for missing home '
          'is just having company.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// EXPLORER QUEST 7: My Turn to Talk
// ═══════════════════════════════════════════════════════════════════════════════

const questMyTurnTalk = LifeQuestScenario(
  id: 'my_turn_talk',
  title: 'My Turn to Talk',
  hook: 'Everyone is about to look at you. All at once.',
  emoji: '\u{1F62C}',
  emotions: ['scared', 'worried', 'excited'],
  recommendedBands: [AgeBand.explorer],
  startSegmentId: 'mtt_start',
  segments: {
    'mtt_start': QuestSegment(
      id: 'mtt_start',
      content:
          'The teacher calls your name.\n\n'
          'This is it. Your turn to stand up and talk to the class.\n\n'
          'Your heart is going VERY fast. '
          'Your hands feel a little bit sweaty. '
          'All the faces in the room are turning toward you.\n\n'
          '«{companion} gives you a quick encouraging nod. »\n\n'
          'You stand up. '
          'What do you do first?',
      choices: [
        QuestChoice(
          id: 'mtt_back_wall',
          text: "Look at the back wall — not at anyone's face.",
          nextSegmentId: 'mtt_back_wall',
        ),
        QuestChoice(
          id: 'mtt_friendly_face',
          text: 'Find one friendly face and look at that person.',
          nextSegmentId: 'mtt_friendly_face',
        ),
      ],
    ),

    'mtt_back_wall': QuestSegment(
      id: 'mtt_back_wall',
      content:
          'You focus on a spot above everyone\'s heads.\n\n'
          'You start talking. Your voice shakes a little at first. '
          'Then it gets steadier.\n\n'
          'Mostly you\'re just saying the words, one after another, '
          'until they\'re all gone.\n\n'
          'How does it go?',
      choices: [
        QuestChoice(
          id: 'mtt_strong_finish',
          text: "You get to the end — and it wasn't as bad as you thought.",
          nextSegmentId: 'mtt_end_strong_finish',
        ),
        QuestChoice(
          id: 'mtt_lose_place',
          text: 'You lose your place and go blank for a second.',
          nextSegmentId: 'mtt_lose_place',
        ),
      ],
    ),

    'mtt_friendly_face': QuestSegment(
      id: 'mtt_friendly_face',
      content:
          'You find someone who looks kind — '
          'a friend, or someone who\'s smiling at you.\n\n'
          'You talk to them. Just them. '
          'Like it\'s a normal conversation, not a performance.\n\n'
          'The rest of the room sort of blurs at the edges.\n\n'
          'How does it go?',
      choices: [
        QuestChoice(
          id: 'mtt_strong_finish',
          text: "You get to the end — and it wasn't as bad as you thought.",
          nextSegmentId: 'mtt_end_strong_finish',
        ),
        QuestChoice(
          id: 'mtt_lose_place',
          text: 'You lose your place and go blank for a second.',
          nextSegmentId: 'mtt_lose_place',
        ),
      ],
    ),

    'mtt_lose_place': QuestSegment(
      id: 'mtt_lose_place',
      content:
          'Oh no. You had it — and now you don\'t.\n\n'
          'The blank is just a few seconds, but it feels like forever.\n\n'
          'What do you do?',
      choices: [
        QuestChoice(
          id: 'mtt_pause_recover',
          text: 'Take a breath. Find your place. Keep going.',
          nextSegmentId: 'mtt_end_recover',
        ),
        QuestChoice(
          id: 'mtt_rush_finish',
          text: 'Rush to the end as fast as you can.',
          nextSegmentId: 'mtt_end_rush',
        ),
      ],
    ),

    'mtt_end_strong_finish': QuestSegment(
      id: 'mtt_end_strong_finish',
      content:
          'You finish. You sit down.\n\n'
          'Your heart is still going fast — '
          'but a different kind of fast. '
          'The kind that happens after something hard '
          'that you actually did.\n\n'
          '«{companion} grins at you. »\n\n'
          'The thing you were most scared of? '
          'You just did it.',
      isEnding: true,
    ),

    'mtt_end_recover': QuestSegment(
      id: 'mtt_end_recover',
      content:
          'You find the words again and keep going.\n\n'
          'Maybe one or two people noticed. '
          'Most didn\'t.\n\n'
          'Everyone who has ever talked in front of a class '
          'has had a blank moment. '
          'The ones who are good at it are the ones '
          'who learned to breathe and carry on.\n\n'
          'That\'s what you just did.',
      isEnding: true,
    ),

    'mtt_end_rush': QuestSegment(
      id: 'mtt_end_rush',
      content:
          'You tumble through the last bit really fast '
          'and sit down hard.\n\n'
          'Phew. Over.\n\n'
          'It wasn\'t perfect. '
          'But you got through it — '
          'and getting through it is the whole point.\n\n'
          'Every time you do this, '
          'it gets just a little bit less scary. '
          'Even the messy times count.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// CREATOR QUEST 1: The Group Chat
// ═══════════════════════════════════════════════════════════════════════════════

const questGroupChat = LifeQuestScenario(
  id: 'group_chat',
  title: 'The Group Chat',
  hook: 'You said something. The replies stopped.',
  emoji: '\u{1F4F1}',
  emotions: ['worried', 'embarrassed', 'sad'],
  recommendedBands: [AgeBand.creator],
  startSegmentId: 'gc_start',
  segments: {
    'gc_start': QuestSegment(
      id: 'gc_start',
      content:
          'You typed it fast. A joke — or what you thought was a joke.\n\n'
          'It landed in the group chat and then... nothing. '
          'The typing bubbles that were bouncing a second ago '
          'have gone still. Thirty people in this chat '
          'and not one of them is typing.\n\n'
          'You scroll back up and read your message again. '
          'It reads differently now. Harsher. '
          'You can see how someone could take it the wrong way.\n\n'
          '«{companion} texts you privately: "uh, that came out weird" »\n\n'
          'Your face is burning. What do you do?',
      choices: [
        QuestChoice(
          id: 'gc_fix',
          text: 'Send a follow-up: "that came out wrong, sorry"',
          nextSegmentId: 'gc_fix',
        ),
        QuestChoice(
          id: 'gc_wait',
          text: 'Put the phone down and wait it out.',
          nextSegmentId: 'gc_wait',
        ),
      ],
    ),

    'gc_fix': QuestSegment(
      id: 'gc_fix',
      content:
          'You type: "hey that came out way harsher than I meant, sorry"\n\n'
          'A few seconds pass. Then someone drops a thumbs-up. '
          'Someone else sends a meme. The chat moves on.\n\n'
          'But one person — the one your comment was sort of about — '
          'hasn\'t said anything.\n\n'
          'What do you do?',
      choices: [
        QuestChoice(
          id: 'gc_dm',
          text: 'DM them directly to check in.',
          nextSegmentId: 'gc_end_dm',
        ),
        QuestChoice(
          id: 'gc_leave_it',
          text: 'Leave it — the group moved on, so it must be fine.',
          nextSegmentId: 'gc_end_leave_it',
        ),
      ],
    ),

    'gc_wait': QuestSegment(
      id: 'gc_wait',
      content:
          'You put the phone face-down on your desk.\n\n'
          'Your brain is not face-down. Your brain is replaying '
          'every possible reading of that message on a loop. '
          'Are they talking about you in a different chat right now? '
          'Are they screenshotting it?\n\n'
          'Ten minutes later you check. '
          'Someone\'s changed the subject. '
          'But you can\'t tell if that means it\'s fine '
          'or if everyone just decided to pretend.\n\n'
          'What do you do?',
      choices: [
        QuestChoice(
          id: 'gc_late_apology',
          text: 'Send a late apology — better late than never.',
          nextSegmentId: 'gc_end_late_apology',
        ),
        QuestChoice(
          id: 'gc_in_person',
          text: 'Talk to the person face-to-face tomorrow.',
          nextSegmentId: 'gc_end_in_person',
        ),
      ],
    ),

    'gc_end_dm': QuestSegment(
      id: 'gc_end_dm',
      content:
          '"Hey, I\'m sorry about what I said in the chat. '
          'I didn\'t mean it that way."\n\n'
          'They take a minute to reply. Then: '
          '"It\'s okay. It did sting a bit but I know you didn\'t mean it."\n\n'
          'That was hard to send. '
          'But the relief of knowing where you actually stand with someone '
          'is worth the thirty seconds of vulnerability.\n\n'
          'Text is tricky. Tone doesn\'t travel well through a screen. '
          'But owning it quickly does.',
      isEnding: true,
    ),

    'gc_end_leave_it': QuestSegment(
      id: 'gc_end_leave_it',
      content:
          'Maybe it is fine. Maybe they barely noticed.\n\n'
          'Or maybe they\'re doing the same thing you\'re doing — '
          'staring at their phone, wondering whether they overreacted.\n\n'
          'The thing about text is that silence can mean "no worries" '
          'or it can mean "I\'m hurt and I don\'t know how to say it." '
          'You can\'t always tell which.\n\n'
          'If the uneasy feeling is still there tomorrow, '
          'it might be worth a quick word in person.',
      isEnding: true,
    ),

    'gc_end_late_apology': QuestSegment(
      id: 'gc_end_late_apology',
      content:
          'You type it out. Delete it. Type it again. Hit send.\n\n'
          '"Hey, that thing I said earlier — I\'m sorry. '
          'It wasn\'t what I meant."\n\n'
          'Someone replies: "oh lol I already forgot about that"\n\n'
          'Maybe they did. Maybe they\'re being kind. '
          'Either way, you said the thing that was sitting on your chest, '
          'and it\'s lighter now.\n\n'
          'Late apologies still count.',
      isEnding: true,
    ),

    'gc_end_in_person': QuestSegment(
      id: 'gc_end_in_person',
      content:
          'The next day you find them by the lockers.\n\n'
          '"Hey — about what I said in the group chat. '
          'It came out wrong. I\'m sorry."\n\n'
          'They look surprised. "Oh. Thanks for saying that."\n\n'
          'In person is harder than text. '
          'You can\'t edit, you can\'t delete, '
          'you have to look at their actual face.\n\n'
          'But that\'s also why it lands differently. '
          'It means more because it costs more.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// CREATOR QUEST 2: My Work, My Way
// ═══════════════════════════════════════════════════════════════════════════════

const questMyWorkMyWay = LifeQuestScenario(
  id: 'my_work_my_way',
  title: 'My Work, My Way',
  hook: 'You made something you care about. Someone just laughed at it.',
  emoji: '\u{1F3A8}',
  emotions: ['sad', 'angry', 'embarrassed'],
  recommendedBands: [AgeBand.creator],
  startSegmentId: 'mw_start',
  segments: {
    'mw_start': QuestSegment(
      id: 'mw_start',
      content:
          'You worked on this for days. '
          'It\'s not perfect — you know that — '
          'but it\'s yours, and when you look at it you feel something.\n\n'
          'Then someone in class glances at it and says, '
          '"Wait, that\'s what you\'re handing in?"\n\n'
          'A couple of people laugh. Not everyone. '
          'But enough.\n\n'
          'The thing you were proud of five minutes ago '
          'now feels like it\'s shrinking in your hands.\n\n'
          '«{companion} is watching from across the room. »\n\n'
          'What do you do?',
      choices: [
        QuestChoice(
          id: 'mw_defend',
          text: 'Say something back — stand up for your work.',
          nextSegmentId: 'mw_defend',
        ),
        QuestChoice(
          id: 'mw_fold',
          text: 'Flip it over so nobody else can see.',
          nextSegmentId: 'mw_fold',
        ),
      ],
    ),

    'mw_defend': QuestSegment(
      id: 'mw_defend',
      content:
          '"I actually like it," you say.\n\n'
          'It comes out quieter than you wanted, '
          'but you said it. The person who laughed shrugs '
          'and looks away.\n\n'
          'Your heart is hammering. '
          'You\'re not sure if that was brave or stupid.\n\n'
          'How do you feel about your work now?',
      choices: [
        QuestChoice(
          id: 'mw_still_proud',
          text: 'I still like it. Their opinion is their opinion.',
          nextSegmentId: 'mw_end_still_proud',
        ),
        QuestChoice(
          id: 'mw_doubt',
          text: 'I don\'t know anymore. Maybe they saw something I didn\'t.',
          nextSegmentId: 'mw_end_doubt',
        ),
      ],
    ),

    'mw_fold': QuestSegment(
      id: 'mw_fold',
      content:
          'You turn it over, face-down. '
          'The laughter fades into normal classroom noise.\n\n'
          'But the feeling doesn\'t fade. '
          'Something that was open is closed now, '
          'and you\'re the one who closed it.\n\n'
          '«{companion} comes over. "Can I see it?" »\n\n'
          'What do you do?',
      choices: [
        QuestChoice(
          id: 'mw_show_friend',
          text: 'Show it — to someone you trust.',
          nextSegmentId: 'mw_end_show_friend',
        ),
        QuestChoice(
          id: 'mw_change_it',
          text: 'Start over. Make something safer.',
          nextSegmentId: 'mw_end_change_it',
        ),
      ],
    ),

    'mw_end_still_proud': QuestSegment(
      id: 'mw_end_still_proud',
      content:
          'Good.\n\n'
          'Here\'s the thing about making something real: '
          'not everyone will get it. '
          'That doesn\'t mean it\'s wrong — '
          'it means it\'s actually yours.\n\n'
          'The stuff that everyone agrees on immediately '
          'is usually the stuff nobody remembers.\n\n'
          'Keep making things that make you feel something.',
      isEnding: true,
    ),

    'mw_end_doubt': QuestSegment(
      id: 'mw_end_doubt',
      content:
          'Doubt is normal after someone laughs at your work. '
          'It doesn\'t mean they\'re right.\n\n'
          'There\'s a difference between useful feedback '
          'and someone who just wants a reaction. '
          'The first one helps you grow. '
          'The second one says nothing about your work '
          'and everything about theirs.\n\n'
          'Give yourself a day. '
          'Then look at your work again with fresh eyes. '
          'You\'ll know.',
      isEnding: true,
    ),

    'mw_end_show_friend': QuestSegment(
      id: 'mw_end_show_friend',
      content:
          'You turn it over, slowly.\n\n'
          'Your friend looks at it properly — '
          'not a glance, not a joke, '
          'an actual look.\n\n'
          '"I really like this part," they say, '
          'pointing to something specific.\n\n'
          'One person who actually looks is worth more '
          'than a roomful of people who don\'t.\n\n'
          'Be careful who you show your real work to. '
          'Not everyone has earned that.',
      isEnding: true,
    ),

    'mw_end_change_it': QuestSegment(
      id: 'mw_end_change_it',
      content:
          'You start again. Something simpler. Something nobody will laugh at.\n\n'
          'It\'s fine. It looks like everyone else\'s.\n\n'
          'And you feel... nothing.\n\n'
          'The original is still in your bag. '
          'It\'s not gone. You can always pull it back out — '
          'today, or next week, or in a month when the sting has faded.\n\n'
          'The work that scares you a little '
          'is usually the work that matters.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// CREATOR QUEST 3: Mirror, Mirror
// ═══════════════════════════════════════════════════════════════════════════════

const questMirrorMirror = LifeQuestScenario(
  id: 'mirror_mirror',
  title: 'Mirror, Mirror',
  hook: 'They make it look so easy. You make it look like trying.',
  emoji: '\u{1FA9E}',
  emotions: ['sad', 'worried', 'embarrassed'],
  recommendedBands: [AgeBand.creator],
  startSegmentId: 'mm_start',
  segments: {
    'mm_start': QuestSegment(
      id: 'mm_start',
      content:
          'You see them every day — that person who just seems '
          'to have it figured out. The right clothes. '
          'The easy laugh. The way people gravitate toward them '
          'like it costs them nothing.\n\n'
          'Then there\'s you, in the bathroom mirror before school, '
          'trying to make your hair do a thing it won\'t do, '
          'wearing the third outfit you\'ve tried on this morning.\n\n'
          'You\'re late now.\n\n'
          '«{companion} is waiting by the door. »\n\n'
          'What goes through your head?',
      choices: [
        QuestChoice(
          id: 'mm_compare',
          text: 'Why can\'t I just look like them?',
          nextSegmentId: 'mm_compare',
        ),
        QuestChoice(
          id: 'mm_stop',
          text: 'This is what I\'ve got. Move.',
          nextSegmentId: 'mm_stop',
        ),
      ],
    ),

    'mm_compare': QuestSegment(
      id: 'mm_compare',
      content:
          'The comparing starts and it doesn\'t stop.\n\n'
          'At school you notice everything — '
          'how they walk, what they eat, '
          'who sits next to them. '
          'Every detail confirms the same thought: '
          'they have something you don\'t.\n\n'
          'By lunch, the inside of your head is exhausting.\n\n'
          'What do you do with this?',
      choices: [
        QuestChoice(
          id: 'mm_talk',
          text: 'Tell someone how you\'re feeling.',
          nextSegmentId: 'mm_end_talk',
        ),
        QuestChoice(
          id: 'mm_examine',
          text: 'Ask yourself what exactly you\'re jealous of.',
          nextSegmentId: 'mm_end_examine',
        ),
      ],
    ),

    'mm_stop': QuestSegment(
      id: 'mm_stop',
      content:
          'You pull on what you had and walk out the door.\n\n'
          'It\'s not a victory — more like a truce. '
          'You don\'t love what you see in the mirror, '
          'but you\'re not going to let it eat your morning.\n\n'
          'At school, something small happens — '
          'someone compliments your shoes, or laughs at your joke, '
          'or chooses you first for something.\n\n'
          'How does that land?',
      choices: [
        QuestChoice(
          id: 'mm_accept_it',
          text: 'Let it in. Maybe I\'m harder on myself than I should be.',
          nextSegmentId: 'mm_end_accept',
        ),
        QuestChoice(
          id: 'mm_dismiss_it',
          text: 'They\'re just being nice. It doesn\'t really count.',
          nextSegmentId: 'mm_end_dismiss',
        ),
      ],
    ),

    'mm_end_talk': QuestSegment(
      id: 'mm_end_talk',
      content:
          '"I just feel like everyone else has it figured out '
          'and I\'m still... figuring."\n\n'
          'The person you\'re talking to is quiet for a second. '
          'Then: "Yeah. Me too, honestly."\n\n'
          'Oh.\n\n'
          'The person you thought had it together '
          'is standing here telling you they don\'t.\n\n'
          'Everyone is comparing themselves to someone. '
          'The question is whether you let it run your day.',
      isEnding: true,
    ),

    'mm_end_examine': QuestSegment(
      id: 'mm_end_examine',
      content:
          'You sit with it. What exactly do they have?\n\n'
          'Confidence? A certain look? The way people respond to them?\n\n'
          'Here\'s the thing: some of that is real. '
          'Some of it is performance. '
          'And some of it is a story you\'re telling yourself '
          'about who they are from the outside.\n\n'
          'You\'re comparing your insides to their outsides. '
          'That\'s never going to be a fair comparison.',
      isEnding: true,
    ),

    'mm_end_accept': QuestSegment(
      id: 'mm_end_accept',
      content:
          'You let the nice thing sit for a moment '
          'instead of explaining it away.\n\n'
          'It doesn\'t fix everything. '
          'The mirror will still be difficult some mornings.\n\n'
          'But maybe the mirror isn\'t the most reliable narrator. '
          'It shows you one angle, frozen, at your most critical moment.\n\n'
          'The people around you are seeing something '
          'the mirror doesn\'t show.',
      isEnding: true,
    ),

    'mm_end_dismiss': QuestSegment(
      id: 'mm_end_dismiss',
      content:
          'You wave it off. Easy to do. '
          'Dismissing compliments is almost automatic by now.\n\n'
          'But notice what you just did: '
          'you accepted the criticism from your own head instantly, '
          'and rejected the kindness from someone else instantly.\n\n'
          'That\'s not honesty. That\'s a habit.\n\n'
          'Habits can change — '
          'but only once you notice them.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// ADOLESCENT QUEST 1: Someone Needs Help
// ═══════════════════════════════════════════════════════════════════════════════

const questSomeoneNeedsHelp = LifeQuestScenario(
  id: 'someone_needs_help',
  title: 'Someone Needs Help',
  hook: 'Your friend hasn\'t been okay. You can see it.',
  emoji: '\u{1F6A8}',
  emotions: ['worried', 'scared', 'sad'],
  recommendedBands: [AgeBand.adolescent],
  startSegmentId: 'sh_start',
  segments: {
    'sh_start': QuestSegment(
      id: 'sh_start',
      content:
          'It\'s been building for weeks.\n\n'
          'Your friend used to be the first person in the group chat, '
          'the one who made plans, the one who showed up early. '
          'Now they cancel everything. They laugh at the wrong moments. '
          'Yesterday they said something that stuck with you — '
          'offhand, almost casual — and you haven\'t been able '
          'to stop thinking about it since.\n\n'
          'You\'re not a therapist. You\'re not their parent. '
          'You\'re sixteen and you\'re scared.\n\n'
          '«{companion} noticed too. '
          '"Should we say something?" {companion} asks. »\n\n'
          'What do you do?',
      choices: [
        QuestChoice(
          id: 'sh_ask',
          text: 'Ask them directly: "Are you okay? Like, really."',
          nextSegmentId: 'sh_ask',
        ),
        QuestChoice(
          id: 'sh_tell_adult',
          text: 'Tell a trusted adult — a teacher, a counsellor, a parent.',
          nextSegmentId: 'sh_tell_adult',
        ),
      ],
    ),

    'sh_ask': QuestSegment(
      id: 'sh_ask',
      content:
          'You find a moment when it\'s just the two of you.\n\n'
          '"Hey. I\'ve noticed you seem really different lately. '
          'Are you actually okay?"\n\n'
          'They go quiet. For a long time. '
          'Then they say: "Not really. No."\n\n'
          'You don\'t know what to say next. '
          'Your heart is pounding.\n\n'
          'What do you do?',
      choices: [
        QuestChoice(
          id: 'sh_listen',
          text: 'Just listen. Don\'t try to fix it.',
          nextSegmentId: 'sh_end_listen',
        ),
        QuestChoice(
          id: 'sh_help_them_get_help',
          text: 'Gently suggest they talk to someone who can actually help.',
          nextSegmentId: 'sh_end_suggest',
        ),
      ],
    ),

    'sh_tell_adult': QuestSegment(
      id: 'sh_tell_adult',
      content:
          'You find a teacher you trust.\n\n'
          '"I\'m worried about someone. '
          'I don\'t know if it\'s serious, but something feels wrong."\n\n'
          'The teacher listens. Takes it seriously. '
          'Says they\'ll look into it.\n\n'
          'You walk away feeling two things at once.\n\n'
          'What hits you first?',
      choices: [
        QuestChoice(
          id: 'sh_relief',
          text: 'Relief — I did the right thing.',
          nextSegmentId: 'sh_end_relief',
        ),
        QuestChoice(
          id: 'sh_guilt',
          text: 'Guilt — what if they find out I told someone?',
          nextSegmentId: 'sh_end_guilt',
        ),
      ],
    ),

    'sh_end_listen': QuestSegment(
      id: 'sh_end_listen',
      content:
          'You sit with them. You don\'t fill the silence.\n\n'
          'They talk, stop, talk again. It comes out in fragments. '
          'You don\'t understand all of it, '
          'but you don\'t need to.\n\n'
          'Sometimes what someone needs isn\'t answers. '
          'It\'s proof that someone noticed.\n\n'
          'You noticed. You asked. You stayed.\n\n'
          'That matters more than you know. '
          'But if what they shared worries you — '
          'it\'s okay to loop in an adult too. '
          'Caring about someone and getting them real help '
          'aren\'t opposites.',
      isEnding: true,
    ),

    'sh_end_suggest': QuestSegment(
      id: 'sh_end_suggest',
      content:
          '"I\'m glad you told me," you say. '
          '"But I think you should talk to someone '
          'who knows more than I do. '
          'A counsellor, or an adult you trust."\n\n'
          'They look away. "I don\'t want to make it a big deal."\n\n'
          '"It already is a big deal," you say quietly. '
          '"That\'s why I\'m asking."\n\n'
          'You\'re not responsible for fixing this. '
          'But pointing someone toward help — '
          'gently, honestly — is one of the most important things '
          'a friend can do.\n\n'
          'You did enough. And it\'s okay to tell an adult yourself '
          'if you\'re still worried.',
      isEnding: true,
    ),

    'sh_end_relief': QuestSegment(
      id: 'sh_end_relief',
      content:
          'You did the right thing.\n\n'
          'It doesn\'t feel triumphant. It feels heavy. '
          'But this is what caring about someone looks like sometimes — '
          'doing the thing that helps them '
          'even when it makes you uncomfortable.\n\n'
          'You\'re not betraying their trust. '
          'You\'re choosing their safety over their secrecy. '
          'That\'s not betrayal — that\'s love.',
      isEnding: true,
    ),

    'sh_end_guilt': QuestSegment(
      id: 'sh_end_guilt',
      content:
          'The guilt is real. You might feel like a snitch, '
          'a bad friend, someone who broke a trust.\n\n'
          'But here\'s what you need to hear: '
          'there are situations where keeping a secret '
          'is more dangerous than telling it.\n\n'
          'If your friend is struggling in a way '
          'that\'s bigger than what a friend can hold — '
          'and you felt that, or you wouldn\'t be here — '
          'then telling someone isn\'t betrayal. '
          'It\'s the hardest, most caring thing you could do.\n\n'
          'They might be angry. They might not understand yet. '
          'But you chose their safety. That took guts.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// ADOLESCENT QUEST 2: The Thing I Didn't Say
// ═══════════════════════════════════════════════════════════════════════════════

const questThingIDidntSay = LifeQuestScenario(
  id: 'thing_i_didnt_say',
  title: "The Thing I Didn't Say",
  hook: 'You saw it happen. You said nothing.',
  emoji: '\u{1F910}',
  emotions: ['worried', 'sad', 'angry'],
  recommendedBands: [AgeBand.adolescent],
  startSegmentId: 'ts_start',
  segments: {
    'ts_start': QuestSegment(
      id: 'ts_start',
      content:
          'It happened in front of you.\n\n'
          'A comment. A push. A joke that wasn\'t a joke. '
          'Someone targeted, someone laughing, '
          'and you — standing right there — '
          'with all the words locked behind your teeth.\n\n'
          'You didn\'t say anything. '
          'Nobody did.\n\n'
          'That was two hours ago and you\'re still carrying it.\n\n'
          '«{companion} was there too. '
          '{companion} hasn\'t mentioned it either. »\n\n'
          'What do you do now?',
      choices: [
        QuestChoice(
          id: 'ts_reach_out',
          text: 'Find the person it happened to. Check on them.',
          nextSegmentId: 'ts_reach_out',
        ),
        QuestChoice(
          id: 'ts_sit_with_it',
          text: 'Sit with the discomfort and think about why you froze.',
          nextSegmentId: 'ts_sit_with_it',
        ),
      ],
    ),

    'ts_reach_out': QuestSegment(
      id: 'ts_reach_out',
      content:
          'You find them. They look tired.\n\n'
          '"Hey. About earlier — that wasn\'t okay. '
          'I\'m sorry I didn\'t say anything."\n\n'
          'They look at you for a long moment. '
          'Then: "Yeah. It wasn\'t."\n\n'
          'There\'s a pause. It\'s not comfortable.\n\n'
          'What do you say?',
      choices: [
        QuestChoice(
          id: 'ts_ask_how',
          text: '"Is there anything I can do?"',
          nextSegmentId: 'ts_end_ask_how',
        ),
        QuestChoice(
          id: 'ts_be_honest',
          text: '"I froze. I want to do better next time."',
          nextSegmentId: 'ts_end_be_honest',
        ),
      ],
    ),

    'ts_sit_with_it': QuestSegment(
      id: 'ts_sit_with_it',
      content:
          'Why did you freeze?\n\n'
          'Fear? You didn\'t want to become the next target.\n'
          'Shock? It happened too fast to process.\n'
          'Social calculus? You weighed the cost of speaking up '
          'and decided, in that split second, that it was too high.\n\n'
          'None of those reasons feel good. '
          'But they\'re honest.\n\n'
          'What matters now?',
      choices: [
        QuestChoice(
          id: 'ts_next_time',
          text: 'Decide what I\'ll do next time.',
          nextSegmentId: 'ts_end_next_time',
        ),
        QuestChoice(
          id: 'ts_report',
          text: 'Report what I saw — even late.',
          nextSegmentId: 'ts_end_report',
        ),
      ],
    ),

    'ts_end_ask_how': QuestSegment(
      id: 'ts_end_ask_how',
      content:
          'They think about it.\n\n'
          '"Honestly? Just... don\'t pretend it didn\'t happen. '
          'Everyone else is acting like it was nothing."\n\n'
          'That\'s the thing about being a bystander — '
          'your silence looks a lot like agreement '
          'from the perspective of the person it happened to.\n\n'
          'You can\'t undo the silence. '
          'But showing up after — acknowledging what happened, '
          'refusing to pretend — that\'s not nothing.',
      isEnding: true,
    ),

    'ts_end_be_honest': QuestSegment(
      id: 'ts_end_be_honest',
      content:
          '"I froze. I want to do better next time."\n\n'
          'They nod slowly. '
          '"At least you\'re being honest about it."\n\n'
          'There\'s something powerful about admitting you fell short '
          'without making excuses. '
          'It doesn\'t erase what happened, '
          'but it changes what happens next.\n\n'
          'The person who recognises their own silence '
          'is more likely to break it next time.',
      isEnding: true,
    ),

    'ts_end_next_time': QuestSegment(
      id: 'ts_end_next_time',
      content:
          'You can\'t script it perfectly. '
          'You can\'t guarantee you\'ll be braver.\n\n'
          'But you can decide, right now, in this calm moment, '
          'what kind of person you want to be '
          'when the next moment isn\'t calm.\n\n'
          'Sometimes it\'s a word. Sometimes it\'s a look. '
          'Sometimes it\'s just standing next to the person afterward '
          'so they know they\'re not alone.\n\n'
          'Courage isn\'t the absence of fear. '
          'It\'s deciding that something else matters more.',
      isEnding: true,
    ),

    'ts_end_report': QuestSegment(
      id: 'ts_end_report',
      content:
          'You find a teacher or counsellor.\n\n'
          '"Something happened earlier and I didn\'t say anything at the time. '
          'But I think someone should know."\n\n'
          'They listen. They ask clarifying questions. '
          'They thank you for coming forward.\n\n'
          'Late is better than never. '
          'The person who speaks up — even after the fact — '
          'is the reason things change.\n\n'
          'It\'s not comfortable. '
          'But it\'s right.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// ADOLESCENT QUEST 3: Where Are You Going?
// ═══════════════════════════════════════════════════════════════════════════════

const questWhereAreYouGoing = LifeQuestScenario(
  id: 'where_are_you_going',
  title: 'Where Are You Going?',
  hook: 'Everyone seems to know their future. You don\'t even know next month.',
  emoji: '\u{1F9ED}',
  emotions: ['worried', 'sad', 'frustrated'],
  recommendedBands: [AgeBand.adolescent],
  startSegmentId: 'way_start',
  segments: {
    'way_start': QuestSegment(
      id: 'way_start',
      content:
          'The question comes at you from every direction.\n\n'
          'Teachers. Parents. Relatives you see once a year. '
          'Even friends — casually, like it\'s simple: '
          '"So what are you going to do after school?"\n\n'
          'Everyone else seems to have an answer. '
          'Medicine. Engineering. Gap year. The army. Something.\n\n'
          'You have: a blank space where the answer should be.\n\n'
          '«{companion} shrugs when you bring it up. '
          '"I don\'t know either," {companion} says, '
          'which helps and doesn\'t help at the same time. »\n\n'
          'Someone asks you again. What do you say?',
      choices: [
        QuestChoice(
          id: 'way_bluff',
          text: 'Make something up so they stop asking.',
          nextSegmentId: 'way_bluff',
        ),
        QuestChoice(
          id: 'way_honest',
          text: '"I don\'t know yet."',
          nextSegmentId: 'way_honest',
        ),
      ],
    ),

    'way_bluff': QuestSegment(
      id: 'way_bluff',
      content:
          '"Probably something with computers," you say, '
          'or "Maybe business," or whatever answer '
          'will end the conversation fastest.\n\n'
          'They nod, satisfied. Move on.\n\n'
          'You\'re off the hook — '
          'but you also feel like a fraud. '
          'You just told someone a version of your future '
          'that you don\'t even believe.\n\n'
          'Later, alone, the real question resurfaces.\n\n'
          'What do you do with it?',
      choices: [
        QuestChoice(
          id: 'way_explore',
          text: 'Think about what you actually enjoy — start there.',
          nextSegmentId: 'way_end_explore',
        ),
        QuestChoice(
          id: 'way_table_it',
          text: 'Decide that not knowing right now is okay.',
          nextSegmentId: 'way_end_table_it',
        ),
      ],
    ),

    'way_honest': QuestSegment(
      id: 'way_honest',
      content:
          '"I don\'t know yet."\n\n'
          'The person\'s face does a thing — '
          'surprise, then maybe a flicker of concern, '
          'then an attempt to be helpful.\n\n'
          '"Well, you\'d better figure it out soon! '
          'Time flies!"\n\n'
          'Thanks. That didn\'t help.\n\n'
          'How do you feel?',
      choices: [
        QuestChoice(
          id: 'way_panicked',
          text: 'Panicked — maybe they\'re right and I\'m behind.',
          nextSegmentId: 'way_end_panicked',
        ),
        QuestChoice(
          id: 'way_steady',
          text: 'Steady — I said the truth and I\'m not ashamed of it.',
          nextSegmentId: 'way_end_steady',
        ),
      ],
    ),

    'way_end_explore': QuestSegment(
      id: 'way_end_explore',
      content:
          'You think about it differently this time.\n\n'
          'Not "what job" but "what pulls me in." '
          'What do you lose time doing? '
          'What problems do you actually care about? '
          'What would you do if nobody was watching or grading?\n\n'
          'You don\'t need the answer today. '
          'But asking better questions '
          'is how you eventually find one.',
      isEnding: true,
    ),

    'way_end_table_it': QuestSegment(
      id: 'way_end_table_it',
      content:
          'You decide, deliberately, to be okay with not knowing.\n\n'
          'Not forever. Not as an excuse. '
          'But as an honest statement about where you are '
          'right now.\n\n'
          'The pressure to have a plan at 16 '
          'is real but manufactured. '
          'Most adults changed direction three times '
          'before they found their thing.\n\n'
          'Not knowing isn\'t failure. '
          'It\'s the starting condition for everyone.',
      isEnding: true,
    ),

    'way_end_panicked': QuestSegment(
      id: 'way_end_panicked',
      content:
          'The panic is real. It sits in your chest like a timer '
          'counting down to something you can\'t see.\n\n'
          'But here\'s what nobody tells you: '
          'almost nobody at your age actually knows. '
          'The ones who sound sure? '
          'Some of them are. Most are just saying something '
          'so the adults stop asking.\n\n'
          'You\'re not behind. '
          'You\'re just the one brave enough to admit '
          'you haven\'t figured it out yet.\n\n'
          'That\'s a better starting point than a fake answer.',
      isEnding: true,
    ),

    'way_end_steady': QuestSegment(
      id: 'way_end_steady',
      content:
          'Good.\n\n'
          '"I don\'t know yet" is an honest answer '
          'in a world that rewards confident performances.\n\n'
          'Some people will try to make you feel bad about it. '
          'That says more about their discomfort with uncertainty '
          'than yours.\n\n'
          'You\'ll figure it out. Not on anyone else\'s timeline — '
          'on yours. And when you do, '
          'it\'ll be because you chose it, '
          'not because you panicked into it.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// ADOLESCENT QUEST 4: The Fight at Home
// ═══════════════════════════════════════════════════════════════════════════════

const questFightAtHome = LifeQuestScenario(
  id: 'the_fight_at_home',
  title: 'The Fight at Home',
  hook: 'Words said you can\'t take back. Now the house is too quiet.',
  emoji: '\u{1F6AA}',
  emotions: ['angry', 'sad', 'frustrated'],
  recommendedBands: [AgeBand.adolescent],
  startSegmentId: 'fh_start',
  segments: {
    'fh_start': QuestSegment(
      id: 'fh_start',
      content:
          'You can still hear the door slam in your ears.\n\n'
          'The argument built fast. '
          'Something they said. Something you said back. '
          'Then everything you\'ve been holding for months, '
          'out in the open, ugly.\n\n'
          'You didn\'t apologise. Neither did they.\n\n'
          'Now the house is quiet. Too quiet.\n\n'
          '«{companion} is in the next room pretending not to have heard.»\n\n'
          'Two hours have passed. '
          'You can hear your parent in the kitchen, moving around.\n\n'
          'What do you do?',
      choices: [
        QuestChoice(
          id: 'fh_go_out',
          text: 'Go out there. Try to fix it.',
          nextSegmentId: 'fh_go_out',
        ),
        QuestChoice(
          id: 'fh_stay_in',
          text: 'Stay in your room. You\'re not sorry.',
          nextSegmentId: 'fh_stay_in',
        ),
      ],
    ),

    'fh_go_out': QuestSegment(
      id: 'fh_go_out',
      content:
          'You walk down the hall.\n\n'
          'Your parent is at the sink, back to you. They don\'t turn around.\n\n'
          '"Hey."\n\n'
          '"Hey." Still not turning.\n\n'
          'This is the hard part. '
          'You could apologise for the whole thing — '
          'smooth it away, make dinner happen, '
          'pretend the next morning is fresh.\n\n'
          'Or you could apologise for *how* it went. '
          'Not for *what you meant*.\n\n'
          'What do you say?',
      choices: [
        QuestChoice(
          id: 'fh_smooth',
          text: '"Sorry. Let\'s just forget it."',
          nextSegmentId: 'fh_end_smooth',
        ),
        QuestChoice(
          id: 'fh_partial',
          text: '"I\'m sorry I yelled. I\'m not sorry for what I said."',
          nextSegmentId: 'fh_end_partial',
        ),
      ],
    ),

    'fh_stay_in': QuestSegment(
      id: 'fh_stay_in',
      content:
          'You stay put. The light fades outside.\n\n'
          'Your phone buzzes once. Maybe your parent. Maybe not.\n'
          'You don\'t check.\n\n'
          'You weren\'t wrong. You know that. '
          'But as the minutes pass, you notice something else — '
          'you\'re not feeling *right* either.\n\n'
          'Being correct and being at peace aren\'t the same thing.\n\n'
          'What now?',
      choices: [
        QuestChoice(
          id: 'fh_text',
          text: 'Text them. Something short. Something true.',
          nextSegmentId: 'fh_end_text',
        ),
        QuestChoice(
          id: 'fh_hold',
          text: 'Hold your ground. Let them come to you.',
          nextSegmentId: 'fh_end_hold',
        ),
      ],
    ),

    'fh_end_smooth': QuestSegment(
      id: 'fh_end_smooth',
      content:
          'Your parent turns around, looking tired.\n\n'
          '"Okay. Forget it."\n\n'
          'And just like that, the fight is filed away.\n\n'
          'The house warms up again. Dinner happens. '
          'By the morning it\'s as if it never happened.\n\n'
          'Except you remember it. '
          'And the thing you were fighting about — '
          'the reason it got that loud — '
          'is still there. Unspoken.\n\n'
          'Sometimes smoothing over is the kind thing to do. '
          'Sometimes it\'s just postponing the same fight.\n\n'
          'Only you know which one this was.',
      isEnding: true,
    ),

    'fh_end_partial': QuestSegment(
      id: 'fh_end_partial',
      content:
          'Your parent puts down the dish towel.\n\n'
          'They look at you for a long moment. '
          'You can see them deciding something.\n\n'
          '"Okay," they say. "I can work with that."\n\n'
          'It\'s not a reconciliation. '
          'It\'s not even agreement. '
          'It\'s an acknowledgement that you said something real, '
          'and you\'re not taking it back.\n\n'
          'The hardest thing in family isn\'t being wrong. '
          'It\'s staying in the room *while* you\'re right.\n\n'
          'You stayed in the room.',
      isEnding: true,
    ),

    'fh_end_text': QuestSegment(
      id: 'fh_end_text',
      content:
          'You type and delete three drafts before one feels honest:\n\n'
          '*I\'m still mad. But I don\'t want us not talking. '
          'I\'ll come out when dinner\'s ready.*\n\n'
          'You send it. The three dots appear.\n\n'
          'Then: *Okay.*\n\n'
          'Just that. One word.\n\n'
          'It\'s not everything you wanted. '
          'It\'s not a win. '
          'But it\'s a door cracked open — '
          'and you\'re the one who cracked it.\n\n'
          'Sometimes the bravest thing in a fight '
          'isn\'t holding your ground. '
          'It\'s refusing to let silence grow teeth.',
      isEnding: true,
    ),

    'fh_end_hold': QuestSegment(
      id: 'fh_end_hold',
      content:
          'You hold.\n\n'
          'Dinner comes and goes. You don\'t eat with them. '
          'The house stays cold.\n\n'
          'Eventually you fall asleep. '
          'In the morning no one says anything, '
          'and neither do you. '
          'The fight just… sits there. For days.\n\n'
          'Holding ground feels powerful in the moment. '
          'It feels less powerful on day three.\n\n'
          'Being right doesn\'t warm a house. '
          'Someone has to speak first — '
          'and the person who speaks first isn\'t the one who lost.\n\n'
          'You can decide, later, to be that person. '
          'It\'s not too late until you decide it is.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// ADOLESCENT QUEST 5: After the Breakup
// ═══════════════════════════════════════════════════════════════════════════════

const questAfterTheBreakup = LifeQuestScenario(
  id: 'after_the_breakup',
  title: 'After the Breakup',
  hook: 'Three months. One text. Now what?',
  emoji: '\u{1F494}',
  emotions: ['sad', 'angry', 'embarrassed'],
  recommendedBands: [AgeBand.adolescent],
  startSegmentId: 'br_start',
  segments: {
    'br_start': QuestSegment(
      id: 'br_start',
      content:
          'The message came in ten minutes ago.\n\n'
          '*I think we need to stop.*\n\n'
          'That\'s it. No "let\'s talk." No explanation. '
          'Three months of something that felt real, '
          'ended in one line on a screen.\n\n'
          'Your chest is tight. Your phone is right there.\n\n'
          'What do you do?',
      choices: [
        QuestChoice(
          id: 'br_reply_now',
          text: 'Reply right now. They owe you a real conversation.',
          nextSegmentId: 'br_reply_now',
        ),
        QuestChoice(
          id: 'br_dont_reply',
          text: 'Don\'t reply. Sit with it. Don\'t give them your reaction for free.',
          nextSegmentId: 'br_dont_reply',
        ),
      ],
    ),

    'br_reply_now': QuestSegment(
      id: 'br_reply_now',
      content:
          'You open the thread.\n\n'
          'You start typing. You delete it. You start again.\n\n'
          'You could lay it all out — '
          'what you thought this was, what it meant to you, '
          'what you hoped. All of it.\n\n'
          'Or you could send one question.\n\n'
          'What do you do?',
      choices: [
        QuestChoice(
          id: 'br_send_everything',
          text: 'Send everything. Let them see you.',
          nextSegmentId: 'br_end_send_everything',
        ),
        QuestChoice(
          id: 'br_ask_why',
          text: 'Just: "Why now?"',
          nextSegmentId: 'br_end_ask_why',
        ),
      ],
    ),

    'br_dont_reply': QuestSegment(
      id: 'br_dont_reply',
      content:
          'You put the phone face-down.\n\n'
          'An hour passes. Another. '
          'You keep almost picking it up.\n\n'
          'You start narrating conversations in your head — '
          'things you should\'ve said, '
          'things you\'ll say when they finally explain themselves.\n\n'
          'They haven\'t texted again.\n\n'
          'What now?',
      choices: [
        QuestChoice(
          id: 'br_block',
          text: 'Block them. Clean wound.',
          nextSegmentId: 'br_end_block',
        ),
        QuestChoice(
          id: 'br_sit_quiet',
          text: 'Stay off it. See who you become in the quiet.',
          nextSegmentId: 'br_end_sit_quiet',
        ),
      ],
    ),

    'br_end_send_everything': QuestSegment(
      id: 'br_end_send_everything',
      content:
          'You send it. All of it.\n\n'
          'Three days later they reply with something hollow. '
          '*I\'m sorry. I didn\'t mean to hurt you.*\n\n'
          'You gave them every piece of you '
          'and got back almost nothing.\n\n'
          'But the pieces were yours to give. '
          'You didn\'t pretend you didn\'t care.\n\n'
          'That\'s not weakness, even if it feels like it. '
          'That\'s a person who refuses to shrink to look cool.',
      isEnding: true,
    ),

    'br_end_ask_why': QuestSegment(
      id: 'br_end_ask_why',
      content:
          'You send it.\n\n'
          '*Why now?*\n\n'
          'They take a while. Then: '
          '*Honestly? I\'ve been pretending for a month. '
          'You deserved better than that.*\n\n'
          'It hurts. And it\'s honest.\n\n'
          'A question is a kind of courage. '
          'Asking one and actually wanting the answer — '
          'even an answer that stings — '
          'is what adults do when they\'re trying to grow up.\n\n'
          'You just did that.',
      isEnding: true,
    ),

    'br_end_block': QuestSegment(
      id: 'br_end_block',
      content:
          'You press block. The thread disappears.\n\n'
          'For about an hour you feel taller.\n\n'
          'Then the silence has a different weight — '
          'not peace, just absence. '
          'The person you were talking to every day is gone '
          'and you made it happen.\n\n'
          'Blocking is a tool, not a feeling. '
          'It makes the noise stop. '
          'It doesn\'t make the grief stop.\n\n'
          'That part you still have to do. '
          'Just now you get to do it without them watching.',
      isEnding: true,
    ),

    'br_end_sit_quiet': QuestSegment(
      id: 'br_end_sit_quiet',
      content:
          'Days pass. You don\'t reply.\n\n'
          'At some point the urge gets quieter '
          'than the person you were with them. '
          'You start remembering who you were before.\n\n'
          'Not everyone deserves a response. '
          'Not every ending needs one.\n\n'
          'The thing you most wanted to say to them '
          'was probably *see me*. '
          'But you can see yourself.\n\n'
          'Start there.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// ADOLESCENT QUEST 6: The Screenshot
// ═══════════════════════════════════════════════════════════════════════════════

const questScreenshotSpreading = LifeQuestScenario(
  id: 'the_screenshot',
  title: 'The Screenshot',
  hook: 'Something you said is getting passed around. You can feel it.',
  emoji: '\u{1F4F1}',
  emotions: ['embarrassed', 'angry', 'sad'],
  recommendedBands: [AgeBand.adolescent],
  startSegmentId: 'ss_start',
  segments: {
    'ss_start': QuestSegment(
      id: 'ss_start',
      content:
          'Something you sent — in what you thought was a private chat — '
          'is being screenshotted.\n\n'
          'You can feel it. '
          'Messages slowing. People viewing stories and not replying. '
          'That specific quiet.\n\n'
          'You don\'t know exactly who has it yet. '
          'You don\'t know how bad the thing you said sounds '
          'when it\'s pulled out of context.\n\n'
          '«{companion} just texted you: "you okay?" »\n\n'
          'What do you do?',
      choices: [
        QuestChoice(
          id: 'ss_get_ahead',
          text: 'Get ahead of it. Post something. Frame it yourself.',
          nextSegmentId: 'ss_get_ahead',
        ),
        QuestChoice(
          id: 'ss_go_dark',
          text: 'Go dark. Close the apps. Don\'t feed it.',
          nextSegmentId: 'ss_go_dark',
        ),
      ],
    ),

    'ss_get_ahead': QuestSegment(
      id: 'ss_get_ahead',
      content:
          'You open the app. Your thumb hovers over the keyboard.\n\n'
          'You could deny it. '
          '"That\'s taken out of context. I didn\'t mean it like that."\n\n'
          'Or you could own it. '
          '"Yeah, I said that. It wasn\'t okay. I\'m sorry."\n\n'
          'Both feel terrible. Differently.\n\n'
          'What do you post?',
      choices: [
        QuestChoice(
          id: 'ss_deny',
          text: 'Deny. Fight the narrative. It\'s not fair to post a fragment.',
          nextSegmentId: 'ss_end_deny',
        ),
        QuestChoice(
          id: 'ss_own',
          text: 'Own it. Apologise publicly, in your own words.',
          nextSegmentId: 'ss_end_own',
        ),
      ],
    ),

    'ss_go_dark': QuestSegment(
      id: 'ss_go_dark',
      content:
          'You close everything. Phone face-down. '
          'You don\'t check for an hour.\n\n'
          'Then two hours. Then a whole evening.\n\n'
          'Your head is loud. Every scenario you can imagine, '
          'your brain runs it three times.\n\n'
          'What do you do with the quiet?',
      choices: [
        QuestChoice(
          id: 'ss_tell_someone',
          text: 'Tell a trusted person — parent, sibling, one real friend.',
          nextSegmentId: 'ss_end_tell_someone',
        ),
        QuestChoice(
          id: 'ss_ride_it',
          text: 'Just ride it out alone. It will pass.',
          nextSegmentId: 'ss_end_ride_it',
        ),
      ],
    ),

    'ss_end_deny': QuestSegment(
      id: 'ss_end_deny',
      content:
          'You post the denial. '
          'Some people believe you. Some don\'t.\n\n'
          'The screenshot keeps spreading.\n\n'
          'Denying something you actually said '
          'doesn\'t kill the screenshot — '
          'it just gives people one more thing to disagree about.\n\n'
          'And the people who know you said it? '
          'They quietly update their opinion of you.\n\n'
          'Not for the thing you said. '
          'For the lying afterward.\n\n'
          'You can still own it later. '
          'But later costs more than now.',
      isEnding: true,
    ),

    'ss_end_own': QuestSegment(
      id: 'ss_end_own',
      content:
          'You post it. '
          'Your thumb actually shakes a little when you hit send.\n\n'
          'The replies come in mixed. '
          'Some cruel. Some kind. Some just nothing.\n\n'
          'Here\'s the thing: '
          'the internet forgets everything except the cover-up. '
          'People respect — quietly, sometimes grudgingly — '
          'someone who faces what they did without excuses.\n\n'
          'The apology won\'t unsend the screenshot. '
          'But it tells the next version of you: '
          '*I don\'t hide from myself.*\n\n'
          'That\'s a thing worth being.',
      isEnding: true,
    ),

    'ss_end_tell_someone': QuestSegment(
      id: 'ss_end_tell_someone',
      content:
          'You say it out loud for the first time.\n\n'
          'They listen. They don\'t flinch. '
          'They don\'t tell you it\'s fine. '
          'They also don\'t tell you it\'s the end of the world.\n\n'
          'Having one person who knows the real story — '
          'the full, unflattering version — '
          'changes the shape of the night.\n\n'
          'Shame grows in silence. '
          'It gets smaller when you let one person see you.\n\n'
          'You\'re still you. '
          'The phone is still loud. '
          'But you\'re not alone with it anymore.',
      isEnding: true,
    ),

    'ss_end_ride_it': QuestSegment(
      id: 'ss_end_ride_it',
      content:
          'You ride it out. '
          'Days pass. It does fade. '
          'Something else replaces it in the feed.\n\n'
          'You were right: it passes.\n\n'
          'But the thing you felt — '
          'the panic, the certainty that everyone was talking — '
          'that lives inside you now.\n\n'
          'Next time something like this happens, '
          'it\'ll be easier to believe '
          'you can survive it alone.\n\n'
          'That\'s a kind of strength. '
          'It\'s also a kind of loneliness.\n\n'
          'Both can be true.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// ADOLESCENT QUEST 7: Burning Out
// ═══════════════════════════════════════════════════════════════════════════════

const questBurningOut = LifeQuestScenario(
  id: 'burning_out',
  title: 'Burning Out',
  hook: 'You\'re doing everything. None of it feels good anymore.',
  emoji: '\u{1F56F}',
  emotions: ['worried', 'frustrated', 'sad'],
  recommendedBands: [AgeBand.adolescent],
  startSegmentId: 'bo_start',
  segments: {
    'bo_start': QuestSegment(
      id: 'bo_start',
      content:
          'It\'s 11 PM on a Tuesday.\n\n'
          'You have two essays due, a test Friday, '
          'practice tomorrow, '
          'and an hour of the reading you haven\'t started.\n\n'
          'You\'re staring at the same paragraph you\'ve read four times. '
          'None of the words are going in.\n\n'
          'You used to be good at this. '
          'Now it feels like you\'re faking being yourself.\n\n'
          'What do you do?',
      choices: [
        QuestChoice(
          id: 'bo_push_through',
          text: 'Push through. Pull an all-nighter. Everyone else does.',
          nextSegmentId: 'bo_push_through',
        ),
        QuestChoice(
          id: 'bo_stop',
          text: 'Stop. Close the laptop. Admit you\'re out.',
          nextSegmentId: 'bo_stop',
        ),
      ],
    ),

    'bo_push_through': QuestSegment(
      id: 'bo_push_through',
      content:
          'You open another tab. Pour another drink. '
          'Put your headphones in.\n\n'
          'You get maybe 40% of it done. '
          'The essay is held together with hope.\n\n'
          'It\'s 3 AM. '
          'You\'re past tired — you\'re into the weird, glassy place '
          'where everything feels possible and nothing feels real.\n\n'
          'You notice you\'re not actually solving anything. '
          'You\'re just running.\n\n'
          'What changes tomorrow?',
      choices: [
        QuestChoice(
          id: 'bo_drop_something',
          text: 'Drop one thing. One commitment. One class. One expectation.',
          nextSegmentId: 'bo_end_drop_something',
        ),
        QuestChoice(
          id: 'bo_keep_running',
          text: 'Keep all of it. This is just what the next few months are.',
          nextSegmentId: 'bo_end_keep_running',
        ),
      ],
    ),

    'bo_stop': QuestSegment(
      id: 'bo_stop',
      content:
          'You close the laptop.\n\n'
          'The room is suddenly very quiet. '
          'You realise you don\'t actually know '
          'what you\'d be doing right now if you weren\'t doing this.\n\n'
          'That\'s a strange thing to notice.\n\n'
          'You haven\'t had a real un-scheduled hour in months.\n\n'
          'What\'s the next step?',
      choices: [
        QuestChoice(
          id: 'bo_ask_for_help',
          text: 'Ask someone — a teacher, a parent, a counsellor — for help.',
          nextSegmentId: 'bo_end_ask_for_help',
        ),
        QuestChoice(
          id: 'bo_rest',
          text: 'Sleep. Just sleep. Decide tomorrow.',
          nextSegmentId: 'bo_end_rest',
        ),
      ],
    ),

    'bo_end_drop_something': QuestSegment(
      id: 'bo_end_drop_something',
      content:
          'You pick the thing. It\'s not the biggest thing. '
          'But it\'s one real thing.\n\n'
          'You tell the person.\n\n'
          'They react how they react. '
          'It\'s uncomfortable. Sometimes it\'s disappointing.\n\n'
          'But the next morning, '
          'for the first time in a month, '
          'you wake up without that specific weight.\n\n'
          'Dropping something isn\'t quitting. '
          'It\'s acknowledging that you only have so much of yourself '
          'and you\'d rather spend it on fewer things, '
          'well.\n\n'
          'Most of the people you admire had to learn this. '
          'Most of them learned it the hard way.',
      isEnding: true,
    ),

    'bo_end_keep_running': QuestSegment(
      id: 'bo_end_keep_running',
      content:
          'You keep all of it.\n\n'
          'Some weeks it works. '
          'Some weeks it really doesn\'t.\n\n'
          'The cost gets paid somewhere — '
          'sleep, food, the people you love, '
          'the version of you that used to find things funny.\n\n'
          'Running hard isn\'t the problem. '
          'Running hard with no day off is.\n\n'
          'If you\'re going to carry all of it, '
          'build in one real rest. '
          'A walk. A bad movie. An hour where nothing is optimised.\n\n'
          'Recovery isn\'t a reward for finishing. '
          'It\'s fuel. You need it to finish.',
      isEnding: true,
    ),

    'bo_end_ask_for_help': QuestSegment(
      id: 'bo_end_ask_for_help',
      content:
          'You find the person. '
          'You say something close to: '
          '"I\'m not okay. I\'m doing too much and I can\'t tell what to drop."\n\n'
          'The first time is the hardest.\n\n'
          'They might offer exactly what you need. '
          'They might offer something that misses slightly. '
          'Either way, you\'ve done the thing that changes the shape of the problem: '
          'you stopped carrying it alone.\n\n'
          'Asking for help isn\'t a character flaw. '
          'It\'s a practical skill '
          'that people who get through hard things '
          'have already learned.\n\n'
          'You just practised it.',
      isEnding: true,
    ),

    'bo_end_rest': QuestSegment(
      id: 'bo_end_rest',
      content:
          'You sleep.\n\n'
          'Real sleep. Not phone-in-bed scroll-sleep. '
          'The kind where your body actually lands.\n\n'
          'In the morning the problems are still there. '
          'But *you* are different. '
          'You can see the edges of them.\n\n'
          'You realise some of last night\'s panic '
          'was just your brain running out of battery.\n\n'
          'Sleep isn\'t the answer to burnout. '
          'But it\'s the first thing underneath the answer. '
          'You can\'t think clearly about what to change '
          'when you haven\'t slept properly in weeks.\n\n'
          'Start here. Decide from rested.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// ADOLESCENT QUEST 8: Who Am I Becoming?
// ═══════════════════════════════════════════════════════════════════════════════

const questWhoAmIBecoming = LifeQuestScenario(
  id: 'who_am_i_becoming',
  title: 'Who Am I Becoming?',
  hook: 'Something about you is changing. They haven\'t noticed yet.',
  emoji: '\u{1FA9E}',
  emotions: ['worried', 'scared', 'excited'],
  recommendedBands: [AgeBand.adolescent],
  startSegmentId: 'wb_start',
  segments: {
    'wb_start': QuestSegment(
      id: 'wb_start',
      content:
          'Something about you is shifting.\n\n'
          'It might be who you\'re drawn to. '
          'What you believe. '
          'What you want your life to actually look like — '
          'and it doesn\'t match the plan they had for you.\n\n'
          'You\'ve been holding it quietly for a while now. '
          'The people closest to you haven\'t noticed yet.\n\n'
          'Or they\'ve noticed and they\'re waiting for you to say it.\n\n'
          'What do you do with this?',
      choices: [
        QuestChoice(
          id: 'wb_tell_someone',
          text: 'Tell one person. One you trust. See what happens.',
          nextSegmentId: 'wb_tell_someone',
        ),
        QuestChoice(
          id: 'wb_keep_quiet',
          text: 'Keep it quiet. It\'s yours. You don\'t owe anyone the whole map.',
          nextSegmentId: 'wb_keep_quiet',
        ),
      ],
    ),

    'wb_tell_someone': QuestSegment(
      id: 'wb_tell_someone',
      content:
          'You pick the person.\n\n'
          'You plan the sentence in your head ten times. '
          'When you actually say it, it comes out smaller and stranger '
          'than you practised.\n\n'
          'They look at you.\n\n'
          'And now — in the pause before they respond — '
          'you notice you\'re bracing.\n\n'
          'What do you hope they say?',
      choices: [
        QuestChoice(
          id: 'wb_hope_accept',
          text: 'Just: "Okay. Thank you for telling me."',
          nextSegmentId: 'wb_end_hope_accept',
        ),
        QuestChoice(
          id: 'wb_hope_honest',
          text: 'Something honest, even if it\'s hard to hear.',
          nextSegmentId: 'wb_end_hope_honest',
        ),
      ],
    ),

    'wb_keep_quiet': QuestSegment(
      id: 'wb_keep_quiet',
      content:
          'You don\'t say it.\n\n'
          'Not tonight. Not this week. '
          'You\'re still figuring it out for yourself, '
          'and other people\'s reactions would get in the way.\n\n'
          'Weeks pass. The thing doesn\'t go away. '
          'If anything it gets clearer.\n\n'
          'You notice you\'re more careful now — '
          'about what you share, what you agree with, '
          'who you are in different rooms.\n\n'
          'How does that sit?',
      choices: [
        QuestChoice(
          id: 'wb_private_for_now',
          text: 'That\'s fine. Privacy isn\'t hiding.',
          nextSegmentId: 'wb_end_private_for_now',
        ),
        QuestChoice(
          id: 'wb_tired_of_hiding',
          text: 'It\'s getting heavy. I don\'t want to live like this forever.',
          nextSegmentId: 'wb_end_tired_of_hiding',
        ),
      ],
    ),

    'wb_end_hope_accept': QuestSegment(
      id: 'wb_end_hope_accept',
      content:
          'They do. Or they don\'t.\n\n'
          'If they do — you\'ll feel like the room got warmer. '
          'A small piece of yourself comes unclenched.\n\n'
          'If they don\'t — it\'ll hurt. '
          'Not because you did anything wrong, '
          'but because you were brave in their direction '
          'and they didn\'t catch you.\n\n'
          'Either way, you did the hard part. '
          'You stopped asking yourself '
          'to be smaller than you are in your own life.\n\n'
          'The first person you tell is rarely the last. '
          'You\'re practising a muscle you\'ll use again.',
      isEnding: true,
    ),

    'wb_end_hope_honest': QuestSegment(
      id: 'wb_end_hope_honest',
      content:
          'They take a long breath.\n\n'
          'What comes back is honest. '
          'Not polished. Maybe a bit messy. '
          'Some of it is supportive. '
          'Some of it you\'ll need to think about later.\n\n'
          'That\'s a real conversation. '
          'Not a script.\n\n'
          'People who love you are allowed to need a beat '
          'to catch up with who you\'re becoming. '
          'A messy honest first reaction '
          'is often the beginning of a real relationship — '
          'not the end of one.\n\n'
          'Give them a little time. '
          'Give yourself a little time too.',
      isEnding: true,
    ),

    'wb_end_private_for_now': QuestSegment(
      id: 'wb_end_private_for_now',
      content:
          'You keep it.\n\n'
          'You figure it out on your own terms. '
          'You read. You think. '
          'You find one corner of the internet or one quiet journal '
          'where the words come out easier.\n\n'
          'Here\'s the line: '
          'privacy is choosing when and with whom. '
          'Hiding is feeling like you have no choice at all.\n\n'
          'Right now this is privacy. '
          'You\'re building your understanding before you hand it to anyone.\n\n'
          'That is allowed. That\'s actually how it\'s supposed to work.',
      isEnding: true,
    ),

    'wb_end_tired_of_hiding': QuestSegment(
      id: 'wb_end_tired_of_hiding',
      content:
          'You notice it — the cost.\n\n'
          'Shape-shifting between rooms is exhausting. '
          'Eventually it starts feeling like you\'re renting out '
          'the most honest parts of yourself '
          'and never getting them back.\n\n'
          'You don\'t have to come out to everyone. '
          'You don\'t have to announce anything on a schedule.\n\n'
          'But you\'re allowed to ask yourself: '
          '*is there one place, with one person, '
          'where I could put this down for a while?*\n\n'
          'Find that place. Start there. '
          'You\'re not obligated to live under your own breath forever.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// ADOLESCENT QUEST 9: The First Paycheck
// ═══════════════════════════════════════════════════════════════════════════════

const questFirstPaycheck = LifeQuestScenario(
  id: 'first_paycheck',
  title: 'The First Paycheck',
  hook: 'Your own money. Your own choices. Also — your own mistakes.',
  emoji: '\u{1F4BC}',
  emotions: ['excited', 'worried', 'frustrated'],
  recommendedBands: [AgeBand.adolescent],
  startSegmentId: 'fp_start',
  segments: {
    'fp_start': QuestSegment(
      id: 'fp_start',
      content:
          'Your first real paycheck landed today.\n\n'
          'Not birthday money. Not pocket money. '
          'Money you traded hours of your actual life for.\n\n'
          'It\'s smaller than you expected — '
          'taxes took a bite you didn\'t see coming.\n\n'
          'Still. It\'s yours.\n\n'
          'And everyone suddenly has opinions about what you should do with it.\n\n'
          'What do you do first?',
      choices: [
        QuestChoice(
          id: 'fp_spend_it',
          text: 'Buy the thing. You earned it. That\'s the whole point.',
          nextSegmentId: 'fp_spend_it',
        ),
        QuestChoice(
          id: 'fp_save_it',
          text: 'Save most of it. Be the sensible one. Future you will thank you.',
          nextSegmentId: 'fp_save_it',
        ),
      ],
    ),

    'fp_spend_it': QuestSegment(
      id: 'fp_spend_it',
      content:
          'You buy it.\n\n'
          'The thing you\'ve been wanting for months. '
          'You take the box home. You open it. '
          'The box is somehow the best part.\n\n'
          'A week later the thrill is quieter. '
          'A month later it\'s just a thing.\n\n'
          'Meanwhile the account is lower than you thought it\'d be.\n\n'
          'Not bad. Just… a lesson.\n\n'
          'What do you take from this one?',
      choices: [
        QuestChoice(
          id: 'fp_no_regret',
          text: 'No regret. Money is for living. Do it again next paycheck.',
          nextSegmentId: 'fp_end_no_regret',
        ),
        QuestChoice(
          id: 'fp_learn',
          text: 'Next time: decide the thing *before* the paycheck lands, not after.',
          nextSegmentId: 'fp_end_learn',
        ),
      ],
    ),

    'fp_save_it': QuestSegment(
      id: 'fp_save_it',
      content:
          'You move most of it into savings. '
          'You keep a small buffer for the week.\n\n'
          'It feels responsible. '
          'It also feels, strangely, a little flat.\n\n'
          'You start noticing the things you said no to. '
          'The coffee with a friend. The concert ticket. '
          'You said you didn\'t have the money. '
          'Technically, you did. You just chose not to spend it.\n\n'
          'What kind of saver are you trying to be?',
      choices: [
        QuestChoice(
          id: 'fp_all_in_save',
          text: 'All in. Every dollar. I\'ll spend less and build a real cushion.',
          nextSegmentId: 'fp_end_all_in_save',
        ),
        QuestChoice(
          id: 'fp_balance',
          text: 'Balance. A slice for future. A slice for now. A slice for people.',
          nextSegmentId: 'fp_end_balance',
        ),
      ],
    ),

    'fp_end_no_regret': QuestSegment(
      id: 'fp_end_no_regret',
      content:
          'Next paycheck, you do it again. '
          'And the next one.\n\n'
          'You enjoy your money. You never save.\n\n'
          'When the first surprise bill hits — '
          'phone screen, doctor, car repair, '
          'the thing you didn\'t plan for — '
          'you find out what stress actually feels like '
          'when there\'s no cushion under you.\n\n'
          'Money for living is right. '
          'But living includes the months that are harder than you expect.\n\n'
          'You don\'t have to be frugal. '
          'You do have to be ready.\n\n'
          'Even a small cushion changes which problems can knock you over.',
      isEnding: true,
    ),

    'fp_end_learn': QuestSegment(
      id: 'fp_end_learn',
      content:
          'Before the next paycheck lands, '
          'you actually think about what you want.\n\n'
          'Not what would feel good in the moment. '
          'What future-you, two weeks from now, '
          'would still be glad about.\n\n'
          'That one habit — *deciding before the money hits* — '
          'is half of being good with money.\n\n'
          'The other half is forgiving yourself '
          'when the decision turns out wrong, '
          'and trying again next time.\n\n'
          'That\'s not boring adulthood. '
          'That\'s the thing most people never actually learn.',
      isEnding: true,
    ),

    'fp_end_all_in_save': QuestSegment(
      id: 'fp_end_all_in_save',
      content:
          'You save hard for months.\n\n'
          'The number in the account grows. '
          'It\'s satisfying. '
          'It\'s also, after a while, a little lonely.\n\n'
          'You start saying no to so many things — '
          'meals, trips, small kindnesses — '
          'that you begin to feel like a visitor in your own life.\n\n'
          'Saving is a tool. '
          'It\'s meant to buy you options, not subtract you from the world.\n\n'
          'Keep saving. '
          'But put a small, real amount aside each month '
          'for being a person in the world '
          'with the people you love.\n\n'
          'Money you never spend is just a number on a screen. '
          'Relationships you underfed are harder to rebuild.',
      isEnding: true,
    ),

    'fp_end_balance': QuestSegment(
      id: 'fp_end_balance',
      content:
          'You split it.\n\n'
          'Some of it goes to future you — '
          'the version who will be glad there\'s a cushion.\n\n'
          'Some goes to right-now you — '
          'the thing that makes this week feel like it had a point.\n\n'
          'Some goes, quietly, to someone else — '
          'the friend\'s coffee, the gift, '
          'the thing you don\'t announce.\n\n'
          'That third category is the one people forget. '
          'It\'s also the one that, in ten years, '
          'you\'ll remember best.\n\n'
          'Good with money doesn\'t mean greedy. '
          'It means *on purpose*.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// SPROUT QUEST 1: The Big Bear Hug  [Sprout: ages 2-5]
// Short segments. Simple words. Two choices. Both paths are kind.
// ═══════════════════════════════════════════════════════════════════════════════

const questBigBearHug = LifeQuestScenario(
  id: 'big_bear_hug',
  title: 'The Big Bear Hug',
  hook: 'Your favorite teddy is missing. Where could he be?',
  emoji: '\u{1F9F8}',
  emotions: ['sad', 'worried'],
  recommendedBands: [AgeBand.sprout],
  cloud: SproutCloud.rain,
  grownupTip: "Ask: 'Have you ever felt like Teddy was lost? What did we do?'",
  startSegmentId: 'bbh_start',
  segments: {
    'bbh_start': QuestSegment(
      id: 'bbh_start',
      content:
          'It is bedtime.\n\n'
          'You look on your pillow. '
          'No teddy.\n\n'
          'You look under the blanket. '
          'No teddy.\n\n'
          'Your tummy feels wobbly. '
          'Where is he?',
      choices: [
        QuestChoice(
          id: 'bbh_c1a',
          text: 'Call out — "Mommy! Daddy!"',
          nextSegmentId: 'bbh_call',
        ),
        QuestChoice(
          id: 'bbh_c1b',
          text: 'Go look in the toy box',
          nextSegmentId: 'bbh_look',
        ),
      ],
    ),

    'bbh_call': QuestSegment(
      id: 'bbh_call',
      content:
          '"I can\'t find Teddy!"\n\n'
          'Big footsteps. A warm hand on your back.\n\n'
          '"Let\'s look together."\n\n'
          'It is so much easier with two.',
      choices: [
        QuestChoice(
          id: 'bbh_c2a',
          text: 'Check the couch first',
          nextSegmentId: 'bbh_couch',
        ),
        QuestChoice(
          id: 'bbh_c2b',
          text: 'Check the car first',
          nextSegmentId: 'bbh_car',
        ),
      ],
    ),

    'bbh_look': QuestSegment(
      id: 'bbh_look',
      content:
          'You dig — blocks, books, a sock.\n\n'
          'No teddy in the toy box.\n\n'
          '«{companion} nudges your leg. »Your eyes feel hot.\n\n'
          'A small tear slips out. That\'s okay. '
          'Tears help when we feel sad.',
      choices: [
        QuestChoice(
          id: 'bbh_c3a',
          text: 'Take a big breath',
          nextSegmentId: 'bbh_breath',
        ),
        QuestChoice(
          id: 'bbh_c3b',
          text: 'Go find a grown-up',
          nextSegmentId: 'bbh_call',
        ),
      ],
    ),

    'bbh_couch': QuestSegment(
      id: 'bbh_couch',
      content:
          'You both kneel by the couch.\n\n'
          'A furry ear pokes out between the cushions.\n\n'
          'TEDDY!\n\n'
          'You squeeze him tight. '
          'He squeezes back — in your heart.\n\n'
          'Lost things can be found. '
          'And grown-ups love helping.',
      isEnding: true,
    ),

    'bbh_car': QuestSegment(
      id: 'bbh_car',
      content:
          'Out to the car, pajamas and all.\n\n'
          'You open the door — and there he is! '
          'Sitting in your car seat, waiting.\n\n'
          'You hug him so hard his nose squishes.\n\n'
          'Teddies don\'t really get lost. '
          'They just have little adventures.',
      isEnding: true,
    ),

    'bbh_breath': QuestSegment(
      id: 'bbh_breath',
      content:
          'You take one big breath in... '
          'and let it out slow.\n\n'
          'Your shoulders go down.\n\n'
          'You peek behind the big chair — '
          'and a fluffy arm waves at you.\n\n'
          'Teddy was only hiding.\n\n'
          'Big feelings come, and big feelings go. '
          'You did it, {name}.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// SPROUT QUEST 2: The Big Loud  [Sprout: ages 2-5]
// Fear of loud sounds. Both paths teach: scary sounds can\'t hurt you.
// ═══════════════════════════════════════════════════════════════════════════════

const questBigLoud = LifeQuestScenario(
  id: 'big_loud',
  title: 'The Big Loud',
  hook: 'A loud sound makes your heart jump. What do you do?',
  emoji: '\u{26C8}',
  emotions: ['worried', 'frustrated'],
  cloud: SproutCloud.wobbly,
  grownupTip: "Ask: 'What loud sounds make YOUR heart jump? What helps you feel braver?'",
  recommendedBands: [AgeBand.sprout],
  startSegmentId: 'bl_start',
  segments: {
    'bl_start': QuestSegment(
      id: 'bl_start',
      content:
          'You are building a tall tower.\n\n'
          'BOOM!\n\n'
          'A big loud sound outside. '
          'Rain is tapping on the window.\n\n'
          'Your heart goes fast. '
          'The sound was so BIG.',
      choices: [
        QuestChoice(
          id: 'bl_c1a',
          text: 'Run to a grown-up',
          nextSegmentId: 'bl_run',
        ),
        QuestChoice(
          id: 'bl_c1b',
          text: 'Hide under the blanket',
          nextSegmentId: 'bl_hide',
        ),
      ],
    ),

    'bl_run': QuestSegment(
      id: 'bl_run',
      content:
          'You run fast. Little feet, big heart.\n\n'
          'A grown-up scoops you up.\n\n'
          '"That was thunder," they say. '
          '"Loud, but safe."\n\n'
          'You press your ear to their chest. '
          'Bu-bump. Bu-bump. Steady.',
      choices: [
        QuestChoice(
          id: 'bl_c2a',
          text: 'Peek at the window together',
          nextSegmentId: 'bl_peek',
        ),
        QuestChoice(
          id: 'bl_c2b',
          text: 'Stay snuggled in',
          nextSegmentId: 'bl_snuggle',
        ),
      ],
    ),

    'bl_hide': QuestSegment(
      id: 'bl_hide',
      content:
          'Under the blanket it is dark and soft.\n\n'
          '«{companion} crawls in too. »You breathe in and out. '
          'In and out.\n\n'
          'The rain keeps tapping. '
          'Tap tap tap. Not scary — just busy.',
      choices: [
        QuestChoice(
          id: 'bl_c3a',
          text: 'Peek one eye out',
          nextSegmentId: 'bl_peek',
        ),
        QuestChoice(
          id: 'bl_c3b',
          text: 'Hum your favorite song',
          nextSegmentId: 'bl_hum',
        ),
      ],
    ),

    'bl_peek': QuestSegment(
      id: 'bl_peek',
      content:
          'You peek out.\n\n'
          'The sky flashes white — so bright! — '
          'and then BOOM again.\n\n'
          'But this time you count: '
          '"One... two... three." '
          'The boom goes away.\n\n'
          'The storm is outside. You are inside. '
          'Safe and dry and brave.',
      isEnding: true,
    ),

    'bl_snuggle': QuestSegment(
      id: 'bl_snuggle',
      content:
          'You stay snuggled in.\n\n'
          'The rain keeps singing its pitter-patter song.\n\n'
          'Soon the loud part is gone. '
          'Only soft rain is left.\n\n'
          'When big sounds come, '
          'hugs make them small again.',
      isEnding: true,
    ),

    'bl_hum': QuestSegment(
      id: 'bl_hum',
      content:
          'You hum. The humming tickles your lips.\n\n'
          'The rain hums too, on the roof.\n\n'
          'You and the rain make a little song together.\n\n'
          'Loud things are less scary '
          'when you have your own song to play.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// SPROUT QUEST 3: My Turn, Your Turn  [Sprout: ages 2-5]
// Sharing / waiting. Both paths end in a warm resolution.
// ═══════════════════════════════════════════════════════════════════════════════

const questMyTurnYourTurn = LifeQuestScenario(
  id: 'my_turn_your_turn',
  title: 'My Turn, Your Turn',
  hook: 'Someone else has the red truck. You really want it.',
  emoji: '\u{1F697}',
  emotions: ['angry', 'frustrated', 'sad'],
  recommendedBands: [AgeBand.sprout],
  cloud: SproutCloud.storm,
  grownupTip: "Ask: 'When was the last time it was hard to wait? What did we do together?'",
  startSegmentId: 'mt_start',
  segments: {
    'mt_start': QuestSegment(
      id: 'mt_start',
      content:
          'The red truck is your favorite.\n\n'
          'But another kid has it right now. '
          'Vroom, vroom.\n\n'
          'Your hands squeeze into tight little fists. '
          'Your face feels hot.\n\n'
          'You really, really want that truck.',
      choices: [
        QuestChoice(
          id: 'mt_c1a',
          text: 'Go grab it',
          nextSegmentId: 'mt_grab',
        ),
        QuestChoice(
          id: 'mt_c1b',
          text: 'Ask nicely',
          nextSegmentId: 'mt_ask',
        ),
      ],
    ),

    'mt_grab': QuestSegment(
      id: 'mt_grab',
      content:
          'You reach out fast.\n\n'
          'The other kid holds on tight. "MINE!"\n\n'
          'Oh no. Your tummy feels wobbly.\n\n'
          'A grown-up kneels down. '
          '"Grabbing makes sad faces. '
          'Let\'s try asking."',
      choices: [
        QuestChoice(
          id: 'mt_c2a',
          text: 'Try again — ask nicely',
          nextSegmentId: 'mt_ask',
        ),
        QuestChoice(
          id: 'mt_c2b',
          text: 'Take a big breath first',
          nextSegmentId: 'mt_breath',
        ),
      ],
    ),

    'mt_ask': QuestSegment(
      id: 'mt_ask',
      content:
          'You walk over. Slow and kind.\n\n'
          '"Can I have a turn, please?"\n\n'
          'The other kid looks at you. '
          'Thinks for a second.\n\n'
          '"After one more vroom."\n\n'
          'One more vroom feels like a long time. '
          'But you can wait.',
      choices: [
        QuestChoice(
          id: 'mt_c3a',
          text: 'Count while you wait',
          nextSegmentId: 'mt_count',
        ),
        QuestChoice(
          id: 'mt_c3b',
          text: 'Play with a different toy',
          nextSegmentId: 'mt_different',
        ),
      ],
    ),

    'mt_breath': QuestSegment(
      id: 'mt_breath',
      content:
          'You take a big breath in. '
          'Then a big breath out.\n\n'
          'Your fists open up like little flowers.\n\n'
          'Your face feels cool again.\n\n'
          'Now you can use your kind voice. '
          '"May I have a turn, please?"\n\n'
          '"Yes," says the other kid. And they hand it over.\n\n'
          'Big feelings, then kind words. That\'s the magic.',
      isEnding: true,
    ),

    'mt_count': QuestSegment(
      id: 'mt_count',
      content:
          'You count on your fingers. '
          'One, two, three...\n\n'
          'The truck comes rolling over to your hand.\n\n'
          '"Your turn!"\n\n'
          'VROOM! You zoom it across the floor.\n\n'
          'Waiting is hard. '
          'But the truck is still just as red.',
      isEnding: true,
    ),

    'mt_different': QuestSegment(
      id: 'mt_different',
      content:
          'You pick up the blue airplane.\n\n'
          'Whoooosh! It swoops over your head.\n\n'
          'Before long, a little hand taps your shoulder.\n\n'
          '"Truck?"\n\n'
          'You trade. Airplane for truck. '
          'Everybody smiles.\n\n'
          'Sharing is taking turns — '
          'and sometimes, trading.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST: When the Spotlight's Not on You  [Explorer: ages 6-8]
// Sibling jealousy — a sibling gets the attention, the praise, the moment.
// ═══════════════════════════════════════════════════════════════════════════════

const questSiblingShine = LifeQuestScenario(
  id: 'sibling_shine',
  title: "When the Spotlight's Not on You",
  hook: 'Everyone is talking about your sister. You\'re right here too.',
  emoji: '✨',
  emotions: ['jealous', 'sad', 'angry', 'left out'],
  recommendedBands: [AgeBand.explorer],
  startSegmentId: 'ss_start',
  grownupTip:
      "Ask: 'Have you ever felt like everyone was looking at someone else? "
      "What helped you feel seen again?'",
  segments: {
    'ss_start': QuestSegment(
      id: 'ss_start',
      content:
          'Your little sister just learned to ride her bike.\n\n'
          'Mom is clapping. Dad is filming on his phone. Grandma calls and '
          'wants to hear the story three times.\n\n'
          'You learned to ride your bike a long time ago. You learned to ride '
          'with no hands last summer. Nobody is filming that today.\n\n'
          '«{companion} sits next to you on the porch. {Pronoun} is quiet too.»\n\n'
          'Your chest feels tight. Like there\'s not enough room for how big '
          'you feel right now.\n\n'
          'What do you do?',
      choices: [
        QuestChoice(
          id: 'ss_c1a',
          text: 'Stomp inside and slam the door',
          nextSegmentId: 'ss_storm',
        ),
        QuestChoice(
          id: 'ss_c1b',
          text: 'Tell Mom you feel left out',
          nextSegmentId: 'ss_say',
        ),
      ],
    ),

    'ss_storm': QuestSegment(
      id: 'ss_storm',
      content:
          'You stomp inside. The door makes a big noise behind you.\n\n'
          'You sit on your bed. Your eyes are hot.\n\n'
          'After a few minutes, Mom knocks.\n\n'
          '"Hey, kiddo. Can I come in?"\n\n'
          'You sniff and nod.\n\n'
          'She sits next to you. "I noticed you got quiet outside. '
          'Are you feeling left out?"',
      copingBreakId: 'belly_breath',
      choices: [
        QuestChoice(
          id: 'ss_c2a',
          text: 'Nod and let her hug you',
          nextSegmentId: 'ss_hug',
        ),
        QuestChoice(
          id: 'ss_c2b',
          text: 'Say "Why is everyone only excited about her?"',
          nextSegmentId: 'ss_words',
        ),
      ],
    ),

    'ss_say': QuestSegment(
      id: 'ss_say',
      content:
          'You take a big breath.\n\n'
          '"Mom?" you say. "I feel kind of left out."\n\n'
          'Mom looks up. Right at you. Like the whole bike thing got paused.\n\n'
          '"Oh, honey. Tell me more."\n\n'
          'It\'s scary to say it out loud. But she\'s listening now.',
      choices: [
        QuestChoice(
          id: 'ss_c3a',
          text: 'Tell her you wanted her to see you too',
          nextSegmentId: 'ss_seen',
        ),
        QuestChoice(
          id: 'ss_c3b',
          text: 'Just shrug — saying it was already enough',
          nextSegmentId: 'ss_shrug',
        ),
      ],
    ),

    'ss_hug': QuestSegment(
      id: 'ss_hug',
      content:
          'You nod. Mom wraps her arms around you.\n\n'
          'You don\'t say anything for a while. You don\'t have to.\n\n'
          'Then she says, "You know what? You learned to ride with no hands. '
          'Want to show me again? Just us?"\n\n'
          'Maybe. In a minute.\n\n'
          'For now, the hug is enough.',
      isEnding: true,
    ),

    'ss_words': QuestSegment(
      id: 'ss_words',
      content:
          '"Why is everyone only excited about her?" you ask.\n\n'
          'Mom is quiet for a moment.\n\n'
          '"Today is her big day," she says. "Tomorrow could be yours. '
          'And last summer was yours, when you went no hands. Remember? '
          'Grandma still talks about that."\n\n'
          'You didn\'t know Grandma still talked about that.\n\n'
          'There\'s enough room. You just couldn\'t see it for a minute.',
      isEnding: true,
    ),

    'ss_seen': QuestSegment(
      id: 'ss_seen',
      content:
          '"I wanted you to see me too," you say.\n\n'
          'Your voice wobbles a little. That\'s okay.\n\n'
          'Mom nods slowly. "I see you. I always see you. Sometimes the noise '
          'gets loud and you can\'t tell — but I do."\n\n'
          'She squeezes your hand.\n\n'
          'Brave words go a long way. '
          'Especially the wobbly ones.',
      isEnding: true,
    ),

    'ss_shrug': QuestSegment(
      id: 'ss_shrug',
      content:
          'You shrug. You\'re not sure what else to say.\n\n'
          'Mom waits. Then she just sits with you.\n\n'
          '"Thanks for telling me," she says. "That took courage."\n\n'
          'You didn\'t fix anything. You didn\'t say much.\n\n'
          'But the tight feeling in your chest got a little smaller. '
          'Saying it out loud was the magic.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST: Where Did Buddy Go?  [Explorer: ages 6-8]
// Lost pet — temporary, scary, happily resolved.
// ═══════════════════════════════════════════════════════════════════════════════

const questLostPet = LifeQuestScenario(
  id: 'lost_pet',
  title: 'Where Did Buddy Go?',
  hook: "You called and called. Your pet didn't come.",
  emoji: '🐾',
  emotions: ['scared', 'sad', 'worried'],
  recommendedBands: [AgeBand.explorer],
  startSegmentId: 'lp_start',
  grownupTip:
      "Ask: 'When something feels really scary, who can you tell? What helped today?'",
  segments: {
    'lp_start': QuestSegment(
      id: 'lp_start',
      content:
          'You whistle the special whistle.\n\n'
          'The one that always makes Pepper come running.\n\n'
          'Nothing.\n\n'
          'You whistle again. Louder.\n\n'
          'The yard is just yard. The bushes are just bushes. Pepper isn\'t '
          'under the porch. Pepper isn\'t by the back door.\n\n'
          'Your heart starts doing that fast thing. Bump-bump-bump-bump.\n\n'
          '«{companion} stands beside you, ears up.»\n\n'
          'What do you do first?',
      choices: [
        QuestChoice(
          id: 'lp_c1a',
          text: 'Run inside and tell a grown-up right away',
          nextSegmentId: 'lp_tell',
        ),
        QuestChoice(
          id: 'lp_c1b',
          text: 'Look in all your secret hiding places first',
          nextSegmentId: 'lp_hunt',
        ),
      ],
    ),

    'lp_tell': QuestSegment(
      id: 'lp_tell',
      content:
          'You run inside. Your shoes are still on the welcome mat behind you.\n\n'
          '"Dad! Pepper\'s not in the yard!"\n\n'
          'Dad puts down his coffee right away. "Okay. Okay. Let\'s think."\n\n'
          'He grabs his shoes. "When did you last see Pepper?"',
      choices: [
        QuestChoice(
          id: 'lp_c2a',
          text: 'Try to remember calmly — by breakfast?',
          nextSegmentId: 'lp_clue',
        ),
        QuestChoice(
          id: 'lp_c2b',
          text: 'Get teary — you can\'t remember',
          nextSegmentId: 'lp_cry',
        ),
      ],
    ),

    'lp_hunt': QuestSegment(
      id: 'lp_hunt',
      content:
          'You check under the porch. Behind the shed. By the recycling bin '
          'where Pepper sometimes naps.\n\n'
          'Empty. Empty. Empty.\n\n'
          'Your eyes start to sting.\n\n'
          'You can keep looking alone. Or you can stop and get help.',
      copingBreakId: 'grounding_54321',
      choices: [
        QuestChoice(
          id: 'lp_c3a',
          text: 'Stop and call out for a grown-up',
          nextSegmentId: 'lp_help',
        ),
        QuestChoice(
          id: 'lp_c3b',
          text: 'Check one more spot — the front yard',
          nextSegmentId: 'lp_front',
        ),
      ],
    ),

    'lp_clue': QuestSegment(
      id: 'lp_clue',
      content:
          'You take a slow breath. "I think... right after breakfast. '
          'When the gate was open for the trash."\n\n'
          'Dad nods. "Good remembering."\n\n'
          'Together you walk down the sidewalk, calling Pepper\'s name.\n\n'
          'Three houses down, a tail. A wag. A guilty face full of grass.\n\n'
          'Pepper. Pepper, Pepper, Pepper.\n\n'
          'You hug your dog so hard. '
          'Asking for help made everything okay again.',
      isEnding: true,
    ),

    'lp_cry': QuestSegment(
      id: 'lp_cry',
      content:
          'Tears spill over. "I — I — I can\'t remember!"\n\n'
          'Dad kneels down. "Hey. Hey. It\'s okay to cry. We\'re going to find '
          'Pepper. You don\'t have to be perfect to help."\n\n'
          'He hands you a tissue. You both walk outside together.\n\n'
          'Pepper is pawing at the gate from the OUTSIDE.\n\n'
          'You sob and laugh at the same time.\n\n'
          'You didn\'t have to know everything. '
          'You just had to tell someone.',
      isEnding: true,
    ),

    'lp_help': QuestSegment(
      id: 'lp_help',
      content:
          'You stop. You wipe your eyes.\n\n'
          '"DAAAD!" you call. "Dad, come help!"\n\n'
          'He\'s there in seconds. "What\'s wrong?"\n\n'
          '"Pepper. I can\'t find Pepper."\n\n'
          'He doesn\'t panic. He says, "Good job telling me. Two of us looking '
          'is way better than one."\n\n'
          'You find Pepper together, behind the neighbor\'s flowerpots.\n\n'
          'Your bravest move was knowing when to ask.',
      isEnding: true,
    ),

    'lp_front': QuestSegment(
      id: 'lp_front',
      content:
          'You jog around to the front yard.\n\n'
          'Pepper is on the front step.\n\n'
          'Just sitting there. Like, "Where have YOU been?"\n\n'
          'You drop down and bury your face in Pepper\'s fur.\n\n'
          'Your heart is still doing the fast thing — but it\'s slowing now.\n\n'
          'Next time, you\'ll tell a grown-up first. '
          'But this time, your dog was just one yard away the whole time.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST: Three Sleeps Until  [Explorer: ages 6-8]
// Missing a grown-up who's away — work trip, hospital, deployment.
// ═══════════════════════════════════════════════════════════════════════════════

const questMissingGrownup = LifeQuestScenario(
  id: 'missing_grownup',
  title: 'Three Sleeps Until',
  hook: 'Mom is away for a few days. The house feels different.',
  emoji: '🏠',
  emotions: ['sad', 'lonely', 'worried'],
  recommendedBands: [AgeBand.explorer],
  startSegmentId: 'mg_start',
  grownupTip:
      "Ask: 'Who do you miss the most when they\\'re far away? "
      "What helps the missing feeling get smaller?'",
  segments: {
    'mg_start': QuestSegment(
      id: 'mg_start',
      content:
          'Mom\'s away for work. Three more sleeps.\n\n'
          'You knew it was happening. You helped her pack. You waved at the '
          'window when the taxi pulled away.\n\n'
          'But now it\'s the second night. And the house sounds different. '
          'The kitchen is quiet. The chair where Mom reads is empty. '
          'Even the fridge hums different.\n\n'
          '«You squeeze {companion} a little tighter than usual.»\n\n'
          'A big lump comes up in your throat.\n\n'
          'What do you do with the missing feeling?',
      choices: [
        QuestChoice(
          id: 'mg_c1a',
          text: 'Curl up and hide it under the blanket',
          nextSegmentId: 'mg_hide',
        ),
        QuestChoice(
          id: 'mg_c1b',
          text: 'Go find Dad and tell him you miss her',
          nextSegmentId: 'mg_share',
        ),
      ],
    ),

    'mg_hide': QuestSegment(
      id: 'mg_hide',
      content:
          'You burrow under the blanket. The missing feeling is still there. '
          'It might even be growing.\n\n'
          'After a while, Dad knocks softly. "Hey. Want to come watch the end '
          'of the game with me?"\n\n'
          'You\'re not really in a game mood. But you\'re not really in an '
          'alone mood either.',
      copingBreakId: 'hot_cocoa_breath',
      choices: [
        QuestChoice(
          id: 'mg_c2a',
          text: 'Come out and sit on the couch with him',
          nextSegmentId: 'mg_couch',
        ),
        QuestChoice(
          id: 'mg_c2b',
          text: 'Ask if you can call Mom to say goodnight',
          nextSegmentId: 'mg_call',
        ),
      ],
    ),

    'mg_share': QuestSegment(
      id: 'mg_share',
      content:
          'You pad into the living room. Dad looks up.\n\n'
          '"I miss Mom," you say. Your voice is small.\n\n'
          'Dad pats the spot next to him. "Yeah. Me too."\n\n'
          'You didn\'t know Dad missed her. He\'s a grown-up. You thought maybe '
          'grown-ups don\'t miss as hard.\n\n'
          'They do. They just hide it better sometimes.',
      choices: [
        QuestChoice(
          id: 'mg_c3a',
          text: "Ask Dad to tell you a story about Mom when she was little",
          nextSegmentId: 'mg_story',
        ),
        QuestChoice(
          id: 'mg_c3b',
          text: 'Just sit with him and watch the rain',
          nextSegmentId: 'mg_quiet',
        ),
      ],
    ),

    'mg_couch': QuestSegment(
      id: 'mg_couch',
      content:
          'You shuffle out and flop on the couch.\n\n'
          'Dad doesn\'t make you talk. He just shares his blanket.\n\n'
          'After a while, you say, "I miss Mom."\n\n'
          'Dad nods. "I know, kiddo. Me too. Two more sleeps."\n\n'
          'You count the sleeps on your fingers like you\'re little again.\n\n'
          'Two isn\'t very many. Two is doable.',
      isEnding: true,
    ),

    'mg_call': QuestSegment(
      id: 'mg_call',
      content:
          'Dad nods and dials. Mom picks up on the second ring.\n\n'
          '"Hey, baby! I was just thinking about you."\n\n'
          'You tell her about the spelling test. About what you had for dinner. '
          'About how the cat tried to drink your milk.\n\n'
          'Mom laughs. You laugh.\n\n'
          'Two sleeps from now, you\'ll see her face for real. '
          'Tonight, you got her voice. '
          'And her voice helps a lot.',
      isEnding: true,
    ),

    'mg_story': QuestSegment(
      id: 'mg_story',
      content:
          '"Tell me a story about Mom when she was little," you say.\n\n'
          'Dad lights up. "Ohhh, I have GOOD ones."\n\n'
          'He tells you about the time Mom climbed a tree and got stuck. '
          'About her first dog. About the song she used to make up about '
          'spaghetti.\n\n'
          'You laugh until your stomach hurts.\n\n'
          'Mom feels close again, even though she\'s far away.\n\n'
          'Stories are a kind of magic for missing.',
      isEnding: true,
    ),

    'mg_quiet': QuestSegment(
      id: 'mg_quiet',
      content:
          'You don\'t say anything else for a while. Just lean against Dad. '
          'Just watch the rain make stripes on the window.\n\n'
          'It\'s okay to be sad.\n\n'
          'It\'s okay to miss someone.\n\n'
          'It\'s also okay to not need to fix the missing right away. '
          'Sometimes you just sit with it. '
          'Sometimes you sit with it next to someone.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST: The First Try  [Explorer: ages 6-8]
// First-time-hard-thing — frustration with a new skill, persistence vs giving up.
// ═══════════════════════════════════════════════════════════════════════════════

const questFirstHardThing = LifeQuestScenario(
  id: 'first_hard_thing',
  title: 'The First Try',
  hook: 'You tried. It went bad. You want to throw it across the room.',
  emoji: '🎈',
  emotions: ['frustrated', 'embarrassed', 'angry', 'sad'],
  recommendedBands: [AgeBand.explorer],
  startSegmentId: 'fh_start',
  grownupTip:
      "Ask: 'Tell me about a time something was hard at first. "
      "What made you keep trying — or what helped you take a break?'",
  segments: {
    'fh_start': QuestSegment(
      id: 'fh_start',
      content:
          'You\'re trying to ride a skateboard for the first time.\n\n'
          'You step on. You tip. You fall.\n\n'
          'You step on. You tip. You fall.\n\n'
          'Your knee stings. Your hands are red. There\'s a tiny crowd of kids '
          'at the playground watching, not even watching, just being there, '
          'but it FEELS like watching.\n\n'
          '«{companion} sits on the bench, patient.»\n\n'
          'Your eyes get hot. The skateboard feels like a dumb piece of wood '
          'right now.\n\n'
          'What do you do?',
      choices: [
        QuestChoice(
          id: 'fh_c1a',
          text: "Throw the skateboard down. You're done!",
          nextSegmentId: 'fh_quit',
        ),
        QuestChoice(
          id: 'fh_c1b',
          text: 'Sit down for a minute and breathe',
          nextSegmentId: 'fh_pause',
        ),
      ],
    ),

    'fh_quit': QuestSegment(
      id: 'fh_quit',
      content:
          'You shove the skateboard. It clatters across the pavement.\n\n'
          'You walk away with your fists tight.\n\n'
          'Half a block later, you stop. Your chest feels heavy.\n\n'
          'You\'re not less mad. You\'re just farther from your skateboard.\n\n'
          'A grown-up\'s voice in your head says: "Big feelings are okay. '
          'Big feelings don\'t have to drive."\n\n'
          'What now?',
      choices: [
        QuestChoice(
          id: 'fh_c2a',
          text: 'Go back and pick up the skateboard',
          nextSegmentId: 'fh_back',
        ),
        QuestChoice(
          id: 'fh_c2b',
          text: 'Walk home and try again tomorrow',
          nextSegmentId: 'fh_tomorrow',
        ),
      ],
    ),

    'fh_pause': QuestSegment(
      id: 'fh_pause',
      content:
          'You sit on the curb. Your skateboard sits next to you.\n\n'
          'You take a big breath in. A long breath out.\n\n'
          'Another one.\n\n'
          'You watch a leaf skitter across the parking lot.\n\n'
          'The mad-feeling is still there. But it\'s smaller now. Like it had '
          'too much air before, and you let some of it out.',
      copingBreakId: 'belly_breath',
      choices: [
        QuestChoice(
          id: 'fh_c3a',
          text: 'Try one more time — just one little push',
          nextSegmentId: 'fh_one_more',
        ),
        QuestChoice(
          id: 'fh_c3b',
          text: 'Save it for tomorrow. Today was a try.',
          nextSegmentId: 'fh_enough',
        ),
      ],
    ),

    'fh_back': QuestSegment(
      id: 'fh_back',
      content:
          'You turn around and walk back.\n\n'
          'The skateboard is right where you threw it. Nobody is laughing. '
          'Nobody actually noticed.\n\n'
          'You pick it up. You don\'t step on it. You just hold it.\n\n'
          '"Tomorrow," you say to nobody.\n\n'
          'And that counts. Coming back to pick it up — that\'s the brave part.',
      isEnding: true,
    ),

    'fh_tomorrow': QuestSegment(
      id: 'fh_tomorrow',
      content:
          'You walk home. Slow. The mad-feeling fades a little with every step.\n\n'
          'When you get home, Dad sees your face. He doesn\'t ask twenty '
          'questions. He just says, "Want a snack?"\n\n'
          'You nod.\n\n'
          'You eat crackers. You decide skateboards are stupid. Then later, '
          'right before bed, you decide they\'re only kind of stupid.\n\n'
          'Tomorrow is a new try.',
      isEnding: true,
    ),

    'fh_one_more': QuestSegment(
      id: 'fh_one_more',
      content:
          'You stand up. You step on the skateboard.\n\n'
          'You push — just one push. You wobble.\n\n'
          'You DON\'T fall.\n\n'
          'You roll about three feet and step off.\n\n'
          'Three feet! Three whole feet!\n\n'
          'You let out a laugh you didn\'t mean to.\n\n'
          'Sometimes the difference between "I can\'t" and "I can a little" '
          'is one breath and one more try.',
      isEnding: true,
    ),

    'fh_enough': QuestSegment(
      id: 'fh_enough',
      content:
          'You stand up. You tuck the skateboard under your arm.\n\n'
          '"Today was a try," you say to yourself.\n\n'
          'You walk home. You don\'t feel great. You don\'t feel bad either. '
          'You feel like a kid who tried something hard and stopped before '
          'it broke you.\n\n'
          'That is NOT giving up.\n\n'
          'That\'s called knowing yourself. Tomorrow is another day.',
      isEnding: true,
    ),
  },
);
