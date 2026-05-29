# PERF-07 Finding: WebP Conversion Already Complete

Date: 2026-05-27
Status: Closed (stale audit finding)

## What I found

The performance audit (2026-05-22) flagged PERF-07 as "Convert bundled PNG
assets to WebP — High severity, ~73MB bundled assets need conversion." That
finding is **stale**. The conversion was already executed in a prior session.

### Evidence

Asset format inventory across the 11 directories targeted by
`scripts/convert_assets_to_webp.ps1`:

| Directory | PNGs remaining | WebPs |
|-----------|---------------|------|
| `assets/images/archetypes` | 0 | 52 |
| `assets/images/companions` | 0 | 15 |
| `assets/images/feelings` | 0 | 149 |
| `assets/images/scenes` | 0 | 4 |
| `assets/images/scenarios` | 0 | 23 |
| `assets/images/orbs` | 0 | 18 |
| `assets/images/backgrounds` | 0 | 0 (empty dir) |
| `assets/images/themes` | 0 | 6 |
| `assets/images/ui` | 0 | 124 |
| `assets/feelings_faces` | 0 | 157 |
| `assets/mood_lanterns` | 0 | 8 |
| **Total** | **0** | **556** |

The 358 MB `assets/.png-backup/` directory is the historical safety net the
conversion script writes — every original PNG is preserved there for rollback.

## Implication for the audit's bundle-size numbers

The audit reported:
- AAB: 114 MiB
- Bundled assets: ~73 MiB

These figures are the **post-WebP** state. The "convert PNGs to WebP" lever has
already been pulled; the AAB is what's left after that win was realized.

## Where the remaining bundle-size opportunity is

WebP is exhausted as a fix. To push the AAB below 50 MiB, the remaining
levers are:

1. **Trim asset count.** 556 illustrations is a lot. Audit the registered
   asset list in `pubspec.yaml:121-180` for unused age-band variants,
   archetypes, or themes that aren't reachable from current code.
2. **Resolution reduction.** Many bundled illustrations may still be at a
   higher resolution than any device displays them. A pass at re-encoding
   to display-max (e.g., 1024px longest edge) on top of WebP could save
   another 20-30%.
3. **Split APKs per ABI** (`flutter build apk --split-per-abi`). The AAB
   already does this transparently for Play Store; a sideloaded APK would
   benefit from explicit splits.
4. **Off-bundle delivery** for low-frequency assets (e.g., advanced
   archetype variants). Load on demand instead of shipping with the app.
5. **Audio reduction.** `assets/sounds` is 6 MB of MP3; check encoding
   bitrate and length.

None of these is small work. PERF-07 as originally scoped is closed; if
the user wants to pursue further bundle reductions, it should be a new
finding with its own scope.
