import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Centralized helper for retrieving a persistent anonymous user id.
class UserIdentityService {
  static const String _userIdKey = 'story_weaver_user_id';

  const UserIdentityService._();

  static Future<String> getOrCreateUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_userIdKey);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final newId = 'user_${const Uuid().v4()}';
    await prefs.setString(_userIdKey, newId);
    return newId;
  }
}
