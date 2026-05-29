import io
from datetime import datetime, timedelta, timezone

import jwt

from backend.database import db
from backend.models import User
from backend.routes import avatar_routes

# Minimal valid PNG signature + padding so the avatar route's magic-byte
# photo validation (_is_valid_image) accepts the upload. The validator
# inspects only the leading bytes.
_VALID_PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32


def _create_user(user_id: str, tier: str) -> str:
    """Create a user and return a valid JWT token."""
    user = User(
        id=user_id,
        username=user_id,
        email=f"{user_id}@example.com",
        password_hash="hash",
        subscription_tier=tier,
        role="user",
    )
    db.session.add(user)
    db.session.commit()

    payload = {
        "user_id": user_id,
        "sub": user_id,
        "email": f"{user_id}@example.com",
        "subscription_tier": tier,
        "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
    }
    return jwt.encode(payload, "dev-secret-key", algorithm="HS256")


def test_avatar_generate_route_enforces_free_tier_limit(client, app):
    """Free users should hit the configured per-hour avatar route limit."""
    with app.app_context():
        token = _create_user("free-avatar-user", "free")

    headers = {"Authorization": f"Bearer {token}"}
    statuses = []
    for _ in range(6):
        resp = client.post(
            "/avatar/generate-avatar",
            json={"character_name": "Luna", "age": 7, "style": "nope"},
            headers=headers,
        )
        statuses.append(resp.status_code)

    # Note: 400 is expected because "nope" is an invalid style, but it still counts towards the limit
    assert statuses[:5] == [400, 400, 400, 400, 400]
    assert statuses[5] == 429

    body = resp.get_json()
    assert body["error_code"] == "RATE_LIMIT_EXCEEDED"
    assert body["limit_per_hour"] == 5
    assert "retry_after_seconds" in body
    assert resp.headers.get("X-Avatar-RateLimit-Tier") == "free"


def test_avatar_generate_route_allows_premium_higher_limit(client, app):
    """Premium users should get higher limits than free users."""
    with app.app_context():
        token = _create_user("premium-avatar-user", "premium")

    headers = {"Authorization": f"Bearer {token}"}
    statuses = []
    for _ in range(6):
        resp = client.post(
            "/avatar/generate-avatar",
            json={"character_name": "Luna", "age": 7, "style": "nope"},
            headers=headers,
        )
        statuses.append(resp.status_code)
        assert resp.headers.get("X-Avatar-RateLimit-Limit") == "50"
        assert resp.headers.get("X-Avatar-RateLimit-Tier") == "premium"

    assert statuses == [400, 400, 400, 400, 400, 400]


def test_avatar_generate_route_byok_unlimited_skips_custom_headers(client, app):
    """BYOK users should bypass avatar route limits when byok=None."""
    with app.app_context():
        token = _create_user("byok-avatar-user", "byok")

    headers = {"Authorization": f"Bearer {token}"}
    statuses = []
    for _ in range(6):
        resp = client.post(
            "/avatar/generate-avatar",
            json={"character_name": "Luna", "age": 7, "style": "nope"},
            headers=headers,
        )
        statuses.append(resp.status_code)
        assert resp.headers.get("X-Avatar-RateLimit-Limit") is None

    assert statuses == [400, 400, 400, 400, 400, 400]


def test_generate_custom_avatar_accepts_age_99(client, app, monkeypatch):
    """Custom avatar endpoint should accept upper bound age 99."""
    with app.app_context():
        token = _create_user("custom-avatar-user-99", "free")

    headers = {"Authorization": f"Bearer {token}"}

    class _StubAvatarService:
        def generate_custom_avatar(self, **kwargs):
            assert kwargs["age"] == 99
            return {
                "id": "avatar-test-99",
                "image_base64": "data:image/png;base64,ZmFrZQ==",
            }

    monkeypatch.setattr(avatar_routes, "_avatar_service", _StubAvatarService())

    resp = client.post(
        "/avatar/generate-custom-avatar",
        data={
            "photo": (io.BytesIO(_VALID_PNG_BYTES), "photo.png"),
            "character_name": "Luna",
            "age": "99",
            "gender": "girl",
            "eye_color": "Brown",
            "favorite_color": "Blue",
        },
        headers=headers,
        content_type="multipart/form-data",
    )

    assert resp.status_code == 200
    body = resp.get_json()
    assert body["status"] == "success"
    assert body["avatar"]["id"] == "avatar-test-99"


def test_generate_custom_avatar_returns_400_for_out_of_range_age(
    client, app, monkeypatch
):
    """Out-of-range custom avatar ages should return validation error with 400."""
    with app.app_context():
        token = _create_user("custom-avatar-user-err", "free")

    headers = {"Authorization": f"Bearer {token}"}

    class _StubAvatarService:
        def generate_custom_avatar(self, **kwargs):
            raise ValueError("Age must be between 3 and 99")

    monkeypatch.setattr(avatar_routes, "_avatar_service", _StubAvatarService())

    resp = client.post(
        "/avatar/generate-custom-avatar",
        data={
            "photo": (io.BytesIO(_VALID_PNG_BYTES), "photo.png"),
            "character_name": "Luna",
            "age": "100",
            "gender": "girl",
            "eye_color": "Brown",
            "favorite_color": "Blue",
        },
        headers=headers,
        content_type="multipart/form-data",
    )

    assert resp.status_code == 400
    body = resp.get_json()
    assert body["status"] == "error"
    assert body["error_code"] == "VALIDATION_ERROR"
    assert body["message"] == "Age must be between 3 and 99"


# ---------------------------------------------------------------------------
# S-05 — avatar rate limiter is Redis-backed (shared across gunicorn workers)
# with an in-process fallback that prunes stale hour-buckets.
# ---------------------------------------------------------------------------


class _FakeRedis:
    """
    Minimal in-memory Redis stand-in for the avatar rate limiter.

    Implements only the commands ``_check_avatar_rate_limit`` uses
    (ping/incr/decr/expire/get). A single instance is shared between simulated
    workers in the test, exactly as a real Redis would be.
    """

    def __init__(self):
        self.store = {}
        self.ttls = {}

    def ping(self):
        return True

    def incr(self, key):
        self.store[key] = int(self.store.get(key, 0)) + 1
        return self.store[key]

    def decr(self, key):
        self.store[key] = int(self.store.get(key, 0)) - 1
        return self.store[key]

    def expire(self, key, ttl):
        self.ttls[key] = ttl
        return True

    def get(self, key):
        return self.store.get(key)


def test_avatar_rate_limit_shared_across_workers_via_redis(monkeypatch):
    """
    With Redis configured, the counter is shared: simulating two gunicorn
    workers (separate calls) against ONE Redis instance counts cumulatively,
    so the limit is enforced globally rather than per-process.
    """
    monkeypatch.setenv("REDIS_URL", "redis://test")
    fake = _FakeRedis()
    monkeypatch.setattr(avatar_routes, "_get_avatar_rl_redis", lambda: fake)

    user_key = "user:shared-rl"
    limit = 5

    # "Worker A" handles 3 requests, "Worker B" handles 2 — same Redis.
    for _ in range(3):
        is_limited, count = avatar_routes._check_avatar_rate_limit(user_key, limit)
        assert is_limited is False
    for _ in range(2):
        is_limited, count = avatar_routes._check_avatar_rate_limit(user_key, limit)
        assert is_limited is False

    # 5 used across both workers — the 6th request is over the shared limit.
    is_limited, count = avatar_routes._check_avatar_rate_limit(user_key, limit)
    assert is_limited is True
    assert count == limit

    # Over-limit requests are rolled back, so the counter never climbs past
    # `limit` (a real Redis key would not keep inflating from rejected calls).
    hour_bucket = int(__import__("time").time()) // 3600
    assert int(fake.get(f"avatar:rl:{user_key}:{hour_bucket}")) == limit


def test_avatar_rate_limit_redis_sets_ttl_on_first_increment(monkeypatch):
    """The first INCR for an hour-bucket arms an EXPIRE so the key self-evicts."""
    monkeypatch.setenv("REDIS_URL", "redis://test")
    fake = _FakeRedis()
    monkeypatch.setattr(avatar_routes, "_get_avatar_rl_redis", lambda: fake)

    avatar_routes._check_avatar_rate_limit("user:ttl-test", 5)

    hour_bucket = int(__import__("time").time()) // 3600
    key = f"avatar:rl:user:ttl-test:{hour_bucket}"
    assert fake.ttls.get(key) == avatar_routes._AVATAR_RL_TTL_SECONDS
    assert 3600 < avatar_routes._AVATAR_RL_TTL_SECONDS < 7200


def test_avatar_rate_limit_falls_back_to_inprocess_dict_when_no_redis(app, monkeypatch):
    """When Redis is not configured, the in-process dict counter is used."""
    monkeypatch.setattr(avatar_routes, "_get_avatar_rl_redis", lambda: None)

    with app.app_context():
        # Reset any state from a prior test.
        if hasattr(app, "_avatar_generate_counts"):
            app._avatar_generate_counts.clear()

        user_key = "user:fallback-rl"
        limit = 3
        for _ in range(3):
            is_limited, _ = avatar_routes._check_avatar_rate_limit(user_key, limit)
            assert is_limited is False

        is_limited, count = avatar_routes._check_avatar_rate_limit(user_key, limit)
        assert is_limited is True
        assert count == limit


def test_avatar_rate_limit_fallback_prunes_stale_hour_buckets(app, monkeypatch):
    """
    The in-process fallback dict must not leak: entries from older hour-buckets
    are pruned the next time the limiter runs (S-05 memory-leak fix).
    """
    monkeypatch.setattr(avatar_routes, "_get_avatar_rl_redis", lambda: None)

    with app.app_context():
        current_hour = int(__import__("time").time()) // 3600
        # Seed the dict with stale entries from previous hours.
        app._avatar_generate_counts = {
            f"user:old-a:{current_hour - 1}": 4,
            f"user:old-b:{current_hour - 24}": 9,
            f"user:current:{current_hour}": 1,
        }

        # One real call triggers a prune.
        avatar_routes._check_avatar_rate_limit("user:current", 5)

        counts = app._avatar_generate_counts
        assert f"user:old-a:{current_hour - 1}" not in counts
        assert f"user:old-b:{current_hour - 24}" not in counts
        # The current-hour entry survives and was incremented.
        assert counts[f"user:current:{current_hour}"] == 2


def test_avatar_rate_limit_redis_error_degrades_to_fallback(app, monkeypatch):
    """A Redis call that raises mid-request degrades to the in-process counter."""

    class _ExplodingRedis:
        def ping(self):
            return True

        def incr(self, key):
            raise ConnectionError("redis down")

    monkeypatch.setattr(
        avatar_routes, "_get_avatar_rl_redis", lambda: _ExplodingRedis()
    )

    with app.app_context():
        if hasattr(app, "_avatar_generate_counts"):
            app._avatar_generate_counts.clear()

        # Should not raise — falls through to the in-process dict.
        is_limited, count = avatar_routes._check_avatar_rate_limit("user:degrade", 2)
        assert is_limited is False
        assert count == 1
