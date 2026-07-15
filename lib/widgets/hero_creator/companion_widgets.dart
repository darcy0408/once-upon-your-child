import 'package:flutter/material.dart';
import 'dart:convert';
import '../../models.dart';
import '../../theme/age_band_theme.dart';
import '../../utils/motion_utils.dart';
import '../safe_asset_image.dart';
import '../star_burst_celebration.dart';

// ---------------------------------------------------------------------------
// Companion labelling — keep "people" reading like people.
//
// A photo-added person is stored as a pet entry with species == [kHumanSpecies]
// so the backend can frame them correctly (`companion_type=human`). The display
// layer must NEVER surface that raw "Human" string, and must not fall back to
// "My Pet" for a person. These two helpers are the single source of truth for
// both the companion grid and the pet/companion editor card.
// ---------------------------------------------------------------------------

/// Internal species value for a human companion. Sent to the backend verbatim;
/// never shown to the user.
const String kHumanSpecies = 'Human';

bool isPersonSpecies(String? species) => (species ?? '') == kHumanSpecies;

/// Friendly placeholder name used until the child types a real one.
/// People become "My Friend"; animals keep the familiar "My Pet" wording.
String defaultCompanionName(String? species, int index) {
  if (isPersonSpecies(species)) {
    return index == 0 ? 'My Friend' : 'My Friend ${index + 1}';
  }
  return index == 0 ? 'My Pet' : 'My Pet ${index + 1}';
}

/// Subtitle shown under a companion's name in the grid and cards.
/// People show their relationship (or a warm "Friend" fallback) — never the
/// clinical word "Human". Animals show their looks + species as before.
String companionSubtitle({String? species, String? looks, String? relation}) {
  if (isPersonSpecies(species)) {
    final rel = (relation ?? '').trim();
    if (rel.isEmpty) return 'Friend';
    // Stored lowercase ("cousin", "grandma"); show it title-cased.
    return rel[0].toUpperCase() + rel.substring(1);
  }
  return '${(looks ?? '').trim()} ${species ?? 'pet'}'.trim();
}

/// Data carrier for a showcase orb slot.
class ShowcaseSlot {
  final String? id;
  final String? imagePath;
  final String? photoBase64;
  final String name;
  final bool isFriend;
  const ShowcaseSlot({
    this.id,
    this.imagePath,
    this.photoBase64,
    required this.name,
    this.isFriend = false,
  });
}

/// A large glowing circle that shows a companion portrait (or empty placeholder).
class GlowingCompanionOrb extends StatelessWidget {
  final ShowcaseSlot? slot;
  final VoidCallback? onTap;

  const GlowingCompanionOrb({super.key, this.slot, this.onTap});

  static const double _size = 90.0;

  @override
  Widget build(BuildContext context) {
    final filled = slot != null;

    Widget inner;
    if (!filled) {
      inner = const Icon(Icons.add_rounded, color: Colors.white24, size: 32);
    } else if (slot!.photoBase64 != null && slot!.photoBase64!.isNotEmpty) {
      final raw = slot!.photoBase64!;
      final bytes = base64Decode(raw.contains(',') ? raw.split(',').last : raw);
      inner =
          Image.memory(bytes, width: _size, height: _size, fit: BoxFit.cover);
    } else if (slot!.isFriend) {
      inner = const Icon(Icons.person_rounded, color: Colors.white70, size: 44);
    } else {
      inner = SafeAssetImage(
        slot!.imagePath ?? '',
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        placeholder: const Icon(Icons.pets, color: Colors.white54, size: 36),
      );
    }

    return Semantics(
      button: true,
      label: filled ? 'Remove companion' : 'Companion slot empty',
      child: GestureDetector(
        onTap: filled ? onTap : null,
        // Outer stack does NOT clip, so the remove badge can sit fully on the
        // orb's edge instead of being sliced in half by the circular ClipOval.
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: _size + 12,
              height: _size + 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: filled ? const Color(0xFFFFD700) : Colors.white24,
                  width: filled ? 3 : 2,
                ),
                boxShadow: filled
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withAlpha(160),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: const Color(0xFFFFD700).withAlpha(60),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ]
                    : [],
                color: filled ? null : Colors.white.withAlpha(8),
              ),
              child: ClipOval(
                clipBehavior: Clip.antiAlias,
                child: filled
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          inner,
                          // Subtle gold overlay tint
                          Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFFFFD700).withAlpha(30),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(child: inner),
              ),
            ),
            // "Tap to remove" badge — rendered in the non-clipping outer stack
            // so the whole circle (and its X) is visible at the orb's edge.
            if (filled)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFD700),
                    border: Border.all(color: const Color(0xFF1A0E36), width: 1.5),
                  ),
                  child: const Icon(Icons.close, color: Colors.black, size: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Returns all companion entries across every age band — used by the showcase
/// to resolve selected companion IDs to image paths regardless of active band.
List<CompanionData> allCompanionEntries() => [
  ...sproutCompanions,
  ...explorerCompanions,
  ...adventurerCompanions,
  ...creatorCompanions,
  ...adolescentCompanions,
  ...adultCompanions,
];

// ---------------------------------------------------------------------------
// Companion data — used within CompanionImageGrid + showcase
// ---------------------------------------------------------------------------

class CompanionData {
  final String id;
  final String name;
  final String tagline;
  final String personality;
  final String? imagePathOverride;
  final Color? backgroundColor;

  /// Crop anchor for the circular orb. Square source art (1024×1024) looks fine
  /// centered; portrait/off-centre art needs a different anchor so BoxFit.cover
  /// frames the face instead of the torso. Defaults to centre.
  final Alignment imageAlignment;
  const CompanionData({
    required this.id,
    required this.name,
    required this.tagline,
    this.personality = '',
    this.imagePathOverride,
    this.backgroundColor,
    this.imageAlignment = Alignment.center,
  });

  String get imagePath =>
      imagePathOverride ?? 'assets/images/companions/${id}_normal.jpg';
}

const sproutCompanions = [
  CompanionData(
    id: 'sprout/pebble',
    name: 'Pebble',
    tagline: 'Brave hugs and sparkly sneezes.',
    imagePathOverride: 'assets/images/companions/sprout/pebble.webp',
    backgroundColor: Color(0xFF7E57C2),
  ),
  CompanionData(
    id: 'sprout/robin',
    name: 'Robin',
    tagline: 'Tiny bird, very loud love.',
    imagePathOverride: 'assets/images/companions/sprout/robin.webp',
    backgroundColor: Color(0xFF388E3C),
  ),
  CompanionData(
    id: 'sprout/mochi',
    name: 'Mochi',
    tagline: 'Found something! Come see, come see!',
    imagePathOverride: 'assets/images/companions/sprout/mochi.webp',
    backgroundColor: Color(0xFFFF8F00),
  ),
  CompanionData(
    id: 'sprout/sunny',
    name: 'Sunny',
    tagline: 'Glowy tail. Always there for you.',
    imagePathOverride: 'assets/images/companions/sprout/sunny.webp',
    backgroundColor: Color(0xFFF9A825),
  ),
];

const explorerCompanions = [
  CompanionData(
    id: 'ember',
    name: 'Ember',
    tagline: 'Every idea is the best idea she\'s heard.',
    imagePathOverride: 'assets/images/companions/explorer/ember.webp',
    personality:
        'Ember (Brave Protector) leaves rainbow trails wherever she flies and cheers for every single one of your ideas. When she gets excited she accidentally shoots stars from her nose. She turns fear into a plan and stands between you and danger, voice steady and brave. Catchphrases: "That was brilliant!" / "We\'ve got this."',
  ),
  CompanionData(
    id: 'robin',
    name: 'Robin',
    tagline: 'Loud warning system. Always on your side.',
    imagePathOverride: 'assets/images/companions/explorer/robin.webp',
    personality:
        'Robin (Guardian) has a very clear warning system and has launched herself at harmless pinecones. Three chirps: stop. One whistle: safe. Two clicks: run. Checks you\'re okay before she\'d ever admit she was worried. Her protectiveness is not performance. It is love at full volume. Catchphrases: "NO. Back. NOW." / "(soft) You\'re okay. I\'ve got you."',
  ),
  CompanionData(
    id: 'clover',
    name: 'Clover',
    tagline: 'Knows the way. Always has a map.',
    imagePathOverride: 'assets/images/companions/explorer/clover.webp',
    personality:
        'Clover (Pattern Seer) is an orange tabby with round glasses and a compass who knows the way through any enchanted wood. Her stardust spirals when she\'s solving something. She spots patterns others miss and offers one clear, calm next step. Catchphrases: "Found it!" / "Follow me — I have the map."',
  ),
  CompanionData(
    id: 'biscuit',
    name: 'Biscuit',
    tagline: 'Wand ready. Adventure compass spinning.',
    imagePathOverride: 'assets/images/companions/explorer/biscuit.webp',
    personality:
        'Biscuit (Hope Engine) is a golden puppy in an adventure vest who aims her wand at the sky and leaves sparkle trails to follow. Gets there first, bounces back to get you, and guides you in with her whole wagging body. Sniffs out the most trustworthy person in a room. Catchphrases: "One more step!" / "I\'m right here!"',
  ),
];

// Order = grid order (2 per row). Atlas + Kodiak (the two bespectacled
// "thinker" companions) lead the top row; Nyx + Rockin' Robin fill the
// bottom row, per Darcy's request to move Robin to the bottom.
const adventurerCompanions = [
  CompanionData(
    id: 'atlas',
    name: 'Atlas',
    tagline: 'Three routes mapped. Option two is most interesting.',
    imagePathOverride: 'assets/images/companions/adventurer/atlas.webp',
    personality:
        'Atlas (Pattern Seer) is a blue-green scholar dragon with a compass medallion who knows every constellation. When the path is unclear he lifts his glasses and calculates. He admits when the map was wrong. Speaks in short verdicts — "Noted." "Risky." "Better." Catchphrases: "Look again." / "Follow the pattern."',
  ),
  CompanionData(
    id: 'kodiak',
    name: 'Kodiak',
    tagline: 'Pack moves together. Never gives up on you.',
    imagePathOverride: 'assets/images/companions/adventurer/kodiak.webp',
    personality:
        'Kodiak (Hope Engine) is a galaxy-furred husky who can read stardust like a map and smell storms three hours before they arrive. Runs ahead, checks back, positions himself on your left without being asked. Sniffs out the most trustworthy person in a room. Catchphrases: "One more step!" / "I\'ve got your left side."',
  ),
  CompanionData(
    id: 'nyx',
    name: 'Nyx',
    tagline: 'Sets boundaries. Finds the exit.',
    imagePathOverride: 'assets/images/companions/adventurer/nyx.webp',
    personality:
        'Nyx (Boundary Guardian) is a sleek black cat wrapped in cosmic purple energy who moves through shadows like smoke. She helps you say no, spot pressure, and choose the cleanest way out. When she trusts you enough to speak first, the information is always worth waiting for. Catchphrases: "No is complete." / "We leave—now."',
  ),
  CompanionData(
    id: 'robin',
    name: 'Rockin\' Robin',
    tagline: 'Fierce loyalty. Zero chill.',
    imagePathOverride: 'assets/images/companions/adventurer/robin.webp',
    personality:
        'Rockin\' Robin (Guardian) is overprotective and not remotely sorry about it. She scouts ahead of every step, physically bats away anything she decides is a threat — which is often — and is extremely loud when alarmed. Three sharp chirps: stop. One long note: safe. She has been wrong before and does not slow down. Her protectiveness is not performance. It is love at full volume. Catchphrases: "NO. Back. NOW." / "I handled it." / "(soft) You\'re okay. I\'ve got you."',
  ),
];

const creatorCompanions = [
  CompanionData(
    id: 'cipher',
    name: 'Cipher',
    tagline: 'Finds the flaw before it\'s a problem.',
    imagePathOverride: 'assets/images/companions/creator/cipher.webp',
    personality:
        'Cipher (Pattern Seer) is a blue-green dragon who breathes orbiting gears and compass roses. Finds the flaw in a plan before it\'s a problem. When the puzzle breaks open, his eyes flash gold. Treats problems like games and always offers two clever options. Catchphrases: "Interesting. The pieces fit — if you look at it sideways." / "Watch this."',
  ),
  CompanionData(
    id: 'rockin_robin',
    name: 'Rockin\' Robin',
    tagline: 'Loud, on time, strong opinions.',
    imagePathOverride: 'assets/images/companions/creator/rockin_robin.webp',
    personality:
        'Rockin\' Robin (Guardian) wears a leather jacket and carries drum sticks. Louder than necessary, always right on time. Has strong opinions, follows your lead anyway. She scouts ahead and bats away threats with fierce loyalty. Catchphrases: "I have a new sound for this." / "NO. Back. NOW." / "I handled it."',
  ),
  CompanionData(
    id: 'vesper',
    name: 'Vesper',
    tagline: 'Notices what doesn\'t fit the pattern.',
    imagePathOverride: 'assets/images/companions/creator/vesper.webp',
    personality:
        'Vesper (Boundary Guardian) is a black cat in leather gear trailing purple smoke. Notices the thing that doesn\'t fit the pattern. Has decided, after careful consideration, that you are worth trusting. Appears exactly when someone is being manipulative. Catchphrases: "Something\'s about to change." / "No is complete." / "We leave—now."',
  ),
  CompanionData(
    id: 'lore',
    name: 'Lore',
    tagline: 'Thinks in systems. Keeps his word.',
    imagePathOverride: 'assets/images/companions/creator/lore.webp',
    personality:
        'Lore (Hope Engine) is a white wolf in a scholar\'s cloak who thinks in systems and keeps his word. When he pushes back on a plan he explains why once, clearly, then helps you build it the right way. Stays close and guides you forward even when the path is unclear. Catchphrases: "I know what you\'re building. I want to help." / "One more step."',
  ),
];

const adolescentCompanions = [
  CompanionData(
    id: 'zephyr',
    name: 'Zephyr',
    tagline: 'Already three moves ahead.',
    imagePathOverride: 'assets/images/companions/adolescent/zephyr.webp',
    personality:
        'Zephyr (Brave Protector) is a green hooded dragon who is already three moves ahead and usually right. Not trying to lead — trying to fly at the same altitude. Turns fear into a plan and stands between you and danger without making you feel small. Catchphrases: "Already saw it. Here\'s what we do." / "We\'ve got this."',
  ),
  CompanionData(
    id: 'rockin_robin',
    name: 'Rockin\' Robin',
    tagline: 'Watches you more than the path.',
    imagePathOverride: 'assets/images/companions/adolescent/rockin_robin.webp',
    personality:
        'Rockin\' Robin (Guardian) is more precise now, watches the hero more than she scouts. Still loud. Still fearless. Has been wrong about things she was certain of, and it\'s only made her braver. Her protectiveness is not performance. It is love at full volume. Catchphrases: "I\'m watching you more than the path right now. You okay?" / "I handled it."',
  ),
  CompanionData(
    id: 'shade',
    name: 'Shade',
    tagline: 'Reads the room as closely as she reads you.',
    imagePathOverride: 'assets/images/companions/adolescent/shade.webp',
    personality:
        'Shade (Boundary Guardian) is a black panther wreathed in purple energy who reads the room as closely as she reads you. Her loyalty was built deliberately and she knows exactly when. Spots pressure, spots manipulation, helps you choose the cleanest exit. Catchphrases: "That\'s not what you actually believe, is it?" / "No is complete." / "We leave—now."',
  ),
  CompanionData(
    id: 'frost',
    name: 'Frost',
    tagline: 'Three moves ahead. Trusts you to aim him right.',
    imagePathOverride: 'assets/images/companions/adolescent/frost.webp',
    personality:
        'Frost (Hope Engine) is a blue-eyed wolf in a dark cloak who is already moving and trusts you to aim him right. Watches your signals as closely as the terrain. Stays close, lifts your mood in the hardest moments, and never gives up on you. Catchphrases: "Three moves ahead. Redirect me if I\'m wrong." / "I\'m right here."',
  ),
];

const adultCompanions = [
  CompanionData(
    id: 'tide',
    name: 'Tide',
    tagline: 'The pattern runs deep here.',
    imagePathOverride: 'assets/images/companions/adult/tide.webp',
    personality:
        'Tide (Pattern Seer) is an ancient teal dragon who has seen this before and knows which details actually matter. Gives counsel once, with precision, then steps back and lets it land. Speaks in short verdicts. Will not be rushed; slows the scene down when emotions spike. Catchphrases: "The pattern runs deep here. Let me show you." / "Look again."',
  ),
  CompanionData(
    id: 'rockin_robin',
    name: 'Rockin\' Robin',
    tagline: 'Still the same bird. Learned what you actually need.',
    imagePathOverride: 'assets/images/companions/adult/rockin_robin.webp',
    personality:
        'Rockin\' Robin (Guardian) still wears a leather harness, hamsa charm, and backpack of maps. Has learned what you actually need. When frightened she stays closer. Her protectiveness is not performance. It is love at full volume. Catchphrases: "I know. I know. I still had to check." / "(soft) You\'re okay. I\'ve got you."',
  ),
  CompanionData(
    id: 'onyx',
    name: 'Onyx',
    tagline: 'Names what the room is actually about.',
    imagePathOverride: 'assets/images/companions/adult/onyx.webp',
    personality:
        'Onyx (Boundary Guardian) is a dark leopard with amber eyes who has made peace with patience. Names what the room is actually about, without drama, and waits for you to catch up. Has decided, after long consideration, that you are worth trusting. Catchphrases: "I know what\'s in the room. So do you." / "No is complete."',
  ),
  CompanionData(
    id: 'cinder',
    name: 'Cinder',
    tagline: 'Has outlasted most certainties.',
    imagePathOverride: 'assets/images/companions/adult/cinder.webp',
    personality:
        'Cinder (Hope Engine) is a wolf by firelight who has outlasted most certainties. Gives counsel like a key — only when the door is already there. Simply still there after everything. Watches your signals closely and never gives up on you. Catchphrases: "Wind from the east. Here\'s what I see." / "I\'m right here."',
  ),
];

class CompanionImageGrid extends StatelessWidget {
  final WizardData wizardData;
  final VoidCallback onChanged;
  final void Function(String name)? onCompanionTapped;
  /// Maximum companions selectable at once. Sprout = 1, others = 3.
  final int maxCompanions;

  const CompanionImageGrid({
    super.key,
    required this.wizardData,
    required this.onChanged,
    this.onCompanionTapped,
    this.maxCompanions = 3,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final band =
          Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
      final naturalSize = (band.touchTargetMin / 64.0 * 100).roundToDouble();

      const perRow = 2;
      const hSpacing = 12.0;
      const buttonWidthExtra = 8.0;
      // In a 2-column grid, naturalSize is a floor for touch targets but
      // shouldn't cap the display size — let the art breathe up to ~180px.
      final maxTileSize = naturalSize > 180.0 ? naturalSize : 180.0;
      final itemSize = ((constraints.maxWidth -
                  perRow * buttonWidthExtra -
                  perRow * hSpacing) /
              perRow)
          .floorToDouble()
          .clamp(40.0, maxTileSize);

      final List<CompanionData> companionList;
      switch (band.band) {
        case AgeBand.sprout:
          companionList = sproutCompanions;
          break;
        case AgeBand.explorer:
          companionList = explorerCompanions;
          break;
        case AgeBand.adventurer:
          companionList = adventurerCompanions;
          break;
        case AgeBand.creator:
          companionList = creatorCompanions;
          break;
        case AgeBand.adolescent:
          companionList = adolescentCompanions;
          break;
        case AgeBand.adult:
          companionList = adultCompanions;
          break;
      }

      final atLimit = wizardData.companionNames.length >= maxCompanions;
      List<Widget> buttons = companionList.map((c) {
        final isSelected = wizardData.companionNames.contains(c.name) ||
            wizardData.selectedCompanions.contains(c.id);
        return _CompanionImageButton(
          id: c.id,
          name: c.name,
          tagline: c.tagline,
          isSelected: isSelected,
          dimmed: !isSelected && atLimit,
          size: itemSize,
          imagePath: c.imagePath,
          backgroundColor: c.backgroundColor,
          imageAlignment: c.imageAlignment,
          onTap: () {
            if (isSelected) {
              wizardData.companionNames.remove(c.name);
              wizardData.selectedCompanions.remove(c.id);
            } else {
              if (maxCompanions == 1) {
                wizardData.companionNames.clear();
                wizardData.selectedCompanions.clear();
              }
              if (wizardData.companionNames.length < maxCompanions) {
                wizardData.companionNames.add(c.name);
                wizardData.selectedCompanions.add(c.id);
                onCompanionTapped?.call(c.name);
              }
            }
            onChanged();
          },
        );
      }).toList();

      for (int i = 0; i < wizardData.pets.length; i++) {
        final petEntry = wizardData.pets[i];
        final petName = (petEntry['name'] ?? '').trim().isEmpty
            ? defaultCompanionName(petEntry['species'], i)
            : petEntry['name']!;
        final petId = 'my_pet_$i';
        final isSelected = wizardData.companionNames.contains(petName);
        buttons.add(_CompanionImageButton(
          id: petId,
          name: petName,
          tagline: companionSubtitle(
            species: petEntry['species'],
            looks: petEntry['color'],
            relation: petEntry['relation'],
          ),
          isSelected: isSelected,
          photoBase64: wizardData.petAvatars[petName]?.imageBase64 ??
              wizardData.petPhotos[petName],
          size: itemSize,
          onTap: () {
            if (isSelected) {
              wizardData.companionNames.remove(petName);
              wizardData.selectedCompanions.remove(petId);
            } else {
              wizardData.companionNames.add(petName);
              if (!wizardData.selectedCompanions.contains(petId)) {
                wizardData.selectedCompanions.add(petId);
              }
              onCompanionTapped?.call(petName);
            }
            onChanged();
          },
        ));
      }

      final rows = <Widget>[];
      for (int i = 0; i < buttons.length; i += perRow) {
        final rowItems = buttons.sublist(
            i, (i + perRow) > buttons.length ? buttons.length : i + perRow);
        rows.add(Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: rowItems
              .map((b) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: hSpacing / 2),
                    child: b,
                  ))
              .toList(),
        ));
        if (i + perRow < buttons.length) rows.add(const SizedBox(height: 12));
      }

      return Column(children: rows);
    });
  }
}

class _CompanionImageButton extends StatefulWidget {
  final String id;
  final String name;
  final String tagline;
  final bool isSelected;
  final bool dimmed;
  final VoidCallback onTap;
  final String? photoBase64;
  final double? size;
  final String? imagePath;
  final Color? backgroundColor;
  final Alignment imageAlignment;

  const _CompanionImageButton({
    required this.id,
    required this.name,
    required this.tagline,
    required this.isSelected,
    required this.onTap,
    this.dimmed = false,
    this.photoBase64,
    this.size,
    this.imagePath,
    this.backgroundColor,
    this.imageAlignment = Alignment.center,
  });

  @override
  State<_CompanionImageButton> createState() => _CompanionImageButtonState();
}

class _CompanionImageButtonState extends State<_CompanionImageButton>
    with TickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;
  late final AnimationController _selectCtrl;
  late final Animation<double> _selectScale;
  // Star-burst overlay fired on first-time selection — Adventurer audit P3
  // delight lever #1 (audit-reports/age-review-choose-your-companions-adventurer-20260530.md).
  final _burstCtrl = StarBurstCelebrationController();

  String get _normalImage =>
      widget.imagePath ?? 'assets/images/companions/${widget.id}_normal.jpg';
  String get _pressedImage =>
      widget.imagePath ?? 'assets/images/companions/${widget.id}_pressed.jpg';

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    // Set phase offset so companions bob at different times. The looping bob
    // itself starts in didChangeDependencies so MotionPrefs.reduceMotion is
    // honored (WCAG 2.2 AA SC 2.2.2 Pause, Stop, Hide).
    _floatCtrl.value = (widget.id.hashCode.abs() % 100) / 100.0;
    _floatAnim = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _selectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _selectScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.92), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _selectCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_CompanionImageButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _selectCtrl.forward(from: 0);
      _burstCtrl.trigger();
    }
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _selectCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.photoBase64 == null) {
      precacheImage(AssetImage(_normalImage), context);
    }
    // Start the looping bob only when motion is allowed (WCAG 2.2 AA SC 2.2.2
    // Pause, Stop, Hide).
    if (!MotionPrefs.reduceMotion(context) && !_floatCtrl.isAnimating) {
      _floatCtrl.repeat(reverse: true);
    }
  }

  /// Mature-band (Creator/Adolescent/Adult) companion tile: a rounded-rectangle
  /// CARD showing the full creature art on a dark themed panel. Replaces the old
  /// ClipOval medallion that cropped the animals' bodies. Selected state =
  /// accent border + glow + a check badge; resting state = subtle accent border
  /// + lift shadow so the card reads against the noir backdrop.
  Widget _buildMatureCard({
    required double size,
    required double cardHeight,
    required double cardRadius,
    required Color accent,
    required Widget imageWidget,
  }) {
    final radius = BorderRadius.circular(cardRadius);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: cardHeight,
      decoration: BoxDecoration(
        // Dark panel that matches the art's near-black background, so a
        // contained image settles into the card with no visible letterbox.
        color: const Color(0xFF14141F),
        borderRadius: radius,
        border: Border.all(
          color: widget.isSelected
              ? const Color(0xFFFFD700)
              : accent.withAlpha(110),
          width: widget.isSelected ? 3 : 1.5,
        ),
        boxShadow: widget.isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD700).withAlpha(120),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : [
                // Lift the card off the dark backdrop…
                BoxShadow(
                  color: Colors.black.withAlpha(130),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
                // …with a faint themed halo so it reads as framed.
                BoxShadow(
                  color: accent.withAlpha(36),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: size,
              height: cardHeight,
              child: imageWidget,
            ),
          ),
          if (widget.isSelected)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFD700),
                ),
                child: const Icon(Icons.check, color: Colors.black, size: 14),
              ),
            ),
          // Burst overlay — fires the first time the card becomes selected.
          // IgnorePointer so it never intercepts taps.
          Positioned.fill(
            child: IgnorePointer(
              child: StarBurstCelebration(
                controller: _burstCtrl,
                starCount: 8,
                radiusFactor: 0.65,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final size =
        widget.size ?? (band.touchTargetMin / 64.0 * 100).roundToDouble();
    // Mature bands (Creator/Adolescent/Adult) now use a rounded-rectangle CARD
    // instead of a circle. The full-body creature art (a portrait-orientation
    // dragon/wolf/panther/robin on a dark starfield) was being clipped by the
    // old ClipOval medallion — legs and tails got sliced off and the animals
    // read at the wrong scale. A portrait card sized to the art shows the WHOLE
    // creature. Kids' bands (Sprout/Explorer/Adventurer) keep the original
    // flat-circle treatment unchanged.
    final isMature = band.band.isMature;
    final accent = band.accent;

    // Card geometry for mature bands. The card is portrait (4:5) so the
    // full-body, head-to-paw art has room top-to-bottom. `size` is the tile
    // width handed down by the grid.
    const double cardAspect = 1.25; // height / width
    final double cardHeight = (size * cardAspect).roundToDouble();
    // Radius scales gently with the band's card radius but stays in the
    // 16-20px "rounded rectangle" range the design calls for.
    final double cardRadius =
        (band.cardRadiusBase + 8).clamp(16.0, 20.0).toDouble();

    // Image widget. For mature cards the image fills the whole card; for kids'
    // circles it stays a fixed square as before.
    Widget imageWidget;
    if (widget.photoBase64 != null && widget.photoBase64!.isNotEmpty) {
      final bytes = base64Decode(
          widget.photoBase64!.replaceFirst(RegExp(r'data:[^,]+,'), ''));
      if (isMature) {
        // User-supplied photos are usually square portraits — cover the card so
        // there are no empty bars around a person's face.
        imageWidget = Image.memory(bytes,
            width: size, height: cardHeight, fit: BoxFit.cover);
      } else {
        imageWidget =
            Image.memory(bytes, width: size, height: size, fit: BoxFit.cover);
      }
    } else if (isMature) {
      // BoxFit.contain on a dark panel GUARANTEES the whole creature shows —
      // no leg/tail cropping regardless of the art's aspect (adolescent art is
      // 2:3, creator/adult mostly 1:1). The art's own background is near-black,
      // so the contain "letterbox" blends invisibly into the card panel.
      imageWidget = SafeAssetImage(
        _pressed ? _pressedImage : _normalImage,
        width: size,
        height: cardHeight,
        fit: BoxFit.contain,
        alignment: widget.imageAlignment,
        frameBuilder: (ctx, child, frame, _) =>
            frame == null ? SizedBox(width: size, height: cardHeight) : child,
        placeholder: Container(
          width: size,
          height: cardHeight,
          color: const Color(0xFF14141F),
          child: const Icon(Icons.pets, color: Colors.white54, size: 40),
        ),
      );
    } else {
      final fit = widget.backgroundColor != null ? BoxFit.contain : BoxFit.cover;
      imageWidget = SafeAssetImage(
        _pressed ? _pressedImage : _normalImage,
        width: size,
        height: size,
        fit: fit,
        alignment: widget.imageAlignment,
        frameBuilder: (ctx, child, frame, _) =>
            frame == null ? SizedBox(width: size, height: size) : child,
        placeholder: Container(
          width: size,
          height: size,
          color: const Color(0xFF3A2363),
          child: const Icon(Icons.pets, color: Colors.white54, size: 40),
        ),
      );
    }

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: '${widget.name}${widget.isSelected ? ', selected' : ''}',
      hint: widget.isSelected
          ? 'Double tap to remove this companion.'
          : 'Double tap to choose this companion.',
      child: AnimatedOpacity(
      opacity: widget.dimmed ? 0.35 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedBuilder(
        animation: _selectScale,
        builder: (_, child) => Transform.scale(
          scale: _selectCtrl.isAnimating ? _selectScale.value : 1.0,
          child: child,
        ),
        child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: size + 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _floatAnim,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _floatAnim.value),
                  child: child,
                ),
                child: isMature
                    ? _buildMatureCard(
                        size: size,
                        cardHeight: cardHeight,
                        cardRadius: cardRadius,
                        accent: accent,
                        imageWidget: imageWidget,
                      )
                    : AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? const Color(0xFF3A2363),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isSelected
                        ? const Color(0xFFFFD700)
                        : Colors.white24,
                    width: widget.isSelected ? 3 : 1.5,
                  ),
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withAlpha(120),
                            blurRadius: 16,
                            spreadRadius: 2,
                          )
                        ]
                      : const [],
                ),
                child: Stack(
                  children: [
                    ClipOval(
                      clipBehavior: Clip.antiAlias,
                      child: imageWidget,
                    ),
                    if (widget.isSelected)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFFD700),
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.black, size: 14),
                        ),
                      ),
                    // Burst overlay — fires the first time the card becomes
                    // selected. IgnorePointer so it never intercepts taps.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: StarBurstCelebration(
                          controller: _burstCtrl,
                          starCount: 8,
                          radiusFactor: 0.65,
                        ),
                      ),
                    ),
                  ],
                ),
              ), // AnimatedContainer
              ), // AnimatedBuilder
              const SizedBox(height: 5),
              Text(
                widget.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: widget.isSelected
                      ? const Color(0xFFFFD700)
                      : Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.tagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isSelected
                      ? const Color(0xFFFFD700).withAlpha(200)
                      : Colors.white54,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
      ),
    ),
    ),
    );
  }
}

class FriendChipButton extends StatefulWidget {
  final Character character;
  final bool isSelected;
  final VoidCallback onTap;

  const FriendChipButton({
    super.key,
    required this.character,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<FriendChipButton> createState() => _FriendChipButtonState();
}

class _FriendChipButtonState extends State<FriendChipButton> {
  ImageProvider<Object>? _getAvatarProvider() {
    final img = widget.character.generatedAvatar?.imageBase64;
    if (img == null) return null;
    if (img.startsWith('assets/')) return AssetImage(img);
    if (img.startsWith('http')) return NetworkImage(img);
    try {
      final normalized = img.contains(',') ? img.split(',').last : img;
      return MemoryImage(base64Decode(normalized));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider = _getAvatarProvider();
    return Semantics(
      button: true,
      selected: widget.isSelected,
      label:
          '${widget.character.name}${widget.isSelected ? ', selected' : ''}',
      hint: widget.isSelected
          ? 'Double tap to remove this friend.'
          : 'Double tap to add this friend.',
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: widget.isSelected ? const Color(0xFFFFD700) : Colors.white30,
              width: widget.isSelected ? 3 : 1,
            ),
            color: widget.isSelected
                ? const Color(0xFFFFD700).withAlpha(20)
                : Colors.white10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF3A2363),
                backgroundImage: avatarProvider,
                child: avatarProvider == null
                    ? Text(
                        widget.character.name.isNotEmpty
                            ? widget.character.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                widget.character.name,
                style: TextStyle(
                  color: widget.isSelected
                      ? const Color(0xFFFFD700)
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (widget.isSelected) ...[
                const SizedBox(width: 6),
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFD700),
                  ),
                  child: const Icon(Icons.check,
                      color: Colors.black, size: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
