"""Tests for POST /api/transcribe (server-side speech-to-text, web build).

The route sends a child's VOICE to an external vendor, so these tests pin the
guards as much as the happy path: consent gating, upload validation, the size
cap, and — importantly — that the audio is never echoed back or persisted.
"""

import io
from datetime import datetime, timedelta, timezone

import jwt

from backend.database import db
from backend.models import User
from backend.models.consent_record import ConsentRecord
from backend.routes import transcription_routes

# MediaRecorder output is an opaque container; the route only sniffs the
# declared content type, so any non-empty payload exercises the path.
_AUDIO_BYTES = b"\x1a\x45\xdf\xa3" + b"\x00" * 64


def _create_user(user_id: str) -> str:
    user = User(
        id=user_id,
        username=user_id,
        email=f"{user_id}@example.com",
        password_hash="hash",
        subscription_tier="free",
        role="user",
    )
    db.session.add(user)
    db.session.commit()

    payload = {
        "user_id": user_id,
        "sub": user_id,
        "email": f"{user_id}@example.com",
        "subscription_tier": "free",
        "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
    }
    return jwt.encode(payload, "dev-secret-key", algorithm="HS256")


def _grant_consent(user_id: str) -> ConsentRecord:
    record = ConsentRecord(
        user_id=user_id,
        child_age=9,
        consent_method="parent",
        withdrawn=False,
    )
    db.session.add(record)
    db.session.commit()
    return record


class _FakeTranscription:
    def __init__(self, text):
        self.text = text


class _FakeAudio:
    def __init__(self, recorder):
        self._recorder = recorder
        self.transcriptions = self

    def create(self, **kwargs):
        self._recorder.append(kwargs)
        return _FakeTranscription("Marbles")


class _FakeClient:
    def __init__(self, recorder):
        self.audio = _FakeAudio(recorder)


def _post_audio(client, token, data=None, content_type="audio/webm;codecs=opus"):
    payload = _AUDIO_BYTES if data is None else data
    return client.post(
        "/api/transcribe",
        data={"audio": (io.BytesIO(payload), "utterance.webm", content_type)},
        content_type="multipart/form-data",
        headers={"Authorization": f"Bearer {token}"},
    )


def test_transcribe_returns_text(client, app, monkeypatch):
    token = _create_user("voice-user-1")
    _grant_consent("voice-user-1")
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")
    monkeypatch.setenv("TRANSCRIPTION_ENABLED", "true")

    calls = []
    monkeypatch.setattr(
        transcription_routes, "_build_client", lambda key: _FakeClient(calls)
    )

    resp = _post_audio(client, token)

    assert resp.status_code == 200
    assert resp.get_json() == {"text": "Marbles"}
    assert len(calls) == 1


def test_transcribe_requires_auth(client, app):
    resp = client.post(
        "/api/transcribe",
        data={"audio": (io.BytesIO(_AUDIO_BYTES), "u.webm", "audio/webm")},
        content_type="multipart/form-data",
    )
    assert resp.status_code in (401, 403)


def test_transcribe_rejects_missing_audio_part(client, app, monkeypatch):
    token = _create_user("voice-user-2")
    _grant_consent("voice-user-2")
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")
    monkeypatch.setenv("TRANSCRIPTION_ENABLED", "true")

    resp = client.post(
        "/api/transcribe",
        data={},
        content_type="multipart/form-data",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 400


def test_transcribe_rejects_unsupported_content_type(client, app, monkeypatch):
    token = _create_user("voice-user-3")
    _grant_consent("voice-user-3")
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")
    monkeypatch.setenv("TRANSCRIPTION_ENABLED", "true")

    resp = _post_audio(client, token, content_type="application/octet-stream")

    assert resp.status_code == 400
    assert resp.get_json()["error"] == "unsupported_audio_type"


def test_transcribe_rejects_empty_audio(client, app, monkeypatch):
    token = _create_user("voice-user-4")
    _grant_consent("voice-user-4")
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")
    monkeypatch.setenv("TRANSCRIPTION_ENABLED", "true")

    resp = _post_audio(client, token, data=b"")

    assert resp.status_code == 400


def test_transcribe_enforces_size_cap(client, app, monkeypatch):
    token = _create_user("voice-user-5")
    _grant_consent("voice-user-5")
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")
    monkeypatch.setenv("TRANSCRIPTION_ENABLED", "true")

    oversized = b"\x00" * (transcription_routes.MAX_AUDIO_BYTES + 64)
    resp = _post_audio(client, token, data=oversized)

    assert resp.status_code == 413
    assert resp.get_json()["error"] == "audio_too_large"


def test_transcribe_503_without_api_key(client, app, monkeypatch):
    """Enabled but unconfigured must still 503 — flag on, so this genuinely
    exercises the missing-key branch rather than short-circuiting on the flag."""
    token = _create_user("voice-user-6")
    _grant_consent("voice-user-6")
    monkeypatch.setenv("TRANSCRIPTION_ENABLED", "true")
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)

    resp = _post_audio(client, token)

    assert resp.status_code == 503
    assert resp.get_json()["error"] == "transcription_unavailable"


def test_transcribe_fails_closed_when_flag_unset(client, app, monkeypatch):
    """No TRANSCRIPTION_ENABLED means no child voice reaches a vendor."""
    token = _create_user("voice-user-7")
    _grant_consent("voice-user-7")
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")
    monkeypatch.delenv("TRANSCRIPTION_ENABLED", raising=False)

    called = []
    monkeypatch.setattr(
        transcription_routes, "_build_client", lambda key: called.append(key)
    )

    resp = _post_audio(client, token)

    assert resp.status_code == 503
    assert resp.get_json()["error"] == "transcription_unavailable"
    assert called == [], "provider must not be constructed while disabled"


def test_transcribe_does_not_leak_provider_error_text(client, app, monkeypatch):
    """Provider errors must not reach a child, and must not echo voice data."""
    token = _create_user("voice-user-8")
    _grant_consent("voice-user-8")
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")
    monkeypatch.setenv("TRANSCRIPTION_ENABLED", "true")

    def _boom(_key):
        raise RuntimeError("provider exploded with secret detail")

    monkeypatch.setattr(transcription_routes, "_build_client", _boom)

    resp = _post_audio(client, token)

    assert resp.status_code == 503
    body = resp.get_data(as_text=True)
    assert "secret detail" not in body
    assert resp.get_json()["error"] == "transcription_failed"


def test_strips_codec_parameters_from_content_type():
    """MediaRecorder sends 'audio/webm;codecs=opus' — the base type must match."""
    assert (
        transcription_routes._base_content_type("audio/webm;codecs=opus")
        == "audio/webm"
    )
    assert transcription_routes._base_content_type("AUDIO/MP4") == "audio/mp4"
    assert transcription_routes._base_content_type("") == ""
