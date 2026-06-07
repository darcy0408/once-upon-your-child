#!/usr/bin/env python3
"""
MT-213 COPPA verifiable-consent round-trip smoke test.

Exercises the under-13 parental email-verification round trip end-to-end
against a live backend, using a fresh free-tier anonymous account:

  (1) POST /api/user/<id>/consent/request-verification  (child_age=10)
        - 200 {"success": true}  -> email queued (Resend configured). GOOD.
        - 503 EMAIL_SERVICE_UNAVAILABLE -> RESEND_API_KEY is NOT set on the
          backend. This is the #1 thing to catch before launch: the code is
          correct but production would block ALL under-13 onboarding.
  (2) POST /api/user/<id>/consent/verify with a deliberately WRONG code
        - expect {"verified": false} (non-distinguishing 400). Confirms the
          gate actually checks the code.
  (3) POST /api/user/<id>/consent/verify with the REAL code you paste from
      the email -> expect {"verified": true}. Confirms the happy path.

This test inherently needs a human: it sends a real email and you paste the
code back in. Run it from a LOCAL shell (scheduled-routine sandboxes are
firewalled off *.railway.app). No git side effects, no deploys.

Usage:
    python coppa_consent_smoke.py you@example.com
    python coppa_consent_smoke.py you@example.com --base http://localhost:5000

Requires: requests  (pip install requests)
"""

import argparse
import sys

import requests

DEFAULT_BASE = "https://story-weaver-app-production.up.railway.app"
CHILD_AGE = 10  # any value < 13 routes through the verifiable round trip
WRONG_CODE = "000000"  # ~1-in-a-million chance of matching the real code
TIMEOUT = 30

PASS, FAIL, BLOCKED = "PASS", "FAIL", "BLOCKED"
results = []  # (label, status, detail)


def record(label, status, detail):
    results.append((label, status, detail))
    print(f"  [{status}] {label}: {detail}")


def excerpt(text, n=300):
    text = (text or "").replace("\n", " ")
    return text if len(text) <= n else text[:n] + " ...(truncated)"


def auth(token):
    return {"Authorization": f"Bearer {token}"}


def new_anon_account(base):
    """Create a fresh free-tier anonymous account; return (token, user_id)."""
    r = requests.post(f"{base}/auth/anonymous", json={}, timeout=TIMEOUT)
    r.raise_for_status()
    data = r.json()
    return data["token"], data["user_id"]


def request_verification(base, token, user_id, parent_email):
    return requests.post(
        f"{base}/api/user/{user_id}/consent/request-verification",
        headers=auth(token),
        json={
            "child_age": CHILD_AGE,
            "parent_email": parent_email,
            "allow_photo_avatar": False,
        },
        timeout=TIMEOUT,
    )


def verify(base, token, user_id, code):
    return requests.post(
        f"{base}/api/user/{user_id}/consent/verify",
        headers=auth(token),
        json={"code": code},
        timeout=TIMEOUT,
    )


def main():
    parser = argparse.ArgumentParser(
        description="MT-213 COPPA consent round-trip smoke test"
    )
    parser.add_argument("parent_email", help="real inbox you can read the code from")
    parser.add_argument(
        "--base",
        default=DEFAULT_BASE,
        help=f"backend base URL (default: {DEFAULT_BASE})",
    )
    parser.add_argument(
        "--skip-verify",
        action="store_true",
        help="only test request-verification (the RESEND config check); do not wait for a code",
    )
    args = parser.parse_args()

    print("=" * 72)
    print("MT-213 COPPA verifiable-consent round-trip smoke test")
    print(f"Target: {args.base}")
    print(f"Parent email: {args.parent_email}")
    print("=" * 72)

    # ---- fresh account ----
    try:
        token, user_id = new_anon_account(args.base)
    except requests.RequestException as e:
        print(f"FATAL: could not create anonymous account: {e}")
        sys.exit(2)
    print(f"Anonymous user_id: {user_id}\n")

    # ---- (1) request verification ----
    print("(1) POST /consent/request-verification (child_age=10)")
    try:
        r = request_verification(args.base, token, user_id, args.parent_email)
    except requests.RequestException as e:
        record("request-verification", FAIL, f"request error: {e}")
        summarize_and_exit()
        return

    if r.status_code == 503:
        code = ""
        try:
            code = (r.json() or {}).get("code", "")
        except ValueError:
            pass
        if code == "EMAIL_SERVICE_UNAVAILABLE":
            detail = (
                "HTTP 503 EMAIL_SERVICE_UNAVAILABLE -> RESEND_API_KEY is NOT set on "
                f"the backend. Set it in Railway before launch: {excerpt(r.text)}"
            )
        elif code == "EMAIL_SEND_FAILED":
            detail = (
                "HTTP 503 EMAIL_SEND_FAILED -> RESEND_API_KEY IS set, but Resend "
                "rejected the send. Most likely the sending domain is not verified "
                "(verify a domain at resend.com/domains and set CONSENT_EMAIL_FROM to "
                "an address on it), or you're in Resend test mode (can only send to "
                f"the account owner's email). Check the backend logs for the exact reason: {excerpt(r.text)}"
            )
        else:
            detail = f"HTTP 503 (unknown code): {excerpt(r.text)}"
        record("request-verification", FAIL, detail)
        summarize_and_exit()
        return
    if r.status_code != 200:
        record(
            "request-verification",
            FAIL,
            f"unexpected HTTP {r.status_code}: {excerpt(r.text)}",
        )
        summarize_and_exit()
        return
    record("request-verification", PASS, f"HTTP 200 -> email queued: {excerpt(r.text)}")

    if args.skip_verify:
        print("\n--skip-verify set: stopping after the config check.")
        summarize_and_exit()
        return

    print(
        "\n  >>> Check the inbox for "
        f"{args.parent_email} — the verification email should arrive in seconds."
    )

    # ---- (2) wrong code is rejected ----
    print("\n(2) POST /consent/verify with a WRONG code (expect verified:false)")
    try:
        r = verify(args.base, token, user_id, WRONG_CODE)
        verified = (
            bool(r.json().get("verified"))
            if r.headers.get("content-type", "").startswith("application/json")
            else None
        )
    except requests.RequestException as e:
        record("wrong-code-rejected", FAIL, f"request error: {e}")
    except ValueError:
        record(
            "wrong-code-rejected",
            FAIL,
            f"non-JSON response HTTP {r.status_code}: {excerpt(r.text)}",
        )
    else:
        if verified is False:
            record(
                "wrong-code-rejected",
                PASS,
                f"HTTP {r.status_code}, verified=false: {excerpt(r.text)}",
            )
        else:
            record(
                "wrong-code-rejected",
                FAIL,
                f"expected verified=false, got HTTP {r.status_code}: {excerpt(r.text)}",
            )

    # ---- (3) real code grants access ----
    print("\n(3) POST /consent/verify with the REAL code from the email")
    try:
        code = input("  Enter the code from your email (or blank to skip): ").strip()
    except EOFError:
        code = ""
    if not code:
        record(
            "real-code-accepted", BLOCKED, "no code entered — happy path not verified"
        )
        summarize_and_exit()
        return
    try:
        r = verify(args.base, token, user_id, code)
        verified = bool(r.json().get("verified"))
    except requests.RequestException as e:
        record("real-code-accepted", FAIL, f"request error: {e}")
    except ValueError:
        record(
            "real-code-accepted",
            FAIL,
            f"non-JSON response HTTP {r.status_code}: {excerpt(r.text)}",
        )
    else:
        if verified:
            record(
                "real-code-accepted",
                PASS,
                f"HTTP {r.status_code}, verified=true: {excerpt(r.text)}",
            )
        else:
            record(
                "real-code-accepted",
                FAIL,
                f"expected verified=true, got HTTP {r.status_code}: {excerpt(r.text)} "
                "(typo? expired? attempt cap hit by step 2?)",
            )

    summarize_and_exit()


def summarize_and_exit():
    print("\n" + "=" * 72)
    print("MT-213 ROUND-TRIP MATRIX")
    print("=" * 72)
    if results:
        width = max(len(label) for label, _, _ in results)
        for label, status, _ in results:
            print(f"  {label.ljust(width)}  {status}")
    print("=" * 72)
    n_fail = sum(1 for _, s, _ in results if s == FAIL)
    n_blocked = sum(1 for _, s, _ in results if s == BLOCKED)
    if n_fail:
        print(f"RESULT: {n_fail} FAIL, {n_blocked} BLOCKED — investigate.")
        sys.exit(1)
    if n_blocked:
        print(
            f"RESULT: runnable checks PASS, {n_blocked} BLOCKED (finish the email step to fully close MT-213)."
        )
        sys.exit(0)
    print("RESULT: all checks PASS — MT-213 round trip verified end-to-end.")
    sys.exit(0)


if __name__ == "__main__":
    main()
