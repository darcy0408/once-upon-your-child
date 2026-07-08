import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/services/feelings_ambient_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FeelingsAmbientService', () {
    test('getRecentFeeling returns null when journal is empty', () async {
      final feeling = await FeelingsAmbientService.getRecentFeeling();
      expect(feeling, isNull);
    });

    test('getRecentFeeling returns feeling when journal has recent entry', () async {
      final prefs = await SharedPreferences.getInstance();
      final entry = {
        'coreName': 'Happy',
        'coreEmoji': '😊',
        'secondaryName': 'Playful',
        'tertiaryName': 'Silly',
        'intensity': 4,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setStringList('feelings_journal', [jsonEncode(entry)]);

      final feeling = await FeelingsAmbientService.getRecentFeeling();
      expect(feeling, isNotNull);
      expect(feeling!.selectedFeeling.core, 'Happy');
      expect(feeling.selectedFeeling.secondary, 'Playful');
      expect(feeling.selectedFeeling.tertiary, 'Silly');
      expect(feeling.intensity, 4);
    });

    test('getRecentFeeling returns null when journal entry is older than 24 hours', () async {
      final prefs = await SharedPreferences.getInstance();
      final oldTimestamp = DateTime.now().subtract(const Duration(hours: 25));
      final entry = {
        'coreName': 'Happy',
        'coreEmoji': '😊',
        'timestamp': oldTimestamp.toIso8601String(),
      };
      await prefs.setStringList('feelings_journal', [jsonEncode(entry)]);

      final feeling = await FeelingsAmbientService.getRecentFeeling();
      expect(feeling, isNull);
    });

    test('getRecentFeeling returns the most recent entry', () async {
      final prefs = await SharedPreferences.getInstance();
      final oldEntry = {
        'coreName': 'Sad',
        'coreEmoji': '😢',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      };
      final newEntry = {
        'coreName': 'Happy',
        'coreEmoji': '😊',
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setStringList('feelings_journal', [jsonEncode(oldEntry), jsonEncode(newEntry)]);

      final feeling = await FeelingsAmbientService.getRecentFeeling();
      expect(feeling!.selectedFeeling.core, 'Happy');
    });
  group('Error handling', () {
    test('getRecentFeeling is resilient to malformed JSON', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('feelings_journal', ['not json']);

      final feeling = await FeelingsAmbientService.getRecentFeeling();
      expect(feeling, isNull);
    });
  });
  });
}
