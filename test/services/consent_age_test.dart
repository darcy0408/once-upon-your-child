import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/services/consent_age.dart';

void main() {
  group('consentAgeForCountry', () {
    test('unknown / null / empty resolves to the COPPA floor (13)', () {
      expect(consentAgeForCountry(null), kDefaultConsentAge);
      expect(consentAgeForCountry(''), kDefaultConsentAge);
      expect(consentAgeForCountry('   '), kDefaultConsentAge);
    });

    test('non-EEA countries resolve to the global default (13)', () {
      expect(consentAgeForCountry('US'), 13);
      expect(consentAgeForCountry('CA'), 13);
      expect(consentAgeForCountry('JP'), 13);
      expect(consentAgeForCountry('ZZ'), 13); // not a real country
    });

    test('all EEA states resolve to the GDPR baseline (16)', () {
      for (final cc in ['DE', 'FR', 'ES', 'PL', 'NL', 'IE', 'SK', 'NO', 'IS']) {
        expect(consentAgeForCountry(cc), 16, reason: '$cc should be 16');
      }
    });

    test('is case- and whitespace-insensitive', () {
      expect(consentAgeForCountry('de'), 16);
      expect(consentAgeForCountry(' fr '), 16);
      expect(consentAgeForCountry('Us'), 13);
    });

    test('never returns a value outside the legal 13–16 band', () {
      for (final cc in [
        'US', 'DE', 'FR', 'ES', 'PL', 'AT', 'CZ', 'NO', 'IS', 'LI', null, 'ZZ',
      ]) {
        final age = consentAgeForCountry(cc);
        expect(age, greaterThanOrEqualTo(13));
        expect(age, lessThanOrEqualTo(16));
      }
    });
  });
}
