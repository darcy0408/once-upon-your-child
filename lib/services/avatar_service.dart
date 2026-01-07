// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import '../services/isar_service.dart';

import '../data/isar/avatar_cache_entry.dart';

/// Service for generating and caching self-hosted DiceBear avatars
///
/// Features:
/// - Age-gated allowlists with probability controls
/// - Offline-first caching with Isar
/// - Proper comma-separated array formatting for DiceBear URLs
/// - Schema version tracking for cache invalidation
class AvatarService {
  final Isar? isar;
  final Random _random = Random();

  // Configuration loaded from assets
  late final Map<String, dynamic> _config;
  late final Map<String, dynamic> _allowlists;

  // Parsed configuration
  late final String _baseUrl;
  late final String _apiVersion;
  late final String _style;
  late final int _cacheMaxAgeDays;
  late final String _schemaVersion;

  bool _initialized = false;

  AvatarService({this.isar});

  /// Initialize service by loading configuration and allowlists from assets
  Future<void> initialize() async {
    if (_initialized) return;

    // Load avatar_config.json
    final configJson =
        await rootBundle.loadString('assets/config/avatar_config.json');
    _config = json.decode(configJson) as Map<String, dynamic>;

    _baseUrl = (_config['baseUrl'] as String).replaceAll(RegExp(r'/+$'), '');
    _apiVersion = _config['apiVersion'] as String;
    _style = _config['style'] as String;
    _cacheMaxAgeDays = _config['cacheMaxAgeDays'] as int? ?? 30;

    // Load allowlists.json
    final allowlistsJson =
        await rootBundle.loadString('assets/config/allowlists.json');
    _allowlists = json.decode(allowlistsJson) as Map<String, dynamic>;

    // Extract schema version
    final schemaVersionRaw = _allowlists['schemaVersion'] as String;
    _schemaVersion = schemaVersionRaw.replaceFirst('sha256:', '');

    // Validate configuration
    if (_allowlists['style'] != _style) {
      throw StateError(
        'Style mismatch: avatar_config.json has "$_style" but '
        'allowlists.json has "${_allowlists['style']}"',
      );
    }

    _initialized = true;
  }

  /// Ensure service is initialized before use
  void _checkInitialized() {
    if (!_initialized) {
      throw StateError(
          'AvatarService not initialized. Call initialize() first.');
    }
  }

  /// Check if caching is available (Isar is not null)
  bool get _cachingAvailable => isar != null;

  /// Determine age tier from character age
  String _getAgeTier(int age) {
    if (age >= 3 && age <= 10) return 'kid';
    if (age >= 11 && age <= 15) return 'teenPlus';
    if (age >= 16) return 'adultPlus';
    // Default to kid for ages < 3
    return 'kid';
  }

  /// Get tier configuration
  Map<String, dynamic> _getTierConfig(String tier) {
    final tiers = _allowlists['tiers'] as Map<String, dynamic>;
    return tiers[tier] as Map<String, dynamic>;
  }

  /// Build normalized options map with allowlist enforcement and probabilities
  ///
  /// This is the core randomization logic:
  /// 1. Determine age tier
  /// 2. Load tier's allowlists and probabilities
  /// 3. Randomly select from allowed variants
  /// 4. Apply probability gates (e.g., 20% chance of glasses)
  /// 5. Apply user overrides if provided AND allowed in tier
  Map<String, String> _buildNormalizedOptions({
    required int age,
    required String seed,
    Map<String, String>? userOverrides,
  }) {
    final tier = _getAgeTier(age);
    final tierConfig = _getTierConfig(tier);

    final allowedOptions = tierConfig['options'] as Map<String, dynamic>;
    final probabilities = tierConfig['probabilities'] as Map<String, dynamic>;

    final normalized = <String, String>{};

    // Process each category in allowlists
    for (final category in allowedOptions.keys) {
      final allowedVariants = (allowedOptions[category] as List).cast<String>();

      if (allowedVariants.isEmpty) continue;

      // Check if user override exists and is allowed
      if (userOverrides != null && userOverrides.containsKey(category)) {
        final override = userOverrides[category]!;
        if (allowedVariants.contains(override)) {
          normalized[category] = override;
          continue;
        }
      }

      // Apply probability gate
      final probability = (probabilities[category] as num?)?.toDouble() ?? 1.0;

      if (probability <= 0.0) {
        // Never include this category (probability = 0)
        continue;
      }

      if (probability < 1.0) {
        // Roll the dice
        if (_random.nextDouble() > probability) {
          continue; // Skip this category
        }
      }

      // Select random variant from allowed list
      final selectedVariant =
          allowedVariants[_random.nextInt(allowedVariants.length)];
      normalized[category] = selectedVariant;
    }

    return normalized;
  }

  /// Build DiceBear URL with comma-separated arrays
  ///
  /// CRITICAL: DiceBear expects arrays as: key=v1,v2,v3 (NOT key[]=v1&key[]=v2)
  String _buildDiceBearUrl({
    required String seed,
    required Map<String, String> options,
  }) {
    final params = <String, String>{
      'seed': seed,
      ...options,
    };

    // Build query string with proper encoding
    final queryParts = params.entries.map((e) {
      final key = Uri.encodeQueryComponent(e.key);
      final value = Uri.encodeQueryComponent(e.value);
      return '$key=$value';
    });

    final queryString = queryParts.join('&');
    return '$_baseUrl/$_apiVersion/$_style/svg?$queryString';
  }

  /// Compute cache key from normalized options
  ///
  /// Format: sha256(style|seed|options_json|schemaVersion)
  String _computeCacheKey({
    required String seed,
    required Map<String, String> options,
  }) {
    // Sort options by key for consistent hashing
    final sortedOptions = Map.fromEntries(
      options.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    final optionsJson = json.encode(sortedOptions);
    final cacheInput = '$_style|$seed|$optionsJson|$_schemaVersion';

    return sha256.convert(utf8.encode(cacheInput)).toString();
  }

  /// Fetch SVG from cache or network
  ///
  /// Flow:
  /// 1. Check Isar cache
  /// 2. If hit and valid, return cached SVG
  /// 3. If miss or invalid, fetch from network
  /// 4. Save to cache on success
  /// 5. If network fails, return stale cache if available
  Future<String?> fetchAvatarSvg({
    required int age,
    required String seed,
    Map<String, String>? userOverrides,
  }) async {
    _checkInitialized();

    // Build normalized options
    final options = _buildNormalizedOptions(
      age: age,
      seed: seed,
      userOverrides: userOverrides,
    );

    // Compute cache key
    final cacheKey = _computeCacheKey(seed: seed, options: options);

    // Try cache first
    final cached = await _getCachedAvatar(cacheKey);
    if (cached != null) {
      // Validate cache
      if (cached.hasValidSchema(_schemaVersion) &&
          !cached.isStale(maxAgeDays: _cacheMaxAgeDays)) {
        // Cache hit - update access time and return
        await _updateCacheAccessTime(cached);
        return cached.svgString;
      }
    }

    // Cache miss or invalid - fetch from network
    try {
      final url = _buildDiceBearUrl(seed: seed, options: options);
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final svgString = response.body;

        // Validate SVG
        if (!svgString.trim().startsWith('<svg')) {
          throw FormatException('Response is not valid SVG');
        }

        // Save to cache
        await _saveToCacheAsync(
          cacheKey: cacheKey,
          svgString: svgString,
          seed: seed,
          options: options,
          age: age,
        );

        return svgString;
      } else {
        throw HttpException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      // Network error - try to return stale cache as fallback
      if (cached != null) {
        print('AvatarService: Network error, using stale cache: $e');
        return cached.svgString;
      }

      print('AvatarService: Failed to fetch avatar: $e');
      return null;
    }
  }

  /// Get cached avatar by key
  Future<AvatarCacheEntry?> _getCachedAvatar(String cacheKey) async {
    if (!_cachingAvailable) return null; // No caching on web
    // TODO: Re-enable when Isar web support is fixed
    // return await isar.avatarCacheEntrys
    //     .where()
    //     .cacheKeyEqualTo(cacheKey)
    //     .findFirst();
    return null;
  }

  /// Update cache access time
  Future<void> _updateCacheAccessTime(AvatarCacheEntry entry) async {
    if (!_cachingAvailable) return; // No caching on web
    // TODO: Re-enable when Isar web support is fixed
    // await isar.writeTxn(() async {
    //   entry.markAccessed();
    //   await isar.avatarCacheEntrys.put(entry);
    // });
  }

  /// Save avatar to cache
  Future<void> _saveToCacheAsync({
    required String cacheKey,
    required String svgString,
    required String seed,
    required Map<String, String> options,
    required int age,
  }) async {
    if (!_cachingAvailable) return; // No caching on web

    final tier = _getAgeTier(age);

    // Sort options for consistent JSON
    final sortedOptions = Map.fromEntries(
      options.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    final entry = AvatarCacheEntry.create(
      cacheKey: cacheKey,
      svgString: svgString,
      schemaVersion: _schemaVersion,
      style: _style,
      seed: seed,
      optionsJson: json.encode(sortedOptions),
      ageTier: tier,
      characterAge: age,
    );

    // TODO: Re-enable when Isar web support is fixed
    // await isar.writeTxn(() async {
    //   await isar.avatarCacheEntrys.put(entry);
    // });
  }

  /// Clear all cached avatars
  Future<int> clearCache() async {
    if (!_cachingAvailable) return 0; // No caching on web
    // TODO: Re-enable when Isar web support is fixed
    // return await isar.writeTxn(() async {
    //   final count = await isar.avatarCacheEntrys.count();
    //   await isar.avatarCacheEntrys.clear();
    //   return count;
    // });
    return 0;
  }

  /// Clear stale cache entries
  Future<int> clearStaleCache() async {
    if (!_cachingAvailable) return 0; // No caching on web
    // TODO: Re-enable when Isar web support is fixed
    // final staleEntries = await isar.avatarCacheEntrys
    //     .filter()
    //     .createdAtLessThan(
    //       DateTime.now().subtract(Duration(days: _cacheMaxAgeDays)),
    //     )
    //     .findAll();

    // if (staleEntries.isEmpty) return 0;

    // return await isar.writeTxn(() async {
    //   final ids = staleEntries.map((e) => e.id).toList();
    //   return await isar.avatarCacheEntrys.deleteAll(ids);
    // });
    return 0;
  }

  /// Clear cache entries with old schema version
  Future<int> clearInvalidSchemaCache() async {
    if (!_cachingAvailable) return 0; // No caching on web
    // TODO: Re-enable when Isar web support is fixed
    // final invalidEntries = await isar.avatarCacheEntrys
    //     .filter()
    //     .not()
    //     .schemaVersionEqualTo(_schemaVersion)
    //     .findAll();

    // if (invalidEntries.isEmpty) return 0;

    // return await isar.writeTxn(() async {
    //   final ids = invalidEntries.map((e) => e.id).toList();
    //   return await isar.avatarCacheEntrys.deleteAll(ids);
    // });
    return 0;
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    if (!_cachingAvailable) {
      return {
        'total': 0,
        'validSchema': 0,
        'stale': 0,
        'fresh': 0,
        'schemaVersion': _schemaVersion,
      };
    }

    // TODO: Re-enable when Isar web support is fixed
    // final total = await isar.avatarCacheEntrys.count();
    // final validSchema = await isar.avatarCacheEntrys
    //     .filter()
    //     .schemaVersionEqualTo(_schemaVersion)
    //     .count();

    // final stale = await isar.avatarCacheEntrys
    //     .filter()
    //     .createdAtLessThan(
    //       DateTime.now().subtract(Duration(days: _cacheMaxAgeDays)),
    //     )
    //     .count();

    final total = 0;
    final validSchema = 0;
    final stale = 0;

    return {
      'total': total,
      'validSchema': validSchema,
      'stale': stale,
      'fresh': total - stale,
      'schemaVersion': _schemaVersion,
    };
  }

  /// Generate random seed for new avatar
  String generateRandomSeed() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        _random.nextInt(999999).toString();
  }

  /// Static method to generate avatar URL for a character
  /// This is a simplified version that doesn't use caching
  static String generateAvatarUrl({
    required String characterId,
    String? hairColor,
    String? eyeColor,
    String? outfit,
  }) {
    // Use character ID as seed for consistency
    final seed = characterId;

    // Build basic options map
    final options = <String, String>{};
    if (hairColor != null) options['hairColor'] = hairColor;
    if (eyeColor != null) options['eyes'] = eyeColor;
    // outfit is not currently used in the allowlists

    // Build query string
    final params = <String, String>{'seed': seed, ...options};
    final queryParts = params.entries.map((e) {
      final key = Uri.encodeQueryComponent(e.key);
      final value = Uri.encodeQueryComponent(e.value);
      return '$key=$value';
    });
    final queryString = queryParts.join('&');

    // Use a default DiceBear URL since we don't have access to config here
    // This should be updated to use the actual service URL when available
    return 'https://api.dicebear.com/9.x/adventurer/svg?$queryString';
  }

  /// Static method to build avatar widget for a character
  /// This is a simplified version that doesn't use caching
  static Widget buildAvatarWidget({
    required String characterId,
    String? hairColor,
    String? eyeColor,
    String? outfit,
    double size = 100,
  }) {
    final url = generateAvatarUrl(
      characterId: characterId,
      hairColor: hairColor,
      eyeColor: eyeColor,
      outfit: outfit,
    );

    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.network(
        url,
        placeholderBuilder: (context) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person,
            size: size * 0.6,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

/// HTTP exception for avatar fetching
class HttpException implements Exception {
  final String message;
  HttpException(this.message);

  @override
  String toString() => 'HttpException: $message';
}
