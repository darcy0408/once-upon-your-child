// Calls the backend /avatar/transform-superhero endpoint, turning a child's
// existing avatar into a superhero portrait built from their costume + power.
//
// Best-effort by design: every failure path returns null so the caller (the
// reveal screen) can fall back gracefully without ever blocking the wizard.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import 'api_service_manager.dart';

class SuperheroPortraitService {
  /// POSTs [avatarBytes] + the costume/power choice ids to the backend and
  /// returns the generated portrait as a `data:image/...;base64,...` URI, or
  /// null on any error (network, auth, paywall, generation failure).
  ///
  /// Pass [client] to retain ownership of the underlying connection so the
  /// caller can cancel an in-flight request by closing it (MT-285: the reveal
  /// screen closes the client on Skip so a slow transform stops running instead
  /// of churning for up to ~2 minutes). When [client] is supplied the caller is
  /// responsible for closing it; otherwise a transient client is created and
  /// closed here.
  static Future<String?> transform({
    required Uint8List avatarBytes,
    String? costumeColor,
    String? capeStyle,
    String? emblem,
    String? power,
    http.Client? client,
  }) async {
    final url =
        Uri.parse('${Environment.backendUrl}/avatar/transform-superhero');
    final ownsClient = client == null;
    final httpClient = client ?? http.Client();

    Future<http.Response> send() async {
      final request = http.MultipartRequest('POST', url);
      final authHeaders = await ApiServiceManager.authHeaders();
      if (authHeaders.containsKey('Authorization')) {
        request.headers['Authorization'] = authHeaders['Authorization']!;
      }
      request.files.add(
        http.MultipartFile.fromBytes('photo', avatarBytes,
            filename: 'avatar.png'),
      );
      if (costumeColor != null) request.fields['costume_color'] = costumeColor;
      if (capeStyle != null) request.fields['cape_style'] = capeStyle;
      if (emblem != null) request.fields['emblem'] = emblem;
      if (power != null) request.fields['power'] = power;
      final streamed =
          await httpClient.send(request).timeout(const Duration(minutes: 2));
      return http.Response.fromStream(streamed);
    }

    try {
      var response = await send();
      // One transparent retry on an expired token, mirroring the custom-avatar
      // flow in custom_avatar_screen.dart.
      if (response.statusCode == 401) {
        await ApiServiceManager.resetAndReauthenticate();
        response = await send();
      }
      if (response.statusCode != 200) {
        debugPrint('Superhero portrait failed: HTTP ${response.statusCode}');
        return null;
      }
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'success') return null;
      final uri = data['avatar']?['image_base64'] as String?;
      if (uri == null || uri.isEmpty) return null;
      return uri;
    } catch (e) {
      // A caller closing [client] mid-flight surfaces here as a
      // ClientException — treated like any other failure (return null).
      debugPrint('Superhero portrait error: $e');
      return null;
    } finally {
      if (ownsClient) httpClient.close();
    }
  }
}
