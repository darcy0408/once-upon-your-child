/// Digital-consent age by country (GDPR Art. 8).
///
/// GDPR Art. 8 sets the age at which a minor can consent to information-society
/// services to 16, but lets each member state lower it to no younger than 13.
/// Member states chose different ages (13–16), so the age at which a parent's
/// verifiable consent is *required* is jurisdiction-dependent in the EEA.
///
/// Outside the EEA we use 13 — the COPPA floor (US) and a sensible global
/// default. Inside the EEA we use **16**, the GDPR Art. 8 baseline.
///
/// We deliberately apply the GDPR ceiling (16) uniformly across the EEA rather
/// than each member state's individual derogation (states may lower it to as
/// young as 13). Reasons: 16 is always lawful everywhere in the EEA, so a
/// uniform 16 cannot under-protect; the only cost is occasionally asking for
/// parental consent where a state allowed a younger age (mild UX friction, not
/// a violation); and it removes a per-country legal-data table that would
/// otherwise need ongoing verification against 30 states' implementing laws.
/// If EEA usage ever grows enough that the teen-consent friction matters, the
/// per-state ages can be reintroduced as a lookup here — a data change, not a
/// structural one.
///
/// The country comes from Cloudflare's `CF-IPCountry` request header, read by
/// the backend and surfaced to the client (the Flutter web client cannot read
/// request headers itself). See [consentAgeForCountry].
library;

/// COPPA / global default — the age an unknown or non-EEA country resolves to.
const int kDefaultConsentAge = 13;

/// GDPR Art. 8 baseline — applied uniformly across the EEA.
const int kGdprBaselineConsentAge = 16;

/// EEA member states (EU-27 + Iceland, Liechtenstein, Norway), ISO 3166-1
/// alpha-2, upper-case. Membership decides whether the EEA baseline (16) or the
/// global default (13) applies.
const Set<String> _eeaCountries = {
  'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR',
  'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK',
  'SI', 'ES', 'SE', 'IS', 'LI', 'NO',
};

/// The digital-consent age for [countryCode] (an ISO 3166-1 alpha-2 code,
/// case-insensitive; typically the `CF-IPCountry` value).
///
/// - EEA → [kGdprBaselineConsentAge] (16).
/// - Unknown / null / non-EEA → [kDefaultConsentAge] (13, the COPPA floor).
///
/// A user whose declared age is BELOW the returned value must complete the
/// verifiable parental-consent round trip; at or above it they may self-attest
/// (subject to the separate COPPA under-13 rule, which still applies in the US).
int consentAgeForCountry(String? countryCode) {
  final cc = countryCode?.trim().toUpperCase();
  if (cc == null || cc.isEmpty || !_eeaCountries.contains(cc)) {
    return kDefaultConsentAge;
  }
  return kGdprBaselineConsentAge;
}
