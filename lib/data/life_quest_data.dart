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

  const LifeQuestScenario({
    required this.id,
    required this.title,
    required this.hook,
    required this.emoji,
    required this.emotions,
    this.recommendedBands = const [AgeBand.adventurer, AgeBand.creator, AgeBand.adolescent],
    required this.segments,
    required this.startSegmentId,
  });
}

/// A single narrative segment in a quest.
class QuestSegment {
  final String id;
  final String content; // story prose with interpolation slots
  final List<QuestChoice> choices; // empty = ending segment
  final bool isEnding;

  const QuestSegment({
    required this.id,
    required this.content,
    this.choices = const [],
    this.isEnding = false,
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
  questLeftOut,
  questPeerPressure,
  questSchoolStress,
  questSiblingConflict,
  questBeingTeased,
  questFamilyStress,
  questFeelingDifferent,
  questLosingFriendship,
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
