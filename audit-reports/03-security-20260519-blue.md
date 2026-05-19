# 03 Security Audit — Blue Hat (Synthesis & Remediation Backlog)

Synthesis of all hats into a prioritized, sequenced remediation backlog.

## Cross-hat synthesis

The White Hat inventory and the Black Hat regression check together establish
the headline: the two prior remediation batches (2026-05-16/17) did land. 20
of 21 spot-checked prior findings are confirmed fixed in current source; the
Yellow Hat documents a payment layer and an auth layer that are genuinely
above baseline. This audit therefore found NO new Critical and only ONE new
High.

The Red Hat correctly predicted where the residual risk sits: not in the
remediated work packages but in their *seams* — a rate-limiter key function
(S-01) that the WP boundaries never touched, a dead `security/` tree (S-02)
that no WP owned, an `/usage/*` handler trio (S-04) that the L-7 sweep walked
past, and an avatar rate-limit dict (S-05) written for a single worker before
the Dockerfile moved to two.

One genuine regression: prior L-7 (raw `str(e)` in 500 responses) was closed
in `api_key_routes.py` but missed in `utility_routes.py` — re-filed as S-04.

## Conflict resolution between hats

- Yellow Hat praises the Redis-backed flask-limiter; Black Hat S-01 says rate
  limiting is bypassable. No contradiction: the limiter *storage* is sound;
  the limiter *key* is spoofable. The fix is to the key function, not the
  limiter — Yellow's assessment of the storage layer stands.
- Yellow Hat praises encryption-at-rest for BYOK keys; Black Hat S-03 flags
  the CBC mode. Resolution: encryption-at-rest is correctly present and the
  key is not hardcoded (Yellow stands); the *mode* should be upgraded to
  authenticated encryption (S-03). Both are true.

## Severity tally (new findings, this audit)

| Severity | Count | IDs |
|---|---|---|
| Critical | 0 | — |
| High | 1 | S-01 |
| Medium | 5 | S-02, S-03, S-04, S-05, S-06 |
| Low / Informational | 7 | S-07, S-08, S-09, S-10, S-11, S-12, S-13 |

Prior-audit findings: 20/21 spot-checked confirmed still fixed; 1 partial
regression (L-7 -> re-filed as S-04). H-8 verified-consent is code-complete
but flag-gated OFF — a launch decision, not a defect.

## Prioritized remediation backlog

Sequenced so independent fixes can run in parallel. P0 = ship before launch.
P1 = next engineering cycle. P2 = follow-up / hardening.

| Seq | ID | Title | Sev | Effort | Needs decision | Depends on |
|---|---|---|---|---|---|---|
| P0-1 | S-01 | Rate-limit key must not trust `X-User-ID` | High | S | No | — |
| P0-2 | S-04 | Remove `str(e)` from `/usage/*` responses | Med | S | No | — |
| P0-3 | S-02 | Delete / archive dead `security/` tree | Med | S | No | — |
| P1-1 | S-03 | BYOK keys -> authenticated encryption (AESGCM) | Med | M | No | migration |
| P1-2 | S-05 | Avatar rate limit -> Redis-backed, evicting | Med | M | No | — |
| P1-3 | S-06 | IAP S2S signature verification before phase 2 | Med | M | No | STORE-1 ph2 |
| P1-4 | S-07 | Set JWT TTLs on config class, not `setdefault` | Low | S | No | — |
| P2-1 | S-08 | Tighten nginx CSP `connect-src` to concrete domain | Low | S | No | stable URL |
| P2-2 | S-09 | `is_production()` guard on `/debug-*` endpoints | Low | S | No | — |
| P2-3 | S-11 | Per-account failed-login backoff (defense in depth) | Low | S | No | S-01 |
| P2-4 | S-13 | Observability counter on `optional_auth` reject | Info | S | No | — |
| — | S-10, S-12 | Informational — no action required now | Info | — | — | — |

Launch gate (not a code fix, tracked separately):
- H-8 — set `COPPA_REQUIRE_VERIFIED_CONSENT=true` before public launch once
  the Resend email round-trip is operational. Product/legal decision.

## Dependency map

- S-11 depends on S-01 (the per-account backoff is the second layer behind the
  fixed rate limiter).
- S-03 needs a one-time migration to re-wrap existing CBC blobs as AESGCM.
- S-06 is gated by the STORE-1 phase-2 schedule but the verification function
  should be written now (Green Hat #5) so phase 2 cannot regress it.
- S-08 is gated on the Railway backend domain being stabilized.
- All other items are independent and parallelizable.

## Sequencing rationale

1. S-01 first — it is the only High and it nullifies brute-force / DoS rate
   limiting app-wide. Small effort, large blast radius. Pure code fix.
2. S-04 and S-02 alongside it — both Small, both pure deletions/replacements,
   zero behavioural risk, and they close an info-leak and a governance gap.
3. S-03 / S-05 / S-06 in the next cycle — each is Medium effort and benefits
   from a migration or a Redis touch; not launch-blocking but should not slip.
4. The Low/Informational tail is opportunistic hardening.

## Coverage statement

Every repo directory in the White Hat inventory appears in at least one hat or
is explicitly excluded with rationale (build artifacts, screenshots, legacy
subtrees, tooling). Content-moderation surfaces are deliberately delegated to
`02-content-safety-20260519.md` and not duplicated. No CSAM-adjacent, grooming,
or minor-manipulation vector was found in the security surfaces audited here.
Live exploitation was not performed — this is a static review; exploit paths
are described conceptually only, per the audit safety protocol.
