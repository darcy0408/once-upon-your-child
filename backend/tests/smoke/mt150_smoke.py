#!/usr/bin/env python3
"""
MT-150 production verification smoke test for Story Weaver
("M-8 monetization re-scope").

Verifies, against the live Railway production backend, using a fresh
free-tier anonymous account:

  (a) POST /generate-interactive-story is NOT premium-gated and accepts
      story `companions` in the payload. Known broken by MT-154
      (psycopg2 StringDataRightTruncation on story_segment.image_url).
      PASS  = request not 403-gated AND (200 OR the exact MT-154 500).
      FAIL  = 403 (gated) or a 500 that is NOT the truncation bug.

  (b) POST /avatar/generate-pet-avatar and POST /generate-coloring-pages
      still return 403 upgrade_required for a free-tier account.

  (c) one-free-avatar gate on POST /avatar/generate-custom-avatar:
      first successful generation increments user.custom_avatars_generated,
      a second attempt returns 403 with an "upgrade" payload.
      MT-155 (custom-avatar generation timeout -> 504) may intermittently
      surface here; a 504/timeout/connection-reset on the FIRST attempt is
      reported as BLOCKED, not FAIL, of the gate itself.

  (d) user.custom_avatars_generated column exists -- an authenticated
      endpoint that reads the user record returns 200, not a 500
      UndefinedColumn. Checked via /users/<id>/feature-unlocks.

Re-runnable: safe to run again after MT-154 / MT-155 deploy. Once MT-154
is fixed (a) should flip to a clean 200; (c) already passes today but is
re-validated each run.

No git side effects, no deploys. Requires: requests, Pillow.
    pip install requests pillow
"""

import io
import sys
import time

import requests

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    print("ERROR: Pillow is required (pip install pillow)")
    sys.exit(2)

BASE = "https://story-weaver-app-production.up.railway.app"

# Generous timeouts: image-gen endpoints can take ~20s; MT-155 may stall ~110s.
GEN_TIMEOUT = 200
SHORT_TIMEOUT = 90

PASS, FAIL, BLOCKED = "PASS", "FAIL", "BLOCKED"

results = []  # list of (id, label, status, detail)


def record(check_id, label, status, detail):
    results.append((check_id, label, status, detail))
    print(f"  [{status}] {check_id}: {detail}")


def excerpt(text, n=240):
    text = (text or "").replace("\n", " ")
    return text if len(text) <= n else text[:n] + " ...(truncated)"


def make_test_png():
    buf = io.BytesIO()
    Image.new("RGB", (256, 256), (128, 180, 220)).save(buf, format="PNG")
    buf.seek(0)
    return buf.read()


def new_anon_account():
    """Create a fresh free-tier anonymous account; return (token, user_id)."""
    r = requests.post(f"{BASE}/auth/anonymous", json={}, timeout=30)
    r.raise_for_status()
    data = r.json()
    return data["token"], data["user_id"]


def auth(token):
    return {"Authorization": f"Bearer {token}"}


# --------------------------------------------------------------------------
# (a) /generate-interactive-story -- not premium-gated, accepts companions
# --------------------------------------------------------------------------
def check_a(token):
    print("\n(a) POST /generate-interactive-story -- not gated, accepts companions")
    payload = {
        "theme": "Adventure",
        "tone": "whimsical",
        "length": "short",
        "age": 7,
        "character_name": "Mia",
        "companion": "a fox",
        "companions": [{"name": "Sparky", "type": "dragon"}],
    }
    try:
        r = requests.post(
            f"{BASE}/generate-interactive-story",
            headers=auth(token),
            json=payload,
            timeout=SHORT_TIMEOUT,
        )
    except requests.RequestException as e:
        record("a", "interactive-story not gated", FAIL, f"request error: {e}")
        return

    body = r.text
    if r.status_code == 403:
        record(
            "a",
            "interactive-story not gated",
            FAIL,
            f"HTTP 403 -- endpoint is premium-gated: {excerpt(body)}",
        )
        return
    if r.status_code == 200:
        record(
            "a",
            "interactive-story not gated",
            PASS,
            "HTTP 200 -- not gated, generation succeeded " "(MT-154 appears fixed)",
        )
        return
    if r.status_code == 500:
        is_truncation = (
            "StringDataRightTruncation" in body
            or "value too long for type character varying" in body
        ) and "image_url" in body
        if is_truncation:
            record(
                "a",
                "interactive-story not gated",
                PASS,
                "HTTP 500 -- not gated; confirmed MT-154 bug "
                f"(image_url truncation): {excerpt(body)}",
            )
        else:
            record(
                "a",
                "interactive-story not gated",
                FAIL,
                f"HTTP 500 but NOT the MT-154 truncation bug: " f"{excerpt(body)}",
            )
        return
    record(
        "a",
        "interactive-story not gated",
        FAIL,
        f"unexpected HTTP {r.status_code}: {excerpt(body)}",
    )


# --------------------------------------------------------------------------
# (b) pet-avatar and coloring-pages stay 403 upgrade_required
# --------------------------------------------------------------------------
def check_b(token, png_bytes):
    print("\n(b) pet-avatar & coloring-pages stay 403 upgrade_required")

    # b1: pet-avatar (multipart)
    try:
        r = requests.post(
            f"{BASE}/avatar/generate-pet-avatar",
            headers=auth(token),
            files={"photo": ("pet.png", png_bytes, "image/png")},
            data={
                "pet_name": "Rex",
                "species": "dog",
                "breed_description": "fluffy",
                "owner_favorite_color": "blue",
            },
            timeout=SHORT_TIMEOUT,
        )
        gated = r.status_code == 403 and "upgrade" in r.text.lower()
        record(
            "b1",
            "pet-avatar gated",
            PASS if gated else FAIL,
            f"HTTP {r.status_code}: {excerpt(r.text)}",
        )
    except requests.RequestException as e:
        record("b1", "pet-avatar gated", FAIL, f"request error: {e}")

    # b2: coloring-pages (json)
    try:
        r = requests.post(
            f"{BASE}/generate-coloring-pages",
            headers=auth(token),
            json={"scene_description": "a castle on a hill"},
            timeout=SHORT_TIMEOUT,
        )
        gated = r.status_code == 403 and "upgrade" in r.text.lower()
        record(
            "b2",
            "coloring-pages gated",
            PASS if gated else FAIL,
            f"HTTP {r.status_code}: {excerpt(r.text)}",
        )
    except requests.RequestException as e:
        record("b2", "coloring-pages gated", FAIL, f"request error: {e}")


# --------------------------------------------------------------------------
# (d) feature-unlocks returns 200 (custom_avatars_generated column exists)
# --------------------------------------------------------------------------
def get_custom_avatar_count(token, user_id):
    """Return (http_status, count_or_None, raw_text)."""
    r = requests.get(
        f"{BASE}/users/{user_id}/feature-unlocks",
        headers=auth(token),
        timeout=30,
    )
    count = None
    if r.status_code == 200:
        try:
            count = r.json().get("custom_avatars_generated")
        except ValueError:
            pass
    return r.status_code, count, r.text


def check_d(token, user_id):
    print("\n(d) /feature-unlocks returns 200 (custom_avatars_generated column)")
    try:
        status, count, body = get_custom_avatar_count(token, user_id)
    except requests.RequestException as e:
        record(
            "d", "custom_avatars_generated column exists", FAIL, f"request error: {e}"
        )
        return None
    if status == 200 and count is not None:
        record(
            "d",
            "custom_avatars_generated column exists",
            PASS,
            f"HTTP 200, custom_avatars_generated={count}",
        )
    elif status == 500 and "UndefinedColumn" in body:
        record(
            "d",
            "custom_avatars_generated column exists",
            FAIL,
            f"HTTP 500 UndefinedColumn -- column missing: {excerpt(body)}",
        )
    else:
        record(
            "d",
            "custom_avatars_generated column exists",
            FAIL,
            f"HTTP {status}: {excerpt(body)}",
        )
    return count


# --------------------------------------------------------------------------
# (c) one-free-avatar gate on /avatar/generate-custom-avatar
# --------------------------------------------------------------------------
def post_custom_avatar(token, png_bytes):
    """Return (http_status_or_None, raw_text, elapsed_s, error_or_None)."""
    t0 = time.time()
    try:
        r = requests.post(
            f"{BASE}/avatar/generate-custom-avatar",
            headers=auth(token),
            files={"photo": ("child.png", png_bytes, "image/png")},
            data={
                "character_name": "Mia",
                "age": "7",
                "gender": "girl",
                "eye_color": "brown",
                "favorite_color": "purple",
            },
            timeout=GEN_TIMEOUT,
        )
        return r.status_code, r.text, time.time() - t0, None
    except requests.RequestException as e:
        return None, "", time.time() - t0, e


def check_c(token, user_id, png_bytes):
    print("\n(c) one-free-avatar gate on /avatar/generate-custom-avatar")

    # count before
    try:
        _, count_before, _ = get_custom_avatar_count(token, user_id)
    except requests.RequestException as e:
        record("c", "one-free-avatar gate", BLOCKED, f"could not read pre-count: {e}")
        return
    print(f"  custom_avatars_generated before: {count_before}")

    # attempt 1
    status1, body1, elapsed1, err1 = post_custom_avatar(token, png_bytes)
    print(f"  attempt 1 -> HTTP {status1} in {elapsed1:.1f}s")

    # MT-155: timeout / 504 / connection reset on the first attempt -> BLOCKED
    mt155 = err1 is not None or status1 in (502, 503, 504) or status1 is None
    if mt155:
        detail = (
            f"MT-155: first generation did not complete cleanly "
            f"(HTTP {status1}, {elapsed1:.0f}s"
            + (f", error={err1}" if err1 else "")
            + "). "
            "Gate cannot be exercised until MT-155 deploys."
        )
        record("c", "one-free-avatar gate", BLOCKED, detail)
        return

    if status1 != 200:
        record(
            "c",
            "one-free-avatar gate",
            FAIL,
            f"attempt 1 expected HTTP 200, got {status1}: {excerpt(body1)}",
        )
        return

    # count after attempt 1 -- must have incremented by exactly 1
    try:
        _, count_after, _ = get_custom_avatar_count(token, user_id)
    except requests.RequestException as e:
        record("c", "one-free-avatar gate", FAIL, f"could not read post-count: {e}")
        return
    print(f"  custom_avatars_generated after attempt 1: {count_after}")

    incremented = (
        count_before is not None
        and count_after is not None
        and count_after == count_before + 1
    )
    if not incremented:
        record(
            "c",
            "one-free-avatar gate",
            FAIL,
            f"custom_avatars_generated did not increment by 1 "
            f"({count_before} -> {count_after})",
        )
        return

    # attempt 2 -- must be 403 with an upgrade payload
    status2, body2, elapsed2, err2 = post_custom_avatar(token, png_bytes)
    print(f"  attempt 2 -> HTTP {status2} in {elapsed2:.1f}s")
    if err2 is not None:
        record(
            "c",
            "one-free-avatar gate",
            BLOCKED,
            f"attempt 2 errored before gate could respond: {err2}",
        )
        return

    gate_ok = status2 == 403 and "upgrade" in body2.lower()
    if gate_ok:
        record(
            "c",
            "one-free-avatar gate",
            PASS,
            f"attempt1=200 (count {count_before}->{count_after}), "
            f"attempt2=403 upgrade: {excerpt(body2)}",
        )
    else:
        record(
            "c",
            "one-free-avatar gate",
            FAIL,
            f"attempt 2 expected 403 upgrade, got {status2}: " f"{excerpt(body2)}",
        )


# --------------------------------------------------------------------------
def main():
    print("=" * 72)
    print("MT-150 production verification smoke test")
    print(f"Target: {BASE}")
    print("=" * 72)

    png_bytes = make_test_png()

    # Each check uses its own fresh anonymous account so metered state
    # (custom_avatars_generated) never leaks between checks.
    try:
        tok_a, _ = new_anon_account()
        tok_b, _ = new_anon_account()
        tok_cd, uid_cd = new_anon_account()
    except requests.RequestException as e:
        print(f"FATAL: could not create anonymous account(s): {e}")
        sys.exit(2)

    check_a(tok_a)
    check_b(tok_b, png_bytes)
    check_d(tok_cd, uid_cd)  # read column before metering it
    check_c(tok_cd, uid_cd, png_bytes)

    # ----- matrix -----
    print("\n" + "=" * 72)
    print("MT-150 VERIFICATION MATRIX")
    print("=" * 72)
    width = max(len(label) for _, label, _, _ in results)
    for cid, label, status, _ in results:
        print(f"  ({cid}) {label.ljust(width)}  {status}")
    print("=" * 72)

    n_fail = sum(1 for _, _, s, _ in results if s == FAIL)
    n_blocked = sum(1 for _, _, s, _ in results if s == BLOCKED)
    if n_fail:
        print(f"RESULT: {n_fail} FAIL, {n_blocked} BLOCKED -- investigate.")
        sys.exit(1)
    if n_blocked:
        print(
            f"RESULT: all runnable checks PASS, {n_blocked} BLOCKED "
            "(re-run after the relevant fix deploys)."
        )
        sys.exit(0)
    print("RESULT: all checks PASS.")
    sys.exit(0)


if __name__ == "__main__":
    main()
