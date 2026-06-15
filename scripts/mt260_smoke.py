"""MT-260 prod smoke-verify for the Story Notes `practiced` field (#279).

Run against the deployed backend AFTER the #279 deploy is live:

    python scripts/mt260_smoke.py

It (1) opens an anonymous session, (2) writes one throwaway Big Feelings
parent-hidden-context row, (3) generates a guided story (expects `practiced`
present) and a plain control story (expects `practiced` absent). Test data
only; controlled-vocab values; ~2 GPT-5 mini generations.
"""
import json
import urllib.request
import urllib.error
import uuid

BASE = "https://story-weaver-app-production.up.railway.app"


def call(method, path, body=None, token=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:500]


def main():
    st, auth = call("POST", "/auth/anonymous", {})
    print("auth:", st)
    if st != 200:
        print(auth)
        return
    token = auth.get("access_token") or auth.get("token") or auth.get("accessToken")
    uid = auth.get("user_id") or auth.get("userId") or (auth.get("user") or {}).get("id")
    print("  token?", bool(token), "user_id:", uid)

    profile = "mt260-smoke-" + uuid.uuid4().hex[:8]

    st, ctx = call(
        "PUT",
        f"/child-profiles/{profile}/parent-hidden-context",
        {
            "trigger": "a limit is set",
            "coping_tool": "dragon breaths",
            "repair_goal": "try again with warmth",
        },
        token,
    )
    print("save context:", st)
    if st != 200:
        print("  ", ctx)

    char = {"name": "Smoke", "age": 7, "gender": "neutral"}

    def gen(label, extra):
        body = {"character": char, "age": 7, "theme": "Big Feelings Quest"}
        body.update(extra)
        st, resp = call("POST", "/generate-story", body, token)
        practiced = None
        if isinstance(resp, dict):
            story = resp.get("story") if isinstance(resp.get("story"), dict) else {}
            practiced = story.get("practiced") or resp.get("practiced")
        print(f"\n[{label}] generate-story: {st}")
        if isinstance(resp, dict):
            story = resp.get("story") if isinstance(resp.get("story"), dict) else {}
            print("  provider_seq:", resp.get("provider_sequence") or story.get("provider_sequence"))
            print("  practiced:", json.dumps(practiced) if practiced else "ABSENT")
        else:
            print("  raw:", resp)
        return practiced

    p1 = gen("GUIDED w/ context", {"child_profile_id": profile})
    p2 = gen("CONTROL no context", {"theme": "Adventure"})

    print("\n=== RESULT ===")
    print("guided practiced present:", bool(p1), "(expect True)")
    print("control practiced absent:", not bool(p2), "(expect True)")


if __name__ == "__main__":
    main()
