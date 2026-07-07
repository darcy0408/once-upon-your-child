import 'package:flutter/material.dart';

import '../screens/bedtime_wizard_screen.dart';
import '../theme/age_band_theme.dart';

/// Shows the shared bedtime / voice-story settings dialog (interactive
/// pick-a-path toggle + sleep-timer slider) and pushes [BedtimeWizardScreen]
/// on Start.
///
/// Single source of truth for launching the screen-free story mode — used by
/// the home screen's audio-only entry point and the wizard's top-bar Bedtime
/// button. Pass an empty [childName] / [childAge] of 0 when no character is
/// selected; the bedtime wizard asks for the age by voice when it's 0.
void showBedtimeLaunchSheet(
  BuildContext context, {
  required String childName,
  required int childAge,
}) {
  bool isInteractive = false;
  double timerMinutes = 0; // 0 means off
  final isMature =
      Theme.of(context).extension<AgeBandThemeData>()?.band.isMature ??
          ageBandFromAge(childAge).isMature;
  final dialogTitle = isMature ? 'Voice Story Settings' : 'Bedtime Settings';
  final interactiveTitle =
      isMature ? 'Interactive Voice Adventure' : 'Interactive Bedtime Adventure';
  final interactiveSubtitle = isMature
      ? 'Voice-led pick-a-path story.'
      : 'Voice-led pick-a-path bedtime story.';

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2A1B4E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              dialogTitle,
              style: const TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text(interactiveTitle,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(interactiveSubtitle,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                  value: isInteractive,
                  activeThumbColor: const Color(0xFFFFD700),
                  onChanged: (val) => setDialogState(() => isInteractive = val),
                ),
                const Divider(color: Colors.white24),
                const Text('Sleep Timer',
                    style: TextStyle(color: Colors.white)),
                Slider(
                  value: timerMinutes,
                  min: 0,
                  max: 60,
                  divisions: 6,
                  activeColor: const Color(0xFFFFD700),
                  inactiveColor: Colors.white24,
                  label:
                      timerMinutes == 0 ? 'Off' : '${timerMinutes.round()} min',
                  onChanged: (val) => setDialogState(() => timerMinutes = val),
                ),
                Text(
                  timerMinutes == 0
                      ? 'Timer is Off'
                      : 'Story ends in ${timerMinutes.round()} minutes',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: const Color(0xFF2A1B4E),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => BedtimeWizardScreen(
                        childName: childName,
                        childAge: childAge,
                        isInteractive: isInteractive,
                        timerMinutes: timerMinutes.round(),
                      ),
                    ),
                  );
                },
                child: const Text('Start'),
              ),
            ],
          );
        },
      );
    },
  );
}
