import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../config/environment.dart';
import '../../models.dart';
import '../../services/api_service_manager.dart';
import '../../theme/app_theme.dart';
import '../../theme/age_band_asset_resolver.dart';
import '../../theme/age_band_theme.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/magic_ear_button.dart';

/// Step 3: The Adventure Team Selector
/// Updated with audio prompts and consistent typography for young children.
class CompanionSelectorStep extends StatefulWidget {
  final WizardData wizardData;
  final VoidCallback onNext;
  final List<Character> savedCharacters;

  const CompanionSelectorStep({
    super.key,
    required this.wizardData,
    required this.onNext,
    this.savedCharacters = const [],
  });

  @override
  State<CompanionSelectorStep> createState() => _CompanionSelectorStepState();
}

class _CompanionSelectorStepState extends State<CompanionSelectorStep> {
  final Set<String> _selectedCompanions = {};
  final bool _isLoading = false;
  bool _isPetGenerating = false;
  String? _petGeneratingName;

  @override
  void initState() {
    super.initState();
    // Sync with existing wizard data
    _selectedCompanions.addAll(widget.wizardData.selectedCompanions);
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<Companion> get _savedCharacterCompanions {
    return widget.savedCharacters.where((char) {
      return char.name != widget.wizardData.characterName;
    }).map((char) {
      String description = '${char.age} years old';
      if (char.role.isNotEmpty && char.role != 'Hero') {
        description = char.role;
      } else if (char.personalityTraits?.isNotEmpty == true) {
        description = char.personalityTraits!.join(', ');
      } else {
        description = 'Age ${char.age}';
      }

      return Companion(
        id: 'character_${char.id}',
        emoji: _getEmojiForAge(char.age),
        name: char.name,
        color: AppColors.gold,
        greeting: 'Let\'s have an adventure!',
        description: description,
        character: char,
      );
    }).toList();
  }

  String _getEmojiForAge(int age) {
    if (age <= 5) return '👶';
    if (age <= 12) return '🧒';
    if (age <= 18) return '👦';
    if (age <= 60) return '👨';
    return '👴';
  }

  List<Companion> get _magicalCompanions {
    final band = Theme.of(context).extension<AgeBandThemeData>()?.band ?? AgeBand.explorer;

    final List<Companion> defaultCompanions;
    switch (band) {
      case AgeBand.sprout:
        defaultCompanions = [
          Companion(
            id: 'pebble',
            emoji: '🐉',
            name: 'Pebble',
            color: const Color(0xFF9575CD),
            greeting: 'Achoo! ...Oops. That was a sparkle sneeze. It means hello!',
            description: 'A round purple dragon whose roars come out as glittery sneezes. He puffs up as big as he can when something seems scary, which is not very big, and stands in front of you anyway.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'pebble.png'),
          ),
          Companion(
            id: 'robin',
            emoji: '🐦',
            name: 'Robin',
            color: const Color(0xFFE53935),
            greeting: 'CHIRP CHIRP! ...You\'re safe. I checked.',
            description: 'Very small, very loud, completely sure you need protecting. She brings tiny gifts and reports on everything.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'robin.png'),
          ),
          Companion(
            id: 'mochi',
            emoji: '🐱',
            name: 'Mochi',
            color: const Color(0xFFFF8F00),
            greeting: 'Mrow! I found something! Come see, come see!',
            description: 'A round orange kitten whose tail tip sparkles gold when she\'s excited, which is almost always. Her moon charm jingles when she runs toward you.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'mochi.jpg'),
          ),
          Companion(
            id: 'sunny',
            emoji: '🐕',
            name: 'Sunny',
            color: const Color(0xFFFFCA28),
            greeting: 'WoofwoofWOOF! *tail spinning like a helicopter*',
            description: 'A golden pup whose star tag glows when she\'s happy — which is always. Gets there first, bounces back to get you, and guides you in with her whole wagging body.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'sunny.png'),
          ),
        ];
        break;
      case AgeBand.explorer:
        defaultCompanions = [
          Companion(
            id: 'ember',
            emoji: '🐉',
            name: 'Ember',
            color: const Color(0xFFFF7043),
            greeting: 'Your idea? Brilliant. Best one I\'ve heard in a hundred years!',
            description: 'A pink dragon who leaves rainbow trails wherever she flies and cheers for every single one of your ideas. When she gets excited she accidentally shoots stars from her nose.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'ember.png'),
          ),
          Companion(
            id: 'robin',
            emoji: '🐦',
            name: 'Robin',
            color: const Color(0xFFE53935),
            greeting: 'Three chirps: stop. One whistle: safe. Two clicks: run. Ready?',
            description: 'Has a very clear warning system and has launched herself at harmless pinecones. Checks you\'re okay before she\'d ever admit she was worried.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'robin.png'),
          ),
          Companion(
            id: 'clover',
            emoji: '🐱',
            name: 'Clover',
            color: const Color(0xFF66BB6A),
            greeting: 'Found it! Just follow me — I have the map right here.',
            description: 'An orange tabby with round glasses and a compass who knows the way through any enchanted wood. Her stardust spirals when she\'s solving something.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'clover.jpg'),
          ),
          Companion(
            id: 'biscuit',
            emoji: '🐕',
            name: 'Biscuit',
            color: const Color(0xFFFFCA28),
            greeting: 'Ooh! Ooh! I have a wand AND a map! Let\'s go everywhere!',
            description: 'A golden puppy in an adventure vest who aims her wand at the sky and leaves sparkle trails to follow. Her compass spins whenever adventure is close.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'biscuit.jpg'),
          ),
        ];
        break;
      case AgeBand.adventurer:
        defaultCompanions = [
          Companion(
            id: 'atlas',
            emoji: '🐉',
            name: 'Atlas',
            color: const Color(0xFF1E88E5),
            greeting: 'I\'ve mapped three routes. Option two is the most interesting.',
            description: 'A blue-green scholar dragon with a compass medallion who knows every constellation. When the path is unclear he lifts his glasses and calculates. He admits when the map was wrong.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'atlas.jpg'),
          ),
          Companion(
            id: 'robin',
            emoji: '🐦',
            name: 'Robin',
            color: const Color(0xFFE53935),
            greeting: '*three sharp chirps* — wait. One long note. Safe to come.',
            description: 'Very low threshold for danger. Loud, fearless, sometimes wrong, never slower for it. Brings gifts when the danger clears.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'robin.png'),
          ),
          Companion(
            id: 'nyx',
            emoji: '🐈‍⬛',
            name: 'Nyx',
            color: const Color(0xFF7E57C2),
            greeting: 'I know a way through. Follow close.',
            description: 'A sleek black cat wrapped in cosmic purple energy who moves through shadows like smoke. When she trusts you enough to speak first, the information is always worth waiting for.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'nyx.png'),
          ),
          Companion(
            id: 'kodiak',
            emoji: '🐺',
            name: 'Kodiak',
            color: const Color(0xFF5C6BC0),
            greeting: 'I\'ve got your left side. Pack moves together.',
            description: 'A galaxy-furred husky who can read stardust like a map and smell storms three hours before they arrive. Runs ahead, checks back, positions himself on your left without being asked.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'kodiak.jpg'),
          ),
        ];
        break;
      case AgeBand.creator:
        defaultCompanions = [
          Companion(
            id: 'cipher',
            emoji: '🐉',
            name: 'Cipher',
            color: const Color(0xFF1E88E5),
            greeting: 'Interesting. The pieces fit — if you look at it sideways.',
            description: 'A blue-green dragon who breathes orbiting gears and compass roses. Finds the flaw in a plan before it\'s a problem. When the puzzle breaks open, his eyes flash gold.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'cipher.jpg'),
          ),
          Companion(
            id: 'rockin_robin',
            emoji: '🐦',
            name: 'Rockin\' Robin',
            color: const Color(0xFFE53935),
            greeting: 'I have a new sound for this. You\'ll know it when you need it.',
            description: 'Leather jacket, drum sticks, mohawk. Louder than necessary, always right on time. Strong opinions, follows your lead anyway.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'rockin_robin.jpg'),
          ),
          Companion(
            id: 'vesper',
            emoji: '🐈‍⬛',
            name: 'Vesper',
            color: const Color(0xFF7E57C2),
            greeting: 'Something\'s about to change. I can feel it.',
            description: 'A black cat in leather gear trailing purple smoke. Notices the thing that doesn\'t fit the pattern. Has decided, after careful consideration, that you are worth trusting.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'vesper.jpg'),
          ),
          Companion(
            id: 'lore',
            emoji: '🐺',
            name: 'Lore',
            color: const Color(0xFF5C6BC0),
            greeting: 'I know what you\'re building. I want to help.',
            description: 'A white wolf in a scholar\'s cloak who thinks in systems and keeps his word. When he pushes back on a plan he explains why once, clearly, then helps you build it the right way.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'lore.png'),
          ),
        ];
        break;
      case AgeBand.adolescent:
        defaultCompanions = [
          Companion(
            id: 'zephyr',
            emoji: '🐉',
            name: 'Zephyr',
            color: const Color(0xFF43A047),
            greeting: 'Already saw it. Here\'s what we do.',
            description: 'A green hooded dragon who is already three moves ahead and usually right. Not trying to lead — trying to fly at the same altitude.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'zephyr.png'),
          ),
          Companion(
            id: 'rockin_robin',
            emoji: '🐦',
            name: 'Rockin\' Robin',
            color: const Color(0xFFE53935),
            greeting: 'I\'m watching you more than the path right now. You okay?',
            description: 'More precise now, watches the hero more than she scouts. Still loud. Still fearless. Has been wrong about things she was certain of, and it\'s only made her braver.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'rockin_robin.png'),
          ),
          Companion(
            id: 'shade',
            emoji: '🐈‍⬛',
            name: 'Shade',
            color: const Color(0xFF7E57C2),
            greeting: 'That\'s not what you actually believe, is it?',
            description: 'A black panther wreathed in purple energy who reads the room as closely as she reads you. Her loyalty was built deliberately and she knows exactly when.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'shade.png'),
          ),
          Companion(
            id: 'frost',
            emoji: '🐺',
            name: 'Frost',
            color: const Color(0xFF5C6BC0),
            greeting: 'Three moves ahead. Redirect me if I\'m wrong.',
            description: 'A blue-eyed wolf in a dark cloak who is already moving and trusts you to aim him right. Watches your signals as closely as the terrain.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'frost.png'),
          ),
        ];
        break;
      case AgeBand.adult:
        defaultCompanions = [
          Companion(
            id: 'tide',
            emoji: '🐉',
            name: 'Tide',
            color: const Color(0xFF00897B),
            greeting: 'The pattern runs deep here. Let me show you.',
            description: 'An ancient teal dragon who has seen this before and knows which details actually matter. Gives counsel once, with precision, then steps back and lets it land.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'tide.png'),
          ),
          Companion(
            id: 'rockin_robin',
            emoji: '🐦',
            name: 'Rockin\' Robin',
            color: const Color(0xFFE53935),
            greeting: 'I know. I know. I still had to check.',
            description: 'Still the same bird — leather harness, hamsa charm, backpack of maps. Has learned what you actually need. When frightened she stays closer.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'rockin_robin.jpg'),
          ),
          Companion(
            id: 'onyx',
            emoji: '🐆',
            name: 'Onyx',
            color: const Color(0xFF546E7A),
            greeting: 'I know what\'s in the room. So do you.',
            description: 'A dark leopard with amber eyes who has made peace with patience. Names what the room is actually about, without drama, and waits for you to catch up.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'onyx.png'),
          ),
          Companion(
            id: 'cinder',
            emoji: '🐺',
            name: 'Cinder',
            color: const Color(0xFF795548),
            greeting: 'Wind from the east. Here\'s what I see.',
            description: 'A wolf by firelight who has outlasted most certainties. Gives counsel like a key — only when the door is already there. Simply still there after everything.',
            imagePath: AgeBandAssetResolver.companionPath(band, 'cinder.png'),
          ),
        ];
        break;
    }

    final customPets = widget.wizardData.pets.map((pet) {
      final name = pet['name']!;
      return Companion(
        id: name,
        emoji: _getEmojiForSpecies(pet['species']),
        name: name,
        color: AppColors.primary,
        greeting: pet['personality']?.isNotEmpty == true
            ? pet['personality']!
            : 'I am your ${pet['species']}!',
        description: 'Your faithful ${pet['species']} companion',
        generatedAvatar: widget.wizardData.petAvatars[name],
      );
    }).toList();

    // Generic "Bring Your Pet" card — shown when no pet has been added yet
    final yourPetCard = Companion(
      id: 'your_pet',
      emoji: '🐾',
      name: 'Your Pet',
      color: const Color(0xFF8D6E63),
      greeting: 'Add a photo and I\'ll become part of the story!',
      description: 'Bring your real pet along. Add their name, species, and a photo to create their storybook character.',
    );

    return [...customPets, ...defaultCompanions, yourPetCard];
  }

  String _getEmojiForSpecies(String? species) {
    switch (species) {
      case 'Dog':
        return '🐕';
      case 'Cat':
        return '🐱';
      case 'Bird':
        return '🐦';
      case 'Hamster':
        return '🐹';
      case 'Fish':
        return '🐠';
      case 'Bunny':
        return '🐰';
      case 'Reptile':
        return '🦎';
      default:
        return '🐾';
    }
  }

  void _toggleCompanion(Companion companion) {
    // "Your Pet" card is a prompt to add a pet, not a selectable companion
    if (companion.id == 'your_pet') {
      _showAddPetDialog();
      return;
    }
    setState(() {
      if (_selectedCompanions.contains(companion.id)) {
        _selectedCompanions.remove(companion.id);
        widget.wizardData.selectedCompanions.remove(companion.id);
        widget.wizardData.companionNames.remove(companion.name);
      } else {
        _selectedCompanions.add(companion.id);
        if (!widget.wizardData.selectedCompanions.contains(companion.id)) {
          widget.wizardData.selectedCompanions.add(companion.id);
          widget.wizardData.companionNames.add(companion.name);
        }
      }
    });
  }

  void _showAddPetDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedSpecies = 'Dog';
    XFile? pickedPhoto;
    const speciesList = ['Dog', 'Cat', 'Bird', 'Bunny', 'Hamster', 'Fish', 'Reptile', 'Other'];

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2A1A4E),
            titleTextStyle: GoogleFonts.fredoka(
              color: const Color(0xFFFFD700),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            title: const Text('Add Your Pet'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Photo picker
                  GestureDetector(
                    onTap: () async {
                      final source = await showDialog<ImageSource>(
                        context: ctx,
                        builder: (c) => AlertDialog(
                          backgroundColor: const Color(0xFF2A1A4E),
                          title: Text('Pet photo',
                              style: GoogleFonts.fredoka(color: Colors.white)),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(c, ImageSource.camera),
                              child: const Text('📷  Camera'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(c, ImageSource.gallery),
                              child: const Text('🖼️  Gallery'),
                            ),
                          ],
                        ),
                      );
                      if (source == null) return;
                      final picker = ImagePicker();
                      final file = await picker.pickImage(
                          source: source, maxWidth: 800, imageQuality: 75);
                      if (file != null) {
                        setDialogState(() => pickedPhoto = file);
                      }
                    },
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: pickedPhoto != null
                              ? const Color(0xFFFFD700)
                              : Colors.white.withAlpha(60),
                          width: pickedPhoto != null ? 2 : 1,
                        ),
                      ),
                      child: pickedPhoto != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.network(pickedPhoto!.path,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                      pickedPhoto!.path,
                                      fit: BoxFit.cover)),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_a_photo,
                                    color: Color(0xFFD4A0FF), size: 36),
                                const SizedBox(height: 8),
                                Text('Tap to add a photo',
                                    style: GoogleFonts.quicksand(
                                        color: Colors.white.withAlpha(180),
                                        fontSize: 14)),
                                Text('(optional — for magical transformation)',
                                    style: GoogleFonts.quicksand(
                                        color: Colors.white.withAlpha(100),
                                        fontSize: 11)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Pet's name",
                      hintText: 'e.g. Biscuit',
                      labelStyle:
                          TextStyle(color: Colors.white.withAlpha(180)),
                      hintStyle:
                          TextStyle(color: Colors.white.withAlpha(80)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withAlpha(60)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFFFD700)),
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  // Species
                  DropdownButtonFormField<String>(
                    value: selectedSpecies,
                    dropdownColor: const Color(0xFF2A1A4E),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Type of animal',
                      labelStyle:
                          TextStyle(color: Colors.white.withAlpha(180)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withAlpha(60)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFFFD700)),
                      ),
                    ),
                    items: speciesList
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedSpecies = v ?? 'Dog'),
                  ),
                  const SizedBox(height: 12),
                  // Description (optional)
                  TextField(
                    controller: descCtrl,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'What do they look like? (optional)',
                      hintText: 'e.g. fluffy, black and white, floppy ears',
                      labelStyle:
                          TextStyle(color: Colors.white.withAlpha(180)),
                      hintStyle:
                          TextStyle(color: Colors.white.withAlpha(80)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withAlpha(60)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFFFD700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: TextStyle(color: Colors.white.withAlpha(180))),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: pickedPhoto != null
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF7B2FBE),
                  foregroundColor: pickedPhoto != null
                      ? const Color(0xFF1A0A2E)
                      : Colors.white,
                ),
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final species = selectedSpecies;
                  final description = descCtrl.text.trim();
                  final photo = pickedPhoto;
                  Navigator.pop(ctx);
                  _onPetAdded(
                    name: name,
                    species: species,
                    description: description,
                    photo: photo,
                  );
                },
                child: Text(pickedPhoto != null && !(Theme.of(context).extension<AgeBandThemeData>()?.band.isMature ?? false) ? '✨ Make Magic!' : 'Add to Story'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onPetAdded({
    required String name,
    required String species,
    required String description,
    XFile? photo,
  }) {
    setState(() {
      widget.wizardData.pets.add({
        'name': name,
        'species': species,
        'personality': '',
        'color': description,
      });
      _selectedCompanions.add(name);
      widget.wizardData.selectedCompanions.add(name);
      widget.wizardData.companionNames.add(name);
    });

    if (photo != null) {
      _runMagicalPetTransform(
        name: name,
        species: species,
        description: description,
        photo: photo,
      );
    }
  }

  Future<void> _runMagicalPetTransform({
    required String name,
    required String species,
    required String description,
    required XFile photo,
  }) async {
    if (!mounted) return;
    setState(() {
      _isPetGenerating = true;
      _petGeneratingName = name;
    });

    try {
      final photoBytes = await photo.readAsBytes();
      final url = Uri.parse('${Environment.backendUrl}/avatar/generate-pet-avatar');
      final request = http.MultipartRequest('POST', url);
      request.files.add(http.MultipartFile.fromBytes(
        'photo',
        photoBytes,
        filename: photo.name.isNotEmpty ? photo.name : 'pet_photo.jpg',
      ));
      request.fields['pet_name'] = name;
      request.fields['species'] = species;
      request.fields['breed_description'] =
          description.isNotEmpty ? description : species;
      request.fields['owner_favorite_color'] =
          widget.wizardData.favoriteColor.isNotEmpty
              ? widget.wizardData.favoriteColor.toLowerCase()
              : 'blue';
      request.fields['owner_age'] =
          widget.wizardData.characterAge.toString();

      final headers = await ApiServiceManager.authHeaders();
      headers.forEach((key, value) {
        if (key.toLowerCase() != 'content-type') {
          request.headers[key] = value;
        }
      });

      final streamed =
          await request.send().timeout(const Duration(minutes: 3));
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 206) {
        final body =
            jsonDecode(response.body) as Map<String, dynamic>;
        if (body['status'] == 'success') {
          final avatarJson =
              body['avatar'] as Map<String, dynamic>?;
          if (avatarJson != null) {
            final generated = GeneratedAvatar.fromJson(avatarJson);
            setState(() {
              widget.wizardData.petAvatars[name] = generated;
            });
            if (mounted) {
              final msg = response.statusCode == 206
                  ? '${photo.name.isNotEmpty ? name : "Your pet"} is ready — magical look coming soon!'
                  : '✨ $name has been transformed!';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(msg),
                  backgroundColor: const Color(0xFF4CAF50),
                ),
              );
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '$name joined the story — magical image unavailable right now.'),
              backgroundColor: const Color(0xFF6D4C41),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('$name is in the story! (magic transform failed: $e)'),
            backgroundColor: const Color(0xFF6D4C41),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPetGenerating = false;
          _petGeneratingName = null;
        });
      }
    }
  }

  Widget _audioPrompt() {
    return MagicEarButton(
      spokenText: _buildCompanionSpokenText(),
    );
  }

  String _buildCompanionSpokenText() {
    final names = _magicalCompanions.map((c) => c.name).join(', ');
    final age = widget.wizardData.characterAge;
    final band = ageBandFromAge(age <= 0 ? 8 : age);
    final prompt = band.isMature
        ? 'Choose a companion to join your story. Options: $names.'
        : age <= 8
            ? 'Pick a friend to come along! You can choose $names.'
            : 'Pick your companions! Tap one to bring them along. You can choose $names.';
    return prompt;
  }

  @override
  Widget build(BuildContext context) {
    final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;

    return Stack(
      children: [
        SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Section
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _audioPrompt(),
                const SizedBox(width: 8),
                Text(
                  'Choose a Travel Buddy',
                  style: GoogleFonts.cinzelDecorative(
                    color: const Color(0xFFFFD700),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Who will join you on this adventure?',
              style: GoogleFonts.quicksand(
                color: Colors.white.withAlpha(200),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // 1. Saved Characters (Friends)
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_savedCharacterCompanions.isNotEmpty) ...[
              Text(
                'Your Friends',
                style: GoogleFonts.fredoka(
                  color: const Color(0xFFD4A0FF),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _savedCharacterCompanions.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final companion = _savedCharacterCompanions[index];
                  final isSelected = _selectedCompanions.contains(companion.id);
                  return _CompanionCard(
                    companion: companion,
                    isSelected: isSelected,
                    onTap: () => _toggleCompanion(companion),
                    customName: widget.wizardData.companionCustomNames[companion.id],
                    onNameChanged: (name) => setState(() {
                      widget.wizardData.companionCustomNames[companion.id] = name;
                    }),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // 2. Magical Creatures
            Text(
              'Magical Creatures',
              style: GoogleFonts.fredoka(
                color: const Color(0xFFD4A0FF),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ..._magicalCompanions.map((creature) {
              final isSelected = _selectedCompanions.contains(creature.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _CompanionCard(
                  companion: creature,
                  isSelected: isSelected,
                  onTap: () => _toggleCompanion(creature),
                  isMagical: true,
                  customName: widget.wizardData.companionCustomNames[creature.id],
                  onNameChanged: (name) => setState(() {
                    widget.wizardData.companionCustomNames[creature.id] = name;
                  }),
                ),
              );
            }),

            const SizedBox(height: AppSpacing.xxl),

            // Navigation
            if (_selectedCompanions.isNotEmpty)
              Center(
                child: PillButton(
                  emoji: '✨',
                  label: band.companionCTALabel,
                  onTap: widget.onNext,
                  variant: PillButtonVariant.purple,
                  isSelected: true,
                ),
              )
            else
              Center(
                child: TextButton(
                  onPressed: widget.onNext,
                  child: Text(
                    band.band.isMature ? 'Skip' : 'Go Solo',
                    style: GoogleFonts.quicksand(
                      color: Colors.white.withAlpha(150),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
        ), // end SingleChildScrollView
        // Magical pet generation loading overlay
        if (_isPetGenerating)
          Positioned.fill(
            child: Container(
              color: Colors.black.withAlpha(160),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFFFFD700),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '✨ Transforming ${_petGeneratingName ?? "your pet"}...',
                    style: GoogleFonts.fredoka(
                      color: const Color(0xFFFFD700),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sprinkling story magic on your companion!',
                    style: GoogleFonts.quicksand(
                      color: Colors.white.withAlpha(200),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class Companion {
  final String id;
  final String emoji;
  final String name;
  final Color color;
  final String greeting;
  final String description;
  final String? imagePath;
  final Character? character;
  final GeneratedAvatar? generatedAvatar;

  Companion({
    required this.id,
    required this.emoji,
    required this.name,
    required this.color,
    required this.greeting,
    this.description = '',
    this.imagePath,
    this.character,
    this.generatedAvatar,
  });
}

class _CompanionCard extends StatefulWidget {
  final Companion companion;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isMagical;
  final String? customName;
  final ValueChanged<String>? onNameChanged;

  const _CompanionCard({
    required this.companion,
    required this.isSelected,
    required this.onTap,
    this.isMagical = false,
    this.customName,
    this.onNameChanged,
  });

  @override
  State<_CompanionCard> createState() => _CompanionCardState();
}

class _CompanionCardState extends State<_CompanionCard> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
        text: widget.customName ?? widget.companion.name);
  }

  @override
  void didUpdateWidget(_CompanionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isSelected && oldWidget.isSelected) {
      _nameController.text = widget.customName ?? widget.companion.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.isSelected,
      label:
          'Companion: ${widget.companion.name}. ${widget.companion.description}. ${widget.isSelected ? 'Selected' : 'Double tap to select'}',
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.white.withAlpha(20)
                : Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: widget.isSelected
                    ? const Color(0xFFFFD700)
                    : const Color(0xFFD4A0FF).withAlpha(80),
                width: widget.isSelected ? 3 : 1.5),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                        color: const Color(0xFFFFD700).withAlpha(80),
                        blurRadius: 20)
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBackground(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.companion.name,
                            style: GoogleFonts.fredoka(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(widget.companion.description,
                            style: GoogleFonts.quicksand(
                                color: Colors.white.withAlpha(180),
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        // Greeting speech bubble + naming field when selected
                        if (widget.isSelected) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(20),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xFFFFD700).withAlpha(120)),
                            ),
                            child: Text(
                              '"${widget.companion.greeting}"',
                              style: GoogleFonts.quicksand(
                                color: const Color(0xFFFFD700),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () {}, // absorb tap to prevent card deselect
                            child: TextField(
                              controller: _nameController,
                              onChanged: widget.onNameChanged,
                              style: GoogleFonts.quicksand(
                                  color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Companion\'s name',
                                labelStyle: TextStyle(
                                    color: Colors.white.withAlpha(150),
                                    fontSize: 12),
                                filled: true,
                                fillColor: Colors.white.withAlpha(15),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.white.withAlpha(60)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFFFD700)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.isSelected)
                Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Color(0xFFFFD700), shape: BoxShape.circle),
                        child: const Icon(Icons.check,
                            color: Color(0xFF3B2363), size: 20))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (widget.companion.generatedAvatar != null) {
      return Image.memory(
          base64Decode(
              widget.companion.generatedAvatar!.imageBase64.split(',').last),
          height: 120,
          fit: BoxFit.cover);
    }
    if (widget.companion.character?.generatedAvatar != null) {
      final b64 = widget.companion.character!.generatedAvatar!.imageBase64;
      if (b64.startsWith('assets/')) {
        return Image.asset(b64, height: 120, fit: BoxFit.cover);
      }
      return Image.memory(base64Decode(b64.split(',').last),
          height: 120, fit: BoxFit.cover);
    }
    if (widget.companion.imagePath != null) {
      return Image.asset(widget.companion.imagePath!,
          height: 120, fit: BoxFit.cover);
    }
    return Container(
        height: 120,
        color: Colors.white.withAlpha(10),
        child: Center(
            child: Text(widget.companion.emoji,
                style: const TextStyle(fontSize: 50))));
  }
}
