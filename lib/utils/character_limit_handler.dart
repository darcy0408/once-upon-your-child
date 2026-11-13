import 'package:flutter/material.dart';

import '../models/api_error.dart';
import '../paywall_dialog.dart';

/// If [error] is the backend's tier character-cap rejection
/// (HTTP 403, `code: CHARACTER_LIMIT_REACHED`), shows the character-limit
/// dialog using the backend's `characters_limit` and returns true. Returns
/// false for any other error so the caller keeps its normal handling.
Future<bool> showCharacterLimitIfReached(
  BuildContext context,
  Object error,
) async {
  if (error is! ApiError || !error.isCharacterLimitReached) return false;
  if (!context.mounted) return true;
  await PaywallDialog.showCharacterLimitDialog(
    context,
    maxCharacters: error.charactersLimit ?? 1,
  );
  return true;
}
