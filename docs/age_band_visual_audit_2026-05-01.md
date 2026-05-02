# Age Band Visual Audit - 2026-05-01

## Scope

Validated the hero creator flow across all six age bands using Flutter tests plus Playwright screenshots from a release web build.

## Test Baseline

- `flutter test test/screens/settings_screen_test.dart`: passed, 6 tests.
- `flutter test test/integration/six_band_integration_test.dart`: passed, 79 tests.

The local Flutter debug web server produced blank white Playwright captures after initial navigation, so the screenshot pass used a release build served from `build/web`.

## Screenshot Method

- Built with `flutter build web --dart-define=FLAVOR=development`.
- Served `build/web` locally on port 8090.
- Captured with Playwright Chromium at `1280x720`.
- Seeded onboarding state in local storage, then captured each age band at the four top wizard steps.

## Screenshot Index

| Age band | Hero | Companions | Setting | Story options |
| --- | --- | --- | --- | --- |
| Sprout | [sprout_01_hero.png](age_band_visual_audit_2026-05-01/sprout_01_hero.png) | [sprout_02_companions.png](age_band_visual_audit_2026-05-01/sprout_02_companions.png) | [sprout_03_setting.png](age_band_visual_audit_2026-05-01/sprout_03_setting.png) | [sprout_04_story_options.png](age_band_visual_audit_2026-05-01/sprout_04_story_options.png) |
| Explorer | [explorer_01_hero.png](age_band_visual_audit_2026-05-01/explorer_01_hero.png) | [explorer_02_companions.png](age_band_visual_audit_2026-05-01/explorer_02_companions.png) | [explorer_03_setting.png](age_band_visual_audit_2026-05-01/explorer_03_setting.png) | [explorer_04_story_options.png](age_band_visual_audit_2026-05-01/explorer_04_story_options.png) |
| Adventurer | [adventurer_01_hero.png](age_band_visual_audit_2026-05-01/adventurer_01_hero.png) | [adventurer_02_companions.png](age_band_visual_audit_2026-05-01/adventurer_02_companions.png) | [adventurer_03_setting.png](age_band_visual_audit_2026-05-01/adventurer_03_setting.png) | [adventurer_04_story_options.png](age_band_visual_audit_2026-05-01/adventurer_04_story_options.png) |
| Creator | [creator_01_hero.png](age_band_visual_audit_2026-05-01/creator_01_hero.png) | [creator_02_companions.png](age_band_visual_audit_2026-05-01/creator_02_companions.png) | [creator_03_setting.png](age_band_visual_audit_2026-05-01/creator_03_setting.png) | [creator_04_story_options.png](age_band_visual_audit_2026-05-01/creator_04_story_options.png) |
| Adolescent | [adolescent_01_hero.png](age_band_visual_audit_2026-05-01/adolescent_01_hero.png) | [adolescent_02_companions.png](age_band_visual_audit_2026-05-01/adolescent_02_companions.png) | [adolescent_03_setting.png](age_band_visual_audit_2026-05-01/adolescent_03_setting.png) | [adolescent_04_story_options.png](age_band_visual_audit_2026-05-01/adolescent_04_story_options.png) |
| Adult | [adult_01_hero.png](age_band_visual_audit_2026-05-01/adult_01_hero.png) | [adult_02_companions.png](age_band_visual_audit_2026-05-01/adult_02_companions.png) | [adult_03_setting.png](age_band_visual_audit_2026-05-01/adult_03_setting.png) | [adult_04_story_options.png](age_band_visual_audit_2026-05-01/adult_04_story_options.png) |

## Areas Of Contention

1. Sprout story options: the bottom purple action control is clipped by the viewport in `sprout_04_story_options.png`. This may be acceptable if the page is intentionally scrollable, but at 720p the primary next action is only partially visible.

2. Explorer story options: the "Pick something special!" section begins near the bottom in `explorer_04_story_options.png`, with the option cards mostly below the fold. This looks like a layout/content-density issue for desktop-height viewports.

3. Creator and Adult character gender portraits: the selected portrait cards show a visible checkerboard transparency background in `creator_01_hero.png` and `adult_01_hero.png`. That reads as unfinished asset presentation rather than intentional UI.

4. Creator, Adolescent, and Adult step navigation: steps 2 through 4 land on a mature accordion-style screen, but the section matching the selected top step is not expanded in the captured view. In `creator_03_setting.png` and `adult_04_story_options.png`, the top progress indicator changes while the visible content remains companion tiles plus closed optional sections.

5. Creator, Adolescent, and Adult first step: the required "Core Archetype" area starts below the fold in the hero screenshots. The first screen shows name, goal, and gender, but the next required choice is cut off at the bottom.

## Clean Passes

- Sprout, Explorer, and Adventurer hero, companion, and setting art all render with age-appropriate imagery and no blank placeholders in the canonical captures.
- Explorer and Adventurer story option cards render with icons, labels, and selected states.
- No Playwright page errors were reported during the release-build screenshot pass.
