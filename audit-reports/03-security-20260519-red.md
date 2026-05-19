# 03 Security Audit — Red Hat (Intuitive Risk Signals)

Gut reactions recorded before evidence-gathering. Not findings — signals that
steered the Black Hat pass.

- The two prior remediation batches landed cleanly and the verified-fixed list
  is genuinely fixed. The instinct here is the opposite of the usual one: this
  codebase has had real security attention. The risk is now in the *seams* —
  the things the prior audit's work-package boundaries didn't cover.

- `get_user_identifier` falling back to a client-supplied `X-User-ID` header
  for the rate-limit key produced the strongest unease. A rate limiter whose
  bucket key the attacker controls is not a rate limiter. It feels like a
  legacy convenience that was never revisited after auth got real.

- The `security/` directory — 1,700+ lines of "AI threat detector", "GDPR
  compliance", "IAM", "data protection" — and nothing imports it. Dead security
  code is worse than no security code: it reads like a control exists when it
  does not, and a future reviewer (or an auditor, or a regulator) may believe
  it is wired in.

- BYOK Gemini keys encrypted with AES-256-**CBC**. CBC with no MAC is a 2010-era
  choice. The data is low-value-ish (a user's own API key) but unauthenticated
  encryption is a smell that invites padding-oracle thinking — and the decrypt
  path does surface "Decryption failed" detail.

- The avatar generate rate limit lives in a plain in-process dict on
  `current_app`. Two gunicorn workers means the real limit is 2x the intended
  one, and the dict never evicts old hour-buckets — a slow leak. It feels like
  it was written for `--workers 1` and never reconciled with the `--workers 2`
  the Dockerfile now ships.

- `/usage/summary`, `/usage/daily`, `/usage/mock-mode` still return raw
  `str(e)` in the response body. The prior audit's L-7 was supposed to have
  swept these. It feels like the L-7 fix walked `api_key_routes.py` and stopped.

- IAP server-to-server notification endpoints are unauthenticated and ACK 200.
  They are stubs today, so harmless — but the instinct is that a stub that
  returns 200 to the world is the kind of thing that quietly becomes load-
  bearing without the signature verification ever being added.

- Pleasant surprise: the webhook idempotency + ordering-cursor design, the
  fail-closed price-ID tier resolution, and the IAP fail-closed default are
  better than most production payment code. The instinct says: trust the
  payment layer, look harder everywhere else.
