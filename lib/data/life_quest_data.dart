// lib/data/life_quest_data.dart
//
// Data model and static content for pre-built Life Quest scenarios.
// These are choose-your-own-adventure stories about real-life situations
// that work WITHOUT any AI generation (no BYOK required).
//
// String interpolation slots:
//   {name}      — child's character name
//   {companion} — companion name (or empty)
//   {pronoun}   — "she"/"he"/"they"
//   {Pronoun}   — "She"/"He"/"They"
//   {possessive} — "her"/"his"/"their"

/// A complete pre-built Life Quest scenario with branching paths.
class LifeQuestScenario {
  final String id;
  final String title;
  final String hook; // one-line teaser shown on quest card
  final String emoji;
  /// Which emotions this quest is relevant for (matches badge grid ids).
  final List<String> emotions;
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
    required this.segments,
    required this.startSegmentId,
  });
}

/// A single narrative segment in a quest.
class QuestSegment {
  final String id;
  final String content; // story prose with {name}/{companion} slots
  final List<QuestChoice> choices; // empty = ending segment
  /// If true, this is a final segment (show reflection prompt).
  final bool isEnding;
  /// Optional reflection question shown at endings.
  final String? reflectionPrompt;

  const QuestSegment({
    required this.id,
    required this.content,
    this.choices = const [],
    this.isEnding = false,
    this.reflectionPrompt,
  });
}

/// A choice the reader can make.
class QuestChoice {
  final String id;
  final String text; // choice label shown to user
  final String nextSegmentId; // which segment this leads to

  const QuestChoice({
    required this.id,
    required this.text,
    required this.nextSegmentId,
  });
}

/// Applies string interpolation to quest text.
String interpolateQuest(
  String text, {
  required String name,
  String companion = '',
  String pronoun = 'they',
  String pronounCap = 'They',
  String possessive = 'their',
}) {
  return text
      .replaceAll('{name}', name)
      .replaceAll('{companion}', companion)
      .replaceAll('{Pronoun}', pronounCap)
      .replaceAll('{pronoun}', pronoun)
      .replaceAll('{possessive}', possessive);
}

// ─────────────────────────────────────────────────────────────────────────────
// Quest Library
// ─────────────────────────────────────────────────────────────────────────────

/// All available pre-built quests.
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
// QUEST 1: Left Out
// ═══════════════════════════════════════════════════════════════════════════════

const questLeftOut = LifeQuestScenario(
  id: 'left_out',
  title: 'The Empty Seat',
  hook: 'Your friends made plans without you.',
  emoji: '\u{1F494}',
  emotions: ['sad', 'worried', 'angry', 'embarrassed'],
  startSegmentId: 'lo_start',
  segments: {
    'lo_start': QuestSegment(
      id: 'lo_start',
      content:
          '{name} walks into the cafeteria on Monday and sees something that '
          'makes {possessive} stomach drop. The usual table — the one where '
          '{name} has sat every single day this year — is full. Not just full. '
          'Rearranged. There are extra chairs pulled up, and everyone is '
          'laughing about something on someone\'s phone. A weekend trip to '
          'the waterpark. Nobody mentioned it. Nobody texted. {name} stands '
          'there holding {possessive} lunch tray, feeling like the floor just '
          'tilted sideways.',
      choices: [
        QuestChoice(
          id: 'lo_c1a',
          text: 'Sit at the table anyway and act normal',
          nextSegmentId: 'lo_sit',
        ),
        QuestChoice(
          id: 'lo_c1b',
          text: 'Find a different table and eat alone',
          nextSegmentId: 'lo_alone',
        ),
        QuestChoice(
          id: 'lo_c1c',
          text: 'Walk up and ask "Why wasn\'t I invited?"',
          nextSegmentId: 'lo_confront',
        ),
      ],
    ),
    'lo_sit': QuestSegment(
      id: 'lo_sit',
      content:
          '{name} slides into the only open chair at the edge of the table. '
          'Everyone says hi, but the conversation keeps rolling about the '
          'waterpark — the slide that was terrifying, the nachos that were '
          'amazing, the sunburn Jayden got on his ears. Nobody asks {name} '
          'about {possessive} weekend. It\'s like being in a room full of '
          'people and being completely invisible. {name}\'s throat feels '
          'tight. The food doesn\'t taste like anything.',
      choices: [
        QuestChoice(
          id: 'lo_c2a',
          text: 'Jump into the conversation — ask about the slide',
          nextSegmentId: 'lo_join_convo',
        ),
        QuestChoice(
          id: 'lo_c2b',
          text: 'Stay quiet and text someone else under the table',
          nextSegmentId: 'lo_text',
        ),
        QuestChoice(
          id: 'lo_c2c',
          text: 'Say "Sounds fun. Wish someone had told me."',
          nextSegmentId: 'lo_honest',
        ),
      ],
    ),
    'lo_alone': QuestSegment(
      id: 'lo_alone',
      content:
          '{name} picks a table in the corner, near the windows. It\'s quiet '
          'here. The food still doesn\'t taste great, but at least nobody can '
          'see the hot feeling behind {possessive} eyes. A kid from science '
          'class — Alex — walks by and pauses. "Hey, mind if I sit? My usual '
          'table is too loud today." Alex sits down and starts talking about '
          'the weird thing that happened in lab, and slowly the knot in '
          '{name}\'s chest loosens a little.',
      choices: [
        QuestChoice(
          id: 'lo_c3a',
          text: 'Tell Alex what happened — be honest',
          nextSegmentId: 'lo_tell_alex',
        ),
        QuestChoice(
          id: 'lo_c3b',
          text: 'Just enjoy the company — don\'t bring it up',
          nextSegmentId: 'lo_enjoy_alex',
        ),
      ],
    ),
    'lo_confront': QuestSegment(
      id: 'lo_confront',
      content:
          '{name} walks right up to the table. "Hey — you all went to the '
          'waterpark this weekend?" The laughter dies down. Maya looks '
          'uncomfortable. "Oh yeah, it was kind of a last-minute thing. '
          'Jayden\'s mom organized it." Jayden shrugs. "There was only room '
          'for five in the car." The silence stretches. {name} can feel '
          'everyone watching.',
      choices: [
        QuestChoice(
          id: 'lo_c4a',
          text: '"Okay. I just wish someone had let me know."',
          nextSegmentId: 'lo_calm_honest',
        ),
        QuestChoice(
          id: 'lo_c4b',
          text: '"Whatever. Doesn\'t matter." — walk away',
          nextSegmentId: 'lo_walk_away',
        ),
        QuestChoice(
          id: 'lo_c4c',
          text: '"Five in the car? That\'s the reason?"',
          nextSegmentId: 'lo_push_back',
        ),
      ],
    ),
    // ── Branch endings ───────────────────────────────────────────────────
    'lo_join_convo': QuestSegment(
      id: 'lo_join_convo',
      content:
          '"Was the big slide actually scary?" {name} asks. Maya turns, '
          'surprised and pleased. "Oh my gosh, YES. I screamed the whole '
          'way down." And just like that, {name} is in the conversation. '
          'It still stings — {name} wasn\'t there, and that part is real. '
          'But sitting here, laughing about Jayden\'s ear sunburn, {name} '
          'realizes something: being left out of one thing doesn\'t mean '
          'being left out of everything. The group didn\'t exclude {name} '
          'on purpose. Sometimes things just happen fast. Later, Maya texts: '
          '"Hey, want to come over Saturday?" {name} smiles at {possessive} '
          'phone. Sometimes you have to show up even when it feels hard.',
      isEnding: true,
      reflectionPrompt: 'Jumping into the conversation took courage. '
          'Have you ever been surprised by how things turned out when you '
          'didn\'t pull away?',
    ),
    'lo_text': QuestSegment(
      id: 'lo_text',
      content:
          '{name} pulls out {possessive} phone under the table and texts '
          'a cousin: "Having the worst lunch." The cousin writes back '
          'right away with a string of memes that make {name} snort-laugh. '
          'Jayden looks over: "What\'s so funny?" {name} shows the meme '
          'and suddenly the table is cracking up about something new — '
          'something {name} brought. The waterpark conversation fades. '
          'It doesn\'t fix the sting completely, but {name} learns '
          'something: when you can\'t change the situation, you can '
          'change what you bring to it.',
      isEnding: true,
      reflectionPrompt: 'Sometimes reaching out to someone outside the '
          'situation helps more than trying to fix things in the moment. '
          'Who do you reach out to when you\'re feeling down?',
    ),
    'lo_honest': QuestSegment(
      id: 'lo_honest',
      content:
          'The words hang in the air: "Sounds fun. Wish someone had told '
          'me." Maya\'s face changes. "Oh — {name}, I\'m sorry. I thought '
          'Jayden invited you." Jayden looks confused. "I thought YOU did." '
          'And there it is — it wasn\'t intentional. It was just a mess-up. '
          'Nobody was trying to leave {name} out. It just... fell through '
          'the cracks. "Next time, I\'m making the group chat," Maya says, '
          'and she means it. {name} nods. The tight feeling in {possessive} '
          'chest loosens. It still hurt. But speaking up — calmly, honestly '
          '— made it possible to fix.',
      isEnding: true,
      reflectionPrompt: 'Being honest about how you feel — without blaming '
          'anyone — can clear things up fast. Is there a time you wish '
          'you had said how you felt?',
    ),
    'lo_tell_alex': QuestSegment(
      id: 'lo_tell_alex',
      content:
          '"My friends went to the waterpark without me," {name} says, '
          'not looking up from {possessive} sandwich. Alex is quiet for '
          'a second. Then: "That sucks. For real." No advice. No trying '
          'to fix it. Just... recognition. It\'s exactly what {name} '
          'needed. They talk about other things — the science project, '
          'the new show everyone\'s watching — and by the end of lunch, '
          '{name} feels lighter. Not fixed, but lighter. Sometimes the '
          'best thing isn\'t solving the problem. It\'s having someone '
          'sit with you in it.',
      isEnding: true,
      reflectionPrompt: 'Alex didn\'t try to fix anything — just listened. '
          'Who in your life is good at just being there?',
    ),
    'lo_enjoy_alex': QuestSegment(
      id: 'lo_enjoy_alex',
      content:
          '{name} decides not to bring it up. Instead, they talk about the '
          'frog that escaped during science lab and how Mr. Torres panicked. '
          'Alex does an impression that\'s so accurate {name} almost spits '
          'out {possessive} juice. By the time the bell rings, {name} '
          'realizes something unexpected: this might have been one of the '
          'better lunches in a while. Sometimes getting bumped out of your '
          'usual routine opens a door you didn\'t know was there. {name} '
          'and Alex walk to class together, still laughing.',
      isEnding: true,
      reflectionPrompt: 'Sometimes a bad situation leads to something '
          'unexpectedly good. Has that ever happened to you?',
    ),
    'lo_calm_honest': QuestSegment(
      id: 'lo_calm_honest',
      content:
          '"I just wish someone had let me know," {name} says, keeping '
          '{possessive} voice steady even though it wants to wobble. Maya '
          'nods. "You\'re right. That was messed up. I\'m sorry." Jayden '
          'looks genuinely embarrassed. "My bad. Seriously." It doesn\'t '
          'erase the weekend, but something shifts. {name} stood up for '
          '{possessive} own feelings without making it a fight, and the '
          'group responded. That\'s not nothing. That\'s actually huge. '
          '{name} sits down, and someone passes the chips.',
      isEnding: true,
      reflectionPrompt: 'Standing up for yourself without starting a fight '
          'is one of the hardest skills there is. When have you done it well?',
    ),
    'lo_walk_away': QuestSegment(
      id: 'lo_walk_away',
      content:
          '{name} turns and walks away, tray in hand. The words "doesn\'t '
          'matter" echo in {possessive} head, but they both know it does. '
          '{name} sits alone and eats in silence. The anger burns hot for '
          'a while, then fades into something heavier. Later, Maya sends '
          'a text: "Hey, are you okay? I feel bad about today." {name} '
          'stares at the message for a long time.',
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
          '{name} types: "Yeah, that hurt." Three dots appear. Maya writes '
          'back: "I\'m really sorry. It was a car situation but I should '
          'have texted you. Want to hang out this weekend, just us?" {name} '
          'takes a breath. It doesn\'t undo today, but it opens a door. '
          '"Yeah. That sounds good." Walking away felt powerful in the '
          'moment, but coming back to be honest? That took even more courage.',
      isEnding: true,
      reflectionPrompt: 'Sometimes we walk away first, then come back '
          'to say the real thing. That\'s okay — what matters is that '
          'you said it eventually.',
    ),
    'lo_leave_read': QuestSegment(
      id: 'lo_leave_read',
      content:
          '{name} puts the phone down. Not to be mean — just because '
          '{pronoun} {pronoun == "they" ? "don\'t" : "doesn\'t"} have the '
          'words yet. And that\'s okay. Not every feeling needs an instant '
          'reply. The next morning, {name} wakes up calmer. The sting is '
          'still there but smaller. At school, {name} sits at the usual '
          'table. Maya catches {possessive} eye and mouths "sorry." {name} '
          'nods. It\'s not all fixed, but it\'s enough for now. Sometimes '
          'the bravest thing is giving yourself time to feel before you '
          'respond.',
      isEnding: true,
      reflectionPrompt: 'Taking time before responding isn\'t ignoring '
          'someone — it\'s taking care of yourself. Do you ever need '
          'time before you\'re ready to talk?',
    ),
    'lo_push_back': QuestSegment(
      id: 'lo_push_back',
      content:
          '"Five in the car? That\'s the reason?" The edge in {name}\'s '
          'voice is sharper than intended. Jayden\'s face hardens. "Dude, '
          'it wasn\'t like a planned thing." The table goes quiet. {name} '
          'can feel the moment tipping — this could become a real fight, '
          'or {name} can pull it back.',
      choices: [
        QuestChoice(
          id: 'lo_c6a',
          text: 'Take a breath. "Sorry. I\'m just hurt."',
          nextSegmentId: 'lo_deescalate',
        ),
        QuestChoice(
          id: 'lo_c6b',
          text: 'Double down: "You could have asked."',
          nextSegmentId: 'lo_double_down',
        ),
      ],
    ),
    'lo_deescalate': QuestSegment(
      id: 'lo_deescalate',
      content:
          '{name} takes a breath. "Sorry. I\'m just hurt. I get that it '
          'was last minute." The tension drops. Jayden nods. "Yeah, I get '
          'it. Next time for real." It\'s not a perfect fix. But {name} '
          'caught {possessive} own anger before it turned into something '
          'bigger. That\'s a skill most adults still struggle with. '
          '{name} sits down, and lunch continues. The sting fades to '
          'something manageable. Sometimes the bravest choice is pulling '
          'yourself back from the edge.',
      isEnding: true,
      reflectionPrompt: 'Catching your anger before it takes over is '
          'really hard. Have you ever managed to pull yourself back '
          'in a tense moment?',
    ),
    'lo_double_down': QuestSegment(
      id: 'lo_double_down',
      content:
          '"You could have asked." Jayden folds his arms. "Okay, {name}, '
          'sorry we didn\'t plan our whole weekend around you." Ouch. The '
          'table is tense. Maya tries: "Can we just—" but the damage is '
          'done. {name} walks away, stomach churning. It doesn\'t feel '
          'like winning. It feels awful. Later, alone, {name} replays '
          'the scene. The hurt was real. But pushing too hard made '
          'everything worse. Tomorrow is another day. Maybe tomorrow '
          '{name} can try again, differently.',
      isEnding: true,
      reflectionPrompt: 'Sometimes being right and handling it well '
          'are two different things. The hurt was real — but pushing '
          'hard made it bigger. What could go differently next time?',
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 2: Peer Pressure
// ═══════════════════════════════════════════════════════════════════════════════

const questPeerPressure = LifeQuestScenario(
  id: 'peer_pressure',
  title: 'The Dare',
  hook: 'Everyone is doing it. Are you?',
  emoji: '\u{1F62C}',
  emotions: ['worried', 'frustrated', 'embarrassed'],
  startSegmentId: 'pp_start',
  segments: {
    'pp_start': QuestSegment(
      id: 'pp_start',
      content:
          'It happens after school at the park. {name}\'s group is hanging '
          'out by the creek when Tyler pulls something out of his backpack — '
          'a can of spray paint. "Who wants to tag the bridge?" A couple kids '
          'laugh nervously. Riley grabs the can. "I\'ll go first." {name} '
          'watches as Riley shakes the can and sprays a wobbly smiley face '
          'on the concrete. Everyone cheers. Tyler holds out the can toward '
          '{name}. "Your turn."',
      choices: [
        QuestChoice(
          id: 'pp_c1a',
          text: '"Nah, I\'m good."',
          nextSegmentId: 'pp_decline',
        ),
        QuestChoice(
          id: 'pp_c1b',
          text: 'Take the can — just a small one',
          nextSegmentId: 'pp_take',
        ),
        QuestChoice(
          id: 'pp_c1c',
          text: 'Make a joke to deflect — "I can\'t even draw on paper"',
          nextSegmentId: 'pp_joke',
        ),
      ],
    ),
    'pp_decline': QuestSegment(
      id: 'pp_decline',
      content:
          '"Nah, I\'m good." Tyler raises an eyebrow. "Seriously? It\'s just '
          'paint." Riley chimes in: "Don\'t be lame." The word stings. {name} '
          'can feel the group watching, deciding. This is the moment where '
          'everything tilts.',
      choices: [
        QuestChoice(
          id: 'pp_c2a',
          text: '"Call me lame. I don\'t care."',
          nextSegmentId: 'pp_stand_firm',
        ),
        QuestChoice(
          id: 'pp_c2b',
          text: '"I gotta go — my mom texted." — leave',
          nextSegmentId: 'pp_excuse',
        ),
      ],
    ),
    'pp_take': QuestSegment(
      id: 'pp_take',
      content:
          '{name} takes the can. It\'s heavier than expected. {name} shakes '
          'it and sprays a star on the bridge — small, quick, done. Everyone '
          'cheers. It felt good for exactly three seconds. Then {name} looks '
          'at the star and realizes: this doesn\'t wash off. And there\'s a '
          'camera on the light post across the path. The good feeling curdles '
          'into dread.',
      choices: [
        QuestChoice(
          id: 'pp_c3a',
          text: 'Say "Guys, there\'s a camera" — warn everyone',
          nextSegmentId: 'pp_warn',
        ),
        QuestChoice(
          id: 'pp_c3b',
          text: 'Quietly put the can down and step back',
          nextSegmentId: 'pp_step_back',
        ),
      ],
    ),
    'pp_joke': QuestSegment(
      id: 'pp_joke',
      content:
          '"I can\'t even draw on paper, let alone a wall." Some kids laugh. '
          'Tyler grins. "Fine, more for us." The attention moves on. {name} '
          'hangs back while the others take turns. Nobody called {name} lame. '
          'Nobody even noticed, really. The joke worked like a shield — '
          'light enough that nobody took offense, firm enough that {name} '
          'didn\'t have to do something {pronoun} didn\'t want to do.',
      choices: [
        QuestChoice(
          id: 'pp_c4a',
          text: 'Stick around and watch',
          nextSegmentId: 'pp_watch',
        ),
        QuestChoice(
          id: 'pp_c4b',
          text: 'Head home — you made your exit',
          nextSegmentId: 'pp_leave_clean',
        ),
      ],
    ),
    // ── Endings ──────────────────────────────────────────────────────────
    'pp_stand_firm': QuestSegment(
      id: 'pp_stand_firm',
      content:
          '"Call me lame. I don\'t care." {name}\'s voice is steady even '
          'though {possessive} heart is hammering. Tyler blinks. Then shrugs. '
          '"Whatever." And that\'s it. The world doesn\'t end. Nobody stops '
          'being {name}\'s friend. Later, walking home, {name}\'s hands are '
          'still a little shaky — but there\'s something else, too. Pride. '
          'The kind you can only feel when you held your ground and it cost '
          'you something. The next day at school, Riley says quietly: '
          '"I kinda wish I hadn\'t done it either."',
      isEnding: true,
      reflectionPrompt: 'Standing firm when everyone else is going along '
          'is one of the hardest things. What helps you hold your ground?',
    ),
    'pp_excuse': QuestSegment(
      id: 'pp_excuse',
      content:
          '{name} pulls out {possessive} phone. "My mom just texted. Gotta '
          'go." It\'s not true, but it works. Nobody argues with the mom card. '
          'Walking home, {name} feels two things at once: relief and a tiny '
          'bit of guilt about lying. But here\'s the thing — sometimes you '
          'need an exit strategy, and "my mom texted" is a perfectly good '
          'one. The important thing is that {name} got out of a situation '
          'that felt wrong. The method was fine. The instinct was right.',
      isEnding: true,
      reflectionPrompt: 'Using an excuse to get out of a bad situation '
          'isn\'t weakness — it\'s strategy. Do you have a go-to exit '
          'line for tricky situations?',
    ),
    'pp_warn': QuestSegment(
      id: 'pp_warn',
      content:
          '"Guys — there\'s a camera." Everyone freezes. Heads turn. Tyler '
          'swears and stuffs the can in his bag. The group scatters. Walking '
          'home, {name}\'s mind races. {Pronoun} already sprayed that star. '
          'It\'s done. But warning everyone else? That was the right call. '
          'At home, {name} stares at the ceiling. Tomorrow {pronoun}\'ll '
          'figure out whether to tell someone. Tonight, {pronoun} just sits '
          'with the fact that {pronoun} made a mistake — and then made a '
          'better choice right after.',
      isEnding: true,
      reflectionPrompt: 'Making a mistake and then making a better choice '
          'right after takes real guts. A bad moment doesn\'t have to '
          'define the whole day.',
    ),
    'pp_step_back': QuestSegment(
      id: 'pp_step_back',
      content:
          '{name} quietly sets the can on the railing and steps back. '
          'Nobody notices — they\'re too busy cheering for Tyler\'s second '
          'round. {name} drifts to the edge of the group, then walks away. '
          'The star is still on the bridge. {name} can\'t un-do it. But '
          '{pronoun} can decide not to do more. And that matters. On the '
          'walk home, {name} thinks about how fast everything happened — '
          'peer pressure doesn\'t feel like pressure in the moment. It '
          'feels like fun. It\'s only after that the weight lands.',
      isEnding: true,
      reflectionPrompt: 'Pressure often doesn\'t feel like pressure — '
          'it feels like fun. Recognizing that difference is a big deal. '
          'What\'s a time you noticed the shift?',
    ),
    'pp_watch': QuestSegment(
      id: 'pp_watch',
      content:
          '{name} hangs back and watches. The others keep spraying until '
          'the bridge looks like a kindergartner\'s art project. It\'s '
          'actually kind of sad up close. When they\'re done, Tyler '
          'high-fives everyone. {name} didn\'t participate, but didn\'t '
          'leave either. On the walk home, {name} wonders: was just '
          'watching okay? Or is standing near it the same as doing it? '
          'There\'s no easy answer. But {name} kept {possessive} hands '
          'clean, and that\'s something.',
      isEnding: true,
      reflectionPrompt: 'Is watching the same as participating? There\'s '
          'no easy answer. What do you think?',
    ),
    'pp_leave_clean': QuestSegment(
      id: 'pp_leave_clean',
      content:
          '{name} waves casually. "Catch you later." And walks. Nobody '
          'follows. Nobody calls after. It\'s anticlimactic and a little '
          'lonely, but also: free. {name} gets home, drops {possessive} '
          'bag, and feels something settle in {possessive} chest. The joke '
          'worked. The exit was clean. No drama, no fight, no paint on '
          '{possessive} hands. Tomorrow the group might have a story about '
          'the bridge. {name}\'s story is different — and that\'s okay.',
      isEnding: true,
      reflectionPrompt: 'A clean exit doesn\'t always feel heroic — '
          'but it is. Sometimes the brave thing looks really quiet.',
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 3: School Stress
// ═══════════════════════════════════════════════════════════════════════════════

const questSchoolStress = LifeQuestScenario(
  id: 'school_stress',
  title: 'The Big Test',
  hook: 'Tomorrow is the test. You\'re not ready.',
  emoji: '\u{1F4DA}',
  emotions: ['worried', 'frustrated', 'sad'],
  startSegmentId: 'ss_start',
  segments: {
    'ss_start': QuestSegment(
      id: 'ss_start',
      content:
          'It\'s 8pm on Thursday night. The math test is tomorrow and {name} '
          'has barely studied. The textbook is open on the desk but the words '
          'are swimming. Fractions, decimals, word problems — it all blurs '
          'together. {name}\'s phone buzzes with group chat messages. '
          '{possessive} stomach is doing that clenching thing it does when '
          'everything feels too big. The clock keeps ticking.',
      choices: [
        QuestChoice(
          id: 'ss_c1a',
          text: 'Close the phone and try to power through',
          nextSegmentId: 'ss_power',
        ),
        QuestChoice(
          id: 'ss_c1b',
          text: 'Ask a parent for help',
          nextSegmentId: 'ss_ask_parent',
        ),
        QuestChoice(
          id: 'ss_c1c',
          text: 'Text a friend: "Are you studying? I\'m lost"',
          nextSegmentId: 'ss_text_friend',
        ),
      ],
    ),
    'ss_power': QuestSegment(
      id: 'ss_power',
      content:
          '{name} puts the phone face-down and stares at the textbook. Twenty '
          'minutes pass. Some of it actually starts clicking — the fraction '
          'stuff, at least. But the word problems still look like another '
          'language. {name}\'s eyes are getting heavy. The brain fog is real.',
      choices: [
        QuestChoice(
          id: 'ss_c2a',
          text: 'Take a 10-minute break, then come back',
          nextSegmentId: 'ss_break',
        ),
        QuestChoice(
          id: 'ss_c2b',
          text: 'Skip the hard stuff and focus on what makes sense',
          nextSegmentId: 'ss_focus_strengths',
        ),
      ],
    ),
    'ss_ask_parent': QuestSegment(
      id: 'ss_ask_parent',
      content:
          '{name} walks into the kitchen where Mom is cleaning up. "Can you '
          'help me study? I\'m kind of freaking out about tomorrow." Mom '
          'looks tired — it\'s been a long day — but she dries her hands '
          'and says, "Show me what you\'re working on." They sit at the '
          'table, and Mom explains word problems the way {name}\'s teacher '
          'never did: with real examples, like splitting a pizza bill. '
          'Something clicks. Not everything, but enough.',
      isEnding: true,
      reflectionPrompt: 'Asking for help when you\'re struggling isn\'t '
          'weakness — it\'s one of the smartest things you can do. '
          'Who would you ask?',
    ),
    'ss_text_friend': QuestSegment(
      id: 'ss_text_friend',
      content:
          '{name} texts Jordan: "Are you studying? I\'m so lost." Jordan '
          'replies: "YES. FaceTime? We can quiz each other." They spend '
          'an hour going through problems together, taking turns being '
          'the teacher. When {name} explains something to Jordan, it '
          'sticks better in {possessive} own brain too. By 9:30, {name} '
          'doesn\'t feel great about the test — but doesn\'t feel '
          'hopeless either. And it was way less lonely than studying alone.',
      isEnding: true,
      reflectionPrompt: 'Studying with someone can make hard things feel '
          'less overwhelming. Who\'s your study buddy — or who could be?',
    ),
    'ss_break': QuestSegment(
      id: 'ss_break',
      content:
          '{name} sets a timer for 10 minutes and walks around the house. '
          'Gets a glass of water. Stretches. Stares out the window at the '
          'dark street. When the timer goes off, something weird happens — '
          '{name} actually wants to go back to studying. The break worked '
          'like a reset button. The word problems are still hard, but '
          '{name}\'s brain isn\'t running on fumes anymore. {name} gets '
          'through three more problems before bed. Not perfect, but real.',
      isEnding: true,
      reflectionPrompt: 'Taking a break when you\'re stuck isn\'t quitting '
          '— it\'s recharging. What does your best break look like?',
    ),
    'ss_focus_strengths': QuestSegment(
      id: 'ss_focus_strengths',
      content:
          '{name} flips past the word problems and drills the fraction and '
          'decimal sections until they\'re solid. It\'s a strategy: bank the '
          'points you can get, don\'t waste time crying over the ones you '
          'can\'t. At the test the next day, the fraction section goes '
          'smoothly. The word problems are rough, but {name} gets partial '
          'credit on two of them. The grade isn\'t amazing, but it\'s not '
          'a disaster either. And {name} learns something: sometimes good '
          'enough is good enough. Perfection isn\'t the only option.',
      isEnding: true,
      reflectionPrompt: 'Focusing on your strengths instead of panicking '
          'about your weaknesses is a real strategy. What are you actually '
          'good at?',
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 4: Sibling Conflict
// ═══════════════════════════════════════════════════════════════════════════════

const questSiblingConflict = LifeQuestScenario(
  id: 'sibling_conflict',
  title: 'The Last Straw',
  hook: 'Your sibling won\'t stop. You\'re about to lose it.',
  emoji: '\u{1F4A2}',
  emotions: ['angry', 'frustrated'],
  startSegmentId: 'sc_start',
  segments: {
    'sc_start': QuestSegment(
      id: 'sc_start',
      content:
          '{name} is in the middle of something important — homework, a '
          'drawing, doesn\'t matter what — when {possessive} younger sibling '
          'barges into the room for the fourth time. "Can I use your markers?" '
          '"Can I watch you?" "Can I sit on your bed?" The answer has been no '
          'every time, but here they are again. The door doesn\'t have a lock. '
          '{name} can feel the anger building like steam in a kettle.',
      choices: [
        QuestChoice(
          id: 'sc_c1a',
          text: 'Yell: "GET OUT OF MY ROOM!"',
          nextSegmentId: 'sc_yell',
        ),
        QuestChoice(
          id: 'sc_c1b',
          text: 'Take a breath and say "I need 30 minutes alone"',
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
          '"GET OUT!" The words come out louder than {name} planned. '
          '{possessive} sibling\'s face crumbles. For one second, there\'s '
          'silence. Then the crying starts — loud, wounded crying. Footsteps '
          'in the hall. A parent appears. "What happened?" And now {name} is '
          'the one in trouble, even though {pronoun} was the one being '
          'bothered. It feels completely unfair.',
      choices: [
        QuestChoice(
          id: 'sc_c2a',
          text: 'Explain what happened — stay calm this time',
          nextSegmentId: 'sc_explain',
        ),
        QuestChoice(
          id: 'sc_c2b',
          text: '"This is so unfair!" — double down',
          nextSegmentId: 'sc_unfair',
        ),
      ],
    ),
    'sc_boundary': QuestSegment(
      id: 'sc_boundary',
      content:
          '{name} takes a breath. It\'s a hard breath — the kind where you '
          'can feel the anger right there, but you hold it. "I need 30 '
          'minutes alone. After that, you can come in." {possessive} sibling '
          'looks disappointed but not hurt. "Okay... 30 minutes?" "30 '
          'minutes." The door closes. {name} sits in the quiet and feels '
          'the steam slowly release. It\'s not perfect — {pronoun}\'ll '
          'have to deal with the sibling again in half an hour. But right '
          'now, this moment of peace was earned, not stolen.',
      isEnding: true,
      reflectionPrompt: 'Setting a time limit ("30 minutes") works better '
          'than just "go away" because it gives the other person something '
          'to hold onto. Have you tried this?',
    ),
    'sc_parent': QuestSegment(
      id: 'sc_parent',
      content:
          '{name} walks past {possessive} sibling and finds Dad in the '
          'living room. "I need help. I\'ve asked them to leave my room four '
          'times and they keep coming back." Dad sighs — the tired sigh of '
          'someone who has mediated this exact fight before. But he gets up '
          'and redirects the sibling with a snack and a show. {name} gets '
          'the room back. It\'s not a long-term fix — tomorrow will probably '
          'be the same — but for now, asking for backup was the right call.',
      isEnding: true,
      reflectionPrompt: 'Asking a parent for help with a sibling conflict '
          'isn\'t tattling — it\'s problem-solving. When is it the right '
          'time to bring in backup?',
    ),
    'sc_explain': QuestSegment(
      id: 'sc_explain',
      content:
          '{name} takes a breath. "They came in my room four times. I asked '
          'them to stop every time. I shouldn\'t have yelled, but I was '
          'really frustrated." The parent pauses. Nods. "I hear you. The '
          'yelling wasn\'t okay, but I understand why you got there." '
          '{name}\'s sibling is still sniffling in the hallway. It\'s not a '
          'clean win — {name} still has to apologize for the yelling. But '
          'explaining {possessive} side calmly, even after the blowup, '
          'showed maturity. The apology comes easier because {name} was '
          'heard first.',
      isEnding: true,
      reflectionPrompt: 'Explaining yourself calmly AFTER you\'ve already '
          'blown up is really hard — but it changes how people hear you. '
          'When have you recovered from a blowup?',
    ),
    'sc_unfair': QuestSegment(
      id: 'sc_unfair',
      content:
          '"This is SO unfair! They bother me all day and I\'M the one who '
          'gets in trouble?" The parent\'s face tightens. "We don\'t yell '
          'in this house." The conversation spirals. Now it\'s not about the '
          'sibling anymore — it\'s about {name}\'s tone. The original '
          'problem is buried under a new fight. {name} ends up in '
          '{possessive} room anyway, but it doesn\'t feel like a win. '
          'It feels like losing twice. Later, the anger fades and {name} '
          'sees it clearly: the unfairness was real, but the delivery '
          'made everything worse.',
      isEnding: true,
      reflectionPrompt: 'The unfairness was real — but how you say it '
          'matters as much as what you say. Have you ever had a good '
          'point that got lost because of how you delivered it?',
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 5: Being Teased
// ═══════════════════════════════════════════════════════════════════════════════

const questBeingTeased = LifeQuestScenario(
  id: 'being_teased',
  title: 'The Comment',
  hook: 'Someone said something that stuck.',
  emoji: '\u{1F62A}',
  emotions: ['sad', 'angry', 'embarrassed'],
  startSegmentId: 'bt_start',
  segments: {
    'bt_start': QuestSegment(
      id: 'bt_start',
      content:
          'It happens in the hallway between classes. {name} is walking past '
          'a group when someone — loud enough for everyone to hear — says '
          'something about {possessive} shoes. Or {possessive} hair. Or the '
          'way {pronoun} answered a question in class. The words themselves '
          'aren\'t the worst part. The worst part is the laughter that '
          'follows. Three or four people, laughing like it\'s the funniest '
          'thing they\'ve heard all day. {name}\'s face goes hot.',
      choices: [
        QuestChoice(
          id: 'bt_c1a',
          text: 'Keep walking — don\'t give them the reaction',
          nextSegmentId: 'bt_keep_walking',
        ),
        QuestChoice(
          id: 'bt_c1b',
          text: 'Fire back with something sharp',
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
          '{name} keeps walking. Shoulders back. Eyes forward. Inside, '
          'everything is screaming, but outside, {pronoun} '
          '{pronoun == "they" ? "look" : "looks"} calm. The laughter fades '
          'behind {possessive} back. In the bathroom, {name} stands at the '
          'sink and looks in the mirror. Breathes. The words are still '
          'buzzing in {possessive} head, but they\'re getting quieter.',
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
          '{name} spins around. The comeback is fast and sharp — something '
          'about the kid\'s backpack that makes the hallway go "OOOH." For '
          'one second, it feels amazing. The kid\'s smirk disappears. But '
          'then the teacher at the end of the hall looks up, and now both '
          'of them are in the spotlight. And {name} realizes: winning the '
          'moment doesn\'t mean winning the day.',
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
          'After class, {name} finds Ms. Chen — the teacher who actually '
          'listens. "Something happened in the hallway and I need to talk '
          'about it." Ms. Chen closes her laptop and gives {name} her full '
          'attention. {name} describes what happened. Ms. Chen nods. "That '
          'wasn\'t okay. I\'m glad you told me." She doesn\'t make a big '
          'scene about it, but she makes a note. And she checks in with '
          '{name} the next day. It doesn\'t erase what happened, but '
          'knowing someone has {possessive} back makes the hallway feel '
          'a little less scary.',
      isEnding: true,
      reflectionPrompt: 'Telling a trusted adult isn\'t snitching — it\'s '
          'protecting yourself. Who\'s your "Ms. Chen" — the adult who '
          'actually listens?',
    ),
    'bt_text_friend': QuestSegment(
      id: 'bt_text_friend',
      content:
          '{name} texts Sam: "Someone just made fun of me in the hall." '
          'Sam replies instantly: "WHO. I will fight them." {name} laughs — '
          'not because it\'s funny, but because Sam\'s loyalty is so fierce '
          'it breaks through the bad feeling. They spend ten minutes going '
          'back and forth, and by the end, the comment feels smaller. Not '
          'gone, but smaller. Having someone who\'s completely on your side '
          'doesn\'t fix the world, but it makes it livable.',
      isEnding: true,
      reflectionPrompt: 'Having someone who\'s immediately on your side '
          'can shrink a bad moment. Who\'s that person for you?',
    ),
    'bt_let_go': QuestSegment(
      id: 'bt_let_go',
      content:
          '{name} splashes water on {possessive} face, takes one more breath, '
          'and walks to class. The comment plays on repeat for another hour, '
          'then starts to fade. By lunch, it\'s background noise. By the end '
          'of the day, it\'s almost gone. {name} didn\'t fight back, didn\'t '
          'report it, didn\'t make it a thing. Sometimes that\'s a choice '
          'too — deciding that someone else\'s words don\'t get to live in '
          'your head rent-free.',
      isEnding: true,
      reflectionPrompt: 'Letting something go isn\'t always passive — '
          'sometimes it\'s a powerful choice. How do you decide what\'s '
          'worth your energy?',
    ),
    'bt_walk_away_after': QuestSegment(
      id: 'bt_walk_away_after',
      content:
          '{name} turns and walks. The hallway buzzes behind {possessive} '
          'back, but {name} doesn\'t look back. The comeback felt good in '
          'the moment, but the aftermath doesn\'t. {name}\'s hands are '
          'shaking a little. At least {pronoun} stopped before it got '
          'worse. That\'s something. Not everything. But something.',
      isEnding: true,
      reflectionPrompt: 'Stopping yourself mid-conflict — even after '
          'you\'ve already fired back — takes real control. What\'s '
          'your signal that it\'s time to walk away?',
    ),
    'bt_escalate': QuestSegment(
      id: 'bt_escalate',
      content:
          'The back-and-forth gets louder. Other kids gather around like '
          'it\'s entertainment. The teacher steps in: "Both of you. Office. '
          'Now." {name} sits in the principal\'s waiting room, stomach '
          'churning. It wasn\'t fair — they started it. But {name} kept it '
          'going. In the end, both kids get a warning. Walking home, {name} '
          'replays it and wishes {pronoun} had walked away after the first '
          'comeback. The satisfaction lasted seconds. The consequences lasted '
          'the rest of the day.',
      isEnding: true,
      reflectionPrompt: 'When someone starts it and you keep it going, '
          'you both end up in trouble. That feels unfair — and it kind '
          'of is. But what would you do differently?',
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 6: Family Stress
// ═══════════════════════════════════════════════════════════════════════════════

const questFamilyStress = LifeQuestScenario(
  id: 'family_stress',
  title: 'Behind Closed Doors',
  hook: 'The house feels heavy tonight.',
  emoji: '\u{1F3E0}',
  emotions: ['sad', 'worried', 'angry'],
  startSegmentId: 'fs_start',
  segments: {
    'fs_start': QuestSegment(
      id: 'fs_start',
      content:
          '{name} is in {possessive} room, door closed, trying to do homework. '
          'But the voices downstairs are hard to ignore. Mom and Dad aren\'t '
          'exactly yelling, but they\'re not not-yelling. The kind of sharp, '
          'tight voices that make {name}\'s stomach clench. It\'s been like '
          'this a lot lately. The homework is impossible to focus on.',
      choices: [
        QuestChoice(
          id: 'fs_c1a',
          text: 'Put on headphones and block it out',
          nextSegmentId: 'fs_headphones',
        ),
        QuestChoice(
          id: 'fs_c1b',
          text: 'Text a friend — just need to talk to someone normal',
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
          '{name} puts on headphones and cranks the music. The voices '
          'disappear under drums and bass. For thirty minutes, {name}\'s '
          'room becomes a separate world. The homework still isn\'t getting '
          'done, but at least the tight feeling in {possessive} chest eases '
          'a little. When {name} takes the headphones off, the house is '
          'quiet. The fight is over — for now. {name} didn\'t fix anything, '
          'but {pronoun} protected {possessive} own peace. That\'s not '
          'nothing.',
      isEnding: true,
      reflectionPrompt: 'Sometimes protecting your own peace is the only '
          'thing you can control. What\'s your version of "headphones on"?',
    ),
    'fs_text': QuestSegment(
      id: 'fs_text',
      content:
          '{name} texts Kai: "What are you up to?" Just normal stuff — not '
          'about the fighting. Kai sends a funny video. Then a meme. Then '
          'they start planning what to do this weekend. For twenty minutes, '
          '{name}\'s world is normal-sized instead of heavy-sized. The '
          'voices downstairs eventually stop, and {name} exhales. Kai '
          'doesn\'t even know what {pronoun} just did — just by being '
          'normal, just by being there, Kai threw {name} a lifeline.',
      isEnding: true,
      reflectionPrompt: 'Sometimes you don\'t need to talk about the hard '
          'thing — you just need someone to be normal with. Who\'s your '
          'lifeline for that?',
    ),
    'fs_intervene': QuestSegment(
      id: 'fs_intervene',
      content:
          '{name} walks downstairs. Both parents stop mid-sentence. "Can '
          'you guys... not do this right now?" The silence is thick. Mom\'s '
          'face softens. "Honey, I\'m sorry you heard that." Dad runs a '
          'hand through his hair. "We\'re just talking. It\'s okay." But '
          'it doesn\'t feel okay. {name} goes back upstairs knowing the '
          'fight will probably continue once {pronoun}\'s out of earshot.',
      choices: [
        QuestChoice(
          id: 'fs_c2a',
          text: 'Write down how you\'re feeling — just for yourself',
          nextSegmentId: 'fs_journal',
        ),
        QuestChoice(
          id: 'fs_c2b',
          text: 'Call Grandma — she always knows what to say',
          nextSegmentId: 'fs_grandma',
        ),
      ],
    ),
    'fs_journal': QuestSegment(
      id: 'fs_journal',
      content:
          '{name} grabs a notebook and writes. Not neat, not organized — '
          'just everything that\'s in {possessive} head. "I hate when they '
          'fight. I feel like it\'s my job to fix it but I can\'t. I wish '
          'they would just be normal." The words on the page look raw and '
          'real. Nobody will read them. That\'s the point. By the time '
          '{name} puts the pen down, the weight has shifted — not gone, '
          'but relocated. Out of {possessive} chest and onto paper. '
          'That\'s how journals work. They don\'t fix anything, but they '
          'make the carrying lighter.',
      isEnding: true,
      reflectionPrompt: 'Writing things down can move feelings from inside '
          'you to outside you. Have you ever tried it?',
    ),
    'fs_grandma': QuestSegment(
      id: 'fs_grandma',
      content:
          'Grandma picks up on the second ring. "Hey, sweetie." Just hearing '
          'her voice makes {name}\'s eyes sting. "Are you okay?" {name} '
          'doesn\'t say everything — just enough. "Mom and Dad are arguing '
          'again." Grandma is quiet for a moment. Then: "That\'s not your '
          'job to fix. You know that, right? Grown-up problems are '
          'grown-up problems." Something in {name}\'s chest unclenches. '
          '"But here\'s what IS your job: take care of you. Go get a snack. '
          'Watch something funny. I\'ll call your mom later." {name} hangs '
          'up feeling lighter. Not because anything is fixed, but because '
          'someone just said the thing {pronoun} needed to hear.',
      isEnding: true,
      reflectionPrompt: '"That\'s not your job to fix." Has anyone ever '
          'told you that — and did it help?',
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 7: Feeling Different
// ═══════════════════════════════════════════════════════════════════════════════

const questFeelingDifferent = LifeQuestScenario(
  id: 'feeling_different',
  title: 'The Only One',
  hook: 'Everyone else seems to fit. You don\'t.',
  emoji: '\u{1F30D}',
  emotions: ['sad', 'worried', 'embarrassed'],
  startSegmentId: 'fd_start',
  segments: {
    'fd_start': QuestSegment(
      id: 'fd_start',
      content:
          'It\'s spirit week at school. Everyone is dressed up for "Twin '
          'Day" — matching outfits, coordinated colors, giggling pairs. '
          '{name} is wearing regular clothes because nobody asked to be '
          '{possessive} twin. It\'s not the end of the world. But walking '
          'through the hallway past all the matching pairs, {name} feels '
          'like a puzzle piece from a different box. It\'s not just today. '
          'It\'s been a lot of days lately.',
      choices: [
        QuestChoice(
          id: 'fd_c1a',
          text: 'Own it — wear the regular clothes like it\'s a statement',
          nextSegmentId: 'fd_own_it',
        ),
        QuestChoice(
          id: 'fd_c1b',
          text: 'Find someone else flying solo and team up',
          nextSegmentId: 'fd_find_solo',
        ),
        QuestChoice(
          id: 'fd_c1c',
          text: 'Skip the hallway — eat lunch in the library',
          nextSegmentId: 'fd_library',
        ),
      ],
    ),
    'fd_own_it': QuestSegment(
      id: 'fd_own_it',
      content:
          '{name} walks through the hallway with {possessive} chin up. "I\'m '
          'going as myself," {pronoun} tells someone who asks. A few kids '
          'laugh — but it\'s the good kind of laugh, the surprised kind. '
          'By third period, two other kids have ditched their twin outfits '
          'because "honestly, it\'s kind of cringe." {name} didn\'t start '
          'a movement on purpose. But sometimes not trying to fit in is '
          'the most interesting thing you can do.',
      isEnding: true,
      reflectionPrompt: 'Owning who you are — even when it\'s not what '
          'everyone else is doing — can be magnetic. When have you '
          'been confidently yourself?',
    ),
    'fd_find_solo': QuestSegment(
      id: 'fd_find_solo',
      content:
          '{name} scans the hallway and spots Dev sitting on a bench, also '
          'in regular clothes, reading a book. {name} sits down. "Twin Day '
          'reject?" Dev laughs. "Proudly." They spend the rest of the morning '
          'making up their own spirit week: "Mismatched Sock Day," "Invisible '
          'Hat Day," "Walk Backwards to Class Day." By lunch, three more kids '
          'have joined the counter-spirit-week. It turns out there are a lot '
          'of puzzle pieces from different boxes. You just have to find them.',
      isEnding: true,
      reflectionPrompt: 'Finding your people doesn\'t mean finding people '
          'like everyone else — it means finding people like you. '
          'Who are your puzzle pieces?',
    ),
    'fd_library': QuestSegment(
      id: 'fd_library',
      content:
          'The library is warm and quiet. The librarian, Mr. Park, nods at '
          '{name} — no questions. {name} picks a spot by the window and '
          'pretends to read, but really just breathes. The twin-day noise '
          'is muffled behind the double doors. It\'s peaceful here. Maybe '
          'too peaceful — the alone feeling is still there.',
      choices: [
        QuestChoice(
          id: 'fd_c2a',
          text: 'Actually start reading — get lost in a story',
          nextSegmentId: 'fd_read',
        ),
        QuestChoice(
          id: 'fd_c2b',
          text: 'Go back out — hiding doesn\'t feel right either',
          nextSegmentId: 'fd_go_back',
        ),
      ],
    ),
    'fd_read': QuestSegment(
      id: 'fd_read',
      content:
          '{name} actually picks up the book and starts reading. It\'s a '
          'story about a kid who moves to a new planet where nobody looks '
          'like them. Ten pages in, {name} is hooked. The character is '
          'brave and weird and doesn\'t apologize for it. By the time '
          'the bell rings, {name} feels something unexpected: inspired. '
          'Not fixed — the different-ness is still there. But seeing it '
          'in a character, seeing it as a strength in a story, makes it '
          'feel less like a flaw and more like a feature.',
      isEnding: true,
      reflectionPrompt: 'Stories can show us that the thing that makes us '
          'different might actually be our superpower. What book or '
          'character has ever made you feel seen?',
    ),
    'fd_go_back': QuestSegment(
      id: 'fd_go_back',
      content:
          '{name} stands up. Hiding isn\'t the answer — not today. Back in '
          'the hallway, the twin-day chaos is still going, but something is '
          'different: {name} chose to come back. That changes the feeling. '
          'Not completely — the not-fitting-in part is still real. But it\'s '
          '{name}\'s choice to be here, not the world forcing {possessive} '
          'hand. In art class, {name} sits next to someone new and they '
          'start talking about music. Sometimes the door you need to walk '
          'through is the one you almost avoided.',
      isEnding: true,
      reflectionPrompt: 'Coming back after wanting to hide takes courage. '
          'Have you ever forced yourself back into a situation and been '
          'glad you did?',
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// QUEST 8: Losing a Friendship
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
          '{name} and Morgan have been best friends since second grade. But '
          'this year, something shifted. Morgan started sitting with the '
          'soccer kids at lunch. Then came the inside jokes {name} didn\'t '
          'get. Then the weekend plans {name} heard about on Monday morning. '
          'Today, {name} walks past the soccer table and Morgan barely looks '
          'up. {name}\'s chest feels hollow, like someone scooped something '
          'out.',
      choices: [
        QuestChoice(
          id: 'lf_c1a',
          text: 'Text Morgan tonight: "Are we okay?"',
          nextSegmentId: 'lf_text',
        ),
        QuestChoice(
          id: 'lf_c1b',
          text: 'Start building other friendships — don\'t wait around',
          nextSegmentId: 'lf_new_friends',
        ),
        QuestChoice(
          id: 'lf_c1c',
          text: 'Say something at school — face to face',
          nextSegmentId: 'lf_face_to_face',
        ),
      ],
    ),
    'lf_text': QuestSegment(
      id: 'lf_text',
      content:
          'That night, {name} types and deletes about six versions before '
          'landing on: "Hey, I feel like we don\'t hang out anymore. Are we '
          'okay?" The three dots appear. Disappear. Appear again. Morgan '
          'writes: "Of course we\'re okay!! I\'ve just been busy with '
          'soccer stuff. Sorry." It sounds genuine. But "busy" and "drifting '
          'away" look the same from the outside.',
      choices: [
        QuestChoice(
          id: 'lf_c2a',
          text: '"Can we hang out this weekend? Just us?"',
          nextSegmentId: 'lf_plan',
        ),
        QuestChoice(
          id: 'lf_c2b',
          text: '"Okay. Just wanted to check." — leave it there',
          nextSegmentId: 'lf_leave_it',
        ),
      ],
    ),
    'lf_new_friends': QuestSegment(
      id: 'lf_new_friends',
      content:
          'Instead of sitting alone or hovering near Morgan\'s table, {name} '
          'sits with the art kids. They\'re weird in the best way — always '
          'drawing on napkins, debating which animated movie has the best '
          'villain. {name} says something about a show and two kids '
          'immediately start quoting it. The hollow feeling doesn\'t '
          'disappear, but it gets a roommate: a warm flicker of something '
          'new.',
      isEnding: true,
      reflectionPrompt: 'Moving toward new people when an old friendship '
          'is fading is brave and scary at the same time. Have you '
          'ever found a friend in an unexpected place?',
    ),
    'lf_face_to_face': QuestSegment(
      id: 'lf_face_to_face',
      content:
          '{name} catches Morgan by the lockers before last period. "Hey, '
          'can we talk for a sec?" Morgan looks surprised, maybe a little '
          'nervous. "Yeah, what\'s up?" {name} takes a breath. "I feel like '
          'we\'re kind of... drifting. And I miss hanging out." Morgan\'s '
          'face goes through about four expressions in two seconds. "I... '
          'didn\'t realize. I\'m sorry. I think I just got caught up in the '
          'soccer thing." They stand there for a moment, and it\'s awkward, '
          'but it\'s real. Morgan says, "Can we get pizza after school '
          'Friday? Like old times?" {name} nods. It might not go back to '
          'the way it was. But at least they\'re talking about it.',
      isEnding: true,
      reflectionPrompt: 'Saying "I miss you" out loud is vulnerable. But '
          'it gives the other person a chance to show up. When have '
          'you been brave enough to say what you actually feel?',
    ),
    'lf_plan': QuestSegment(
      id: 'lf_plan',
      content:
          '"Can we hang out this weekend? Just us?" Morgan replies: "Yes!! '
          'Movie night? Your place?" And just like that, something unclenches. '
          'Saturday comes and it\'s almost like before — popcorn, bad movies, '
          'laughing so hard Morgan snorts juice out of her nose. It\'s not '
          'exactly the same. Morgan talks about the soccer kids a lot. But '
          '{name} realizes something: friendships can have different chapters. '
          'The second-grade chapter is over. But that doesn\'t mean the '
          'story is.',
      isEnding: true,
      reflectionPrompt: 'Friendships change shape over time — that\'s '
          'normal, not a failure. What friendship of yours has changed '
          'but survived?',
    ),
    'lf_leave_it': QuestSegment(
      id: 'lf_leave_it',
      content:
          '"Okay. Just wanted to check." {name} puts the phone down. It '
          'was an honest text and an honest answer. But the distance is '
          'still there. Over the next few weeks, {name} starts to accept '
          'something hard: sometimes friendships change and nobody is the '
          'villain. Morgan isn\'t being mean. {name} isn\'t being dramatic. '
          'People just grow in different directions. It hurts. But {name} '
          'opens {possessive} eyes to who else is around — and discovers '
          'that the world has more people in it than just one best friend.',
      isEnding: true,
      reflectionPrompt: 'Accepting that a friendship is changing — without '
          'anyone being the bad guy — is one of the most mature things '
          'a person can do. Have you ever had to let a friendship evolve?',
    ),
  },
);
