# Sound Effects Assets

This folder contains sound effect audio files for the Story Creator App.

## Required Sound Files

To enable sound effects, add the following audio files to this directory:

### Celebration Sounds
- `achievement.mp3` - General achievement unlocked
- `level_up.mp3` - Level increased
- `badge.mp3` - Badge unlocked
- `star.mp3` - Star collected
- `perfect.mp3` - Perfect score
- `milestone.mp3` - Major milestone reached

### Interaction Sounds
- `tap.mp3` - Button tap
- `button_press.mp3` - Button press
- `success.mp3` - Success action
- `transition.mp3` - Screen transition
- `gem.mp3` - Gem/coin collected

### Educational Sounds
- `word_learned.mp3` - New word learned
- `story_complete.mp3` - Story finished
- `encouragement.mp3` - Encouraging sound for progress

## Where to Get Sounds

### Free Sources:
1. **Freesound.org** (https://freesound.org/)
   - Search for "chime", "bell", "success", "achievement"
   - Choose Creative Commons licensed sounds

2. **Zapsplat** (https://www.zapsplat.com/)
   - Free sound effects library
   - High-quality game sounds

3. **Mixkit** (https://mixkit.co/free-sound-effects/)
   - Free sound effects
   - No attribution required

### Recommendations:
- Format: MP3 or WAV
- Duration: 0.5-2 seconds
- Volume: Normalized to prevent jarring sounds
- Style: Pleasant, child-friendly, uplifting

### Khan Academy Style:
For Khan Academy-like chimes:
- Search for: "bell chime", "xylophone", "glockenspiel"
- Look for: Bright, clean, ascending tones
- Avoid: Harsh, loud, or scary sounds

## Alternative: Use System Sounds

If you don't want to add custom audio files, the app will fall back to using system notification sounds. This works but is less engaging for children.

## File Format Requirements

- **MP3** (recommended) - Universal support, small file size
- **WAV** - Uncompressed, better quality but larger
- **OGG** - Alternative format with good compression

## Testing Your Sounds

After adding audio files:
1. Update `pubspec.yaml` to include this assets folder
2. Restart the app
3. Navigate to Settings > Sound Effects
4. Test each sound effect

## Volume Guidelines

- Keep sounds between -3dB and 0dB peak
- Use audio editing software (Audacity is free) to normalize
- Test on device speakers (not just headphones)
- Sounds should be pleasant at both low and high volume

## License Information

Ensure all sound files are properly licensed for commercial use if you plan to monetize the app. Keep track of:
- Sound file name
- Source/creator
- License type
- Attribution requirements (if any)
