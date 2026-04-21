# Task 5 — BYOK Setup Wizard: Invisible Key + Silent Save Failure

**Model:** Sonnet
**Estimated effort:** 20–30 min

## Background

A user (Darcy) walked through the BYOK setup wizard as an Adult-band user to enable illustration generation. Two problems surfaced:

1. **Pasted API key was invisible.** The cursor advanced some spaces, but no text or obscuring dots appeared in the field.
2. **After pressing Finish, the BYOK state didn't persist.** When the user later selected "Full illustrations" elsewhere in the app, the wizard relaunched from step 0 ("Next: Get My Free Key") — as if nothing had been saved.

## Diagnosis

All in one file: `lib/screens/byok_setup_wizard.dart`.

### Bug 1 — Invisible input (`_EnterKeyStep`, around line 425–521)

Two compounding issues:

- **`obscureText: !_showKey` with `_showKey = false` as the default** (line 430). The field is obscured on open — user sees `•` characters, not the key. Cursor moves because characters *are* being typed; they're just hidden.
- **No explicit text color on the `TextField`** (line 511). The card background is dark (scaffold `0xFF120226` / app bar `0xFF2C1B47` / gradient), but the inherited theme likely uses a dark-ish body text color. The obscuring dots (and any visible text, if `_showKey` were true) render as dark-on-dark, so even the `•` glyphs disappear.

### Bug 2 — Silent save failure (`_EnterKeyStep._validate` at line 439, Finish handler at line 569)

Because the user couldn't see the key, the paste was likely truncated or wrong. That causes `_validate()` to either:

- Fail the `startsWith('AIza')` check at line 456 (if the paste got garbled), OR
- Fail the HTTP ping to `generativelanguage.googleapis.com` at line 467–469 (CORS on web, timeout, or genuine invalid-key 400).

Either way, `_valid` stays `false`. The Finish button handler at line 569 only proceeds when `_valid == true`:

```dart
onPressed: _validating
    ? null
    : () async {
        await _validate();
        if (_valid) {
          final key = _controller.text.trim();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_own_api_key', true);
          await prefs.setBool('is_premium_byok', true);
          await SecureStorageService.saveApiKey('gemini', key);
          if (mounted) widget.onDone(key);
        }
      },
```

When `_valid == false`, the handler **does nothing** — no save, no `onDone`, no visible error. The user sees the `_status` error text (if set) but doesn't realize nothing was persisted. They dismiss the wizard or back out, and other callers (e.g., `story_result_screen`, `settings_screen`, `avatar_gallery_selector`, `upgrade_prompt_dialog`, `parent_controls_screen`) later check `SecureStorageService.getApiKey('gemini')` / `is_premium_byok`, find them empty, and relaunch the wizard at step 0.

The wizard didn't reset — it was freshly re-opened.

## Fix

Make three edits in `lib/screens/byok_setup_wizard.dart`. Do not refactor beyond these — the existing flow is fine once the input is visible and failures are surfaced.

### 1. Default the key to visible (`_showKey = true`)

Line 430:

```dart
bool _showKey = true;  // was: false
```

The user is entering a key they just pasted from Google AI Studio; visibility-by-default matches standard paste-in-key UX. The "Show key (keep private)" checkbox at line 525 still lets them toggle it off.

### 2. Explicit white text style on the `TextField`

Around line 511–520, update the `TextField` to set a white text color and lighten the hint/label so everything reads cleanly on the dark card. Minimal version:

```dart
child: TextField(
  controller: _controller,
  style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
  decoration: InputDecoration(
    labelText: 'API Key',
    hintText: 'AIza...',
    prefixIcon: const Icon(Icons.key, color: Color(0xFFFFD54F)),
    labelStyle: const TextStyle(color: Color(0xB3FFFFFF)),
    hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
  ),
  obscureText: !_showKey,
  maxLines: 1,
),
```

Monospace is optional but matches how API keys render elsewhere. Keep the `Icon(Icons.key)` in gold (`0xFFFFD54F`) to match the screen's accent color.

### 3. Surface save failure so the user knows nothing was persisted

Currently the Finish handler silently no-ops when `_valid` is false. Replace the handler body (around line 569–581) so that after `_validate()`, if `_valid` is still false, a SnackBar makes the failure visible:

```dart
onPressed: _validating
    ? null
    : () async {
        await _validate();
        if (!mounted) return;
        if (_valid) {
          final key = _controller.text.trim();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_own_api_key', true);
          await prefs.setBool('is_premium_byok', true);
          await SecureStorageService.saveApiKey('gemini', key);
          if (mounted) widget.onDone(key);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _status ?? 'Key not saved — please check and try again.',
              ),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
```

This ensures the user understands the key didn't save, rather than silently bouncing back to step 0 in another screen later.

## Out of scope (mention in the commit but don't implement unless asked)

- **Web CORS on the validation probe**: on production web, `generativelanguage.googleapis.com/v1beta/models?key=...` may not allow CORS from the Netlify origin. If that's the case, `_validate()` will fail for every key on web, permanently blocking BYOK. If you can confirm this by testing a real key on the prod web build, flag it to Darcy — the fix is either (a) route the validation probe through the Railway backend, or (b) allow save with `AIza` prefix only (no network probe) on web and validate lazily on first real use. Don't make this change without sign-off — it relaxes a validation gate.

## Verification

Manual browser test (Darcy or you):

1. Run `flutter run -d chrome` (or the equivalent) locally.
2. Navigate to Parent Controls → Use Your Own API Key → step through to Enter Key.
3. Paste a valid Gemini API key.
   - ✅ Key is visible (either as the actual text, since `_showKey = true` by default, or flip the checkbox off and see `•` dots visibly rendered on the dark card).
   - ✅ Press Finish → success state, wizard closes, `onDone` fires.
   - ✅ Open the wizard again from any caller (e.g., Settings) — it should show "key already set" / not relaunch at step 0.
4. Paste an invalid key (e.g., `nope`).
   - ✅ A red SnackBar appears with the validation error.
   - ✅ Wizard stays on the Enter Key step so the user can correct it.

## Deliverable

1. Edits to `lib/screens/byok_setup_wizard.dart` only.
2. Commit: `fix(byok): make pasted key visible on dark card; surface save failures`
3. In the commit body, note the web-CORS follow-up as out of scope pending sign-off.

## Reference files

- `lib/screens/byok_setup_wizard.dart` — all edits live here
- `lib/services/secure_storage_service.dart` — `SecureStorageService.saveApiKey` (existing; no changes needed)
- `lib/services/illustration_preference_service.dart` — illustration prefs (untouched; just context for "Full illustrations" terminology)
- Callers that relaunch the wizard when BYOK isn't set (context only, no changes):
  - `lib/screens/parent_controls_screen.dart:346`
  - `lib/screens/settings_screen.dart:843`
  - `lib/story_result_screen.dart:1401`
  - `lib/widgets/avatar_gallery_selector.dart:430`
  - `lib/dialogs/upgrade_prompt_dialog.dart:127`
