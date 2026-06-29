/// Privacy-by-default policy layer (CAADCA — Cal. Civ. Code §1798.99.28 et seq.).
///
/// California's Age-Appropriate Design Code treats anyone **under 18** as a
/// child and requires privacy-protective settings to be ON *by default* for
/// them. That is a broader cutoff than COPPA's under-13 verifiable-consent
/// gate, and it is a *design-default* obligation, NOT a consent gate.
///
/// This class is the single source of truth for "should the high-privacy
/// default apply to this age?" so the rule lives in one place instead of being
/// re-derived as scattered `age >= 13` / `age < 18` checks.
///
/// Layering (do not conflate the two):
///  - **COPPA, under 13** → verifiable parental consent before any collection.
///    Enforced by [ParentalConsentService] / [PrivacyService.applyConsentDecision].
///  - **CAADCA, under 18** → protective *defaults* unless explicitly enabled.
///    Enforced here (analytics). The photo-to-avatar path is already
///    default-off + explicit-parent-opt-in for every age in
///    [ParentalConsentService], so it needs no separate predicate here.
///
/// Keeping analytics off for the whole under-18 range also closes the CCPA/CPRA
/// concern that an analytics SDK passing identifiers could count as "sharing" a
/// minor's personal information for cross-context behavioral advertising.
class PrivacyDefaults {
  PrivacyDefaults._();

  /// Age at/above which a user is treated as an adult for default-privacy
  /// purposes. CAADCA's definition of "child" is everyone below this.
  static const int adultAge = 18;

  /// True when high-privacy defaults must apply (CAADCA: under 18, or unknown).
  /// Unknown age is treated as a minor — the most protective assumption.
  static bool strictByAge(int? age) => age == null || age < adultAge;

  /// Whether analytics collection may be enabled *by default* for this age.
  /// False for all minors (under 18); they require an explicit opt-in action.
  static bool analyticsAllowedByDefault(int? age) => !strictByAge(age);
}
