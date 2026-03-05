"""
Tests for the POST /avatars/tweak-gallery-avatar endpoint.
"""
import io
import json
import sys
import os
import uuid
from unittest.mock import patch, MagicMock

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

_noop = lambda f: f  # noqa: E731  — patch for require_auth decorator


@pytest.fixture(autouse=True)
def clear_rate_limits():
    """Reset the shared rate-limit hit counter before every test."""
    import backend.routes.avatar_routes as _mod
    _mod._rate_limit_hits.clear()
    yield
    _mod._rate_limit_hits.clear()


@pytest.fixture
def app():
    with patch("backend.middleware.auth.require_auth", _noop):
        from flask import Flask
        from backend.routes.avatar_routes import avatar_bp

        _app = Flask(__name__)
        _app.config.update(TESTING=True, SECRET_KEY="test", JWT_SECRET_KEY="test")
        _app.register_blueprint(avatar_bp, url_prefix="/avatars")
        yield _app


@pytest.fixture
def client(app):
    uid = uuid.uuid4().hex  # unique per test so rate limits never bleed
    with patch("backend.routes.avatar_routes.get_user_tier", return_value="premium"), \
         patch("backend.routes.avatar_routes.get_user_identifier", return_value=uid):
        yield app.test_client()


# ---------------------------------------------------------------------------
# Validation tests
# ---------------------------------------------------------------------------

def test_missing_image_returns_400(client):
    r = client.post(
        "/avatars/tweak-gallery-avatar",
        data={"hair_length": "long"},
        content_type="multipart/form-data",
    )
    assert r.status_code == 400
    assert json.loads(r.data)["error_code"] == "MISSING_IMAGE"


def test_no_changes_returns_400(client):
    r = client.post(
        "/avatars/tweak-gallery-avatar",
        data={"image": (io.BytesIO(b"fake"), "a.webp")},
        content_type="multipart/form-data",
    )
    assert r.status_code == 400
    assert json.loads(r.data)["error_code"] == "NO_CHANGES"


def test_empty_string_changes_returns_400(client):
    """hair_length='' and eye_color='' should also trigger NO_CHANGES."""
    r = client.post(
        "/avatars/tweak-gallery-avatar",
        data={"image": (io.BytesIO(b"fake"), "a.webp"), "hair_length": "", "eye_color": ""},
        content_type="multipart/form-data",
    )
    assert r.status_code == 400
    assert json.loads(r.data)["error_code"] == "NO_CHANGES"


# ---------------------------------------------------------------------------
# Generation tests
# ---------------------------------------------------------------------------

def test_gemini_failure_returns_500(client):
    with patch(
        "backend.gemini_image_generator.GeminiImageGenerator.tweak_gallery_avatar",
        return_value=[],
    ):
        r = client.post(
            "/avatars/tweak-gallery-avatar",
            data={"image": (io.BytesIO(b"fake"), "a.webp"), "hair_length": "long"},
            content_type="multipart/form-data",
        )
        assert r.status_code == 500
        assert json.loads(r.data)["error_code"] == "GENERATION_FAILED"


def test_successful_tweak_returns_base64(client):
    mock_images = [{"image_data": "abc123==", "format": "png"}]
    with patch(
        "backend.gemini_image_generator.GeminiImageGenerator.tweak_gallery_avatar",
        return_value=mock_images,
    ) as mock_fn:
        r = client.post(
            "/avatars/tweak-gallery-avatar",
            data={
                "image": (io.BytesIO(b"real_webp_bytes"), "avatar_042.webp"),
                "hair_length": "long",
                "eye_color": "blue",
            },
            content_type="multipart/form-data",
        )
        assert r.status_code == 200
        d = json.loads(r.data)
        assert d["status"] == "success"
        assert d["tweaked_image_base64"] == "abc123=="

        call_kwargs = mock_fn.call_args.kwargs
        assert call_kwargs["hair_length"] == "long"
        assert call_kwargs["eye_color"] == "blue"
        assert isinstance(call_kwargs["image_bytes"], bytes)


def test_hair_only_tweak(client):
    mock_images = [{"image_data": "hair_only_b64", "format": "png"}]
    with patch(
        "backend.gemini_image_generator.GeminiImageGenerator.tweak_gallery_avatar",
        return_value=mock_images,
    ) as mock_fn:
        r = client.post(
            "/avatars/tweak-gallery-avatar",
            data={"image": (io.BytesIO(b"x"), "a.webp"), "hair_length": "curly"},
            content_type="multipart/form-data",
        )
        assert r.status_code == 200
        call_kwargs = mock_fn.call_args.kwargs
        assert call_kwargs["hair_length"] == "curly"
        assert call_kwargs["eye_color"] is None


def test_eye_only_tweak(client):
    mock_images = [{"image_data": "eye_b64", "format": "png"}]
    with patch(
        "backend.gemini_image_generator.GeminiImageGenerator.tweak_gallery_avatar",
        return_value=mock_images,
    ) as mock_fn:
        r = client.post(
            "/avatars/tweak-gallery-avatar",
            data={"image": (io.BytesIO(b"x"), "a.webp"), "eye_color": "green"},
            content_type="multipart/form-data",
        )
        assert r.status_code == 200
        call_kwargs = mock_fn.call_args.kwargs
        assert call_kwargs["hair_length"] is None
        assert call_kwargs["eye_color"] == "green"


# ---------------------------------------------------------------------------
# Rate limit: free users blocked
# ---------------------------------------------------------------------------

def test_free_user_blocked(app):
    uid = uuid.uuid4().hex
    with patch("backend.routes.avatar_routes.get_user_tier", return_value="free"), \
         patch("backend.routes.avatar_routes.get_user_identifier", return_value=uid):
        r = app.test_client().post(
            "/avatars/tweak-gallery-avatar",
            data={"image": (io.BytesIO(b"x"), "a.webp"), "hair_length": "long"},
            content_type="multipart/form-data",
        )
        assert r.status_code == 429
        d = json.loads(r.data)
        assert d["error_code"] == "RATE_LIMIT_EXCEEDED"
        assert d["limit_per_hour"] == 0


# ---------------------------------------------------------------------------
# Unit tests: GeminiImageGenerator.tweak_gallery_avatar
# ---------------------------------------------------------------------------

def test_tweak_no_client_returns_empty():
    from backend.gemini_image_generator import GeminiImageGenerator
    g = GeminiImageGenerator(api_key=None)
    assert g.tweak_gallery_avatar(b"fake", hair_length="long") == []


def test_tweak_no_changes_returns_empty():
    from backend.gemini_image_generator import GeminiImageGenerator
    g = GeminiImageGenerator(api_key=None)
    assert g.tweak_gallery_avatar(b"fake") == []


def test_tweak_prompt_contains_changes():
    """Verify the edit prompt mentions the requested changes."""
    from backend.gemini_image_generator import GeminiImageGenerator

    captured = {}

    def mock_generate(model, contents, config):
        captured["contents"] = contents
        raise RuntimeError("stop here")

    g = GeminiImageGenerator.__new__(GeminiImageGenerator)
    g.api_key = "fake"
    g._model_name = "gemini-fake"
    g._request_timeout_seconds = 30
    mock_client = MagicMock()
    mock_client.models.generate_content.side_effect = mock_generate
    g._client = mock_client

    result = g.tweak_gallery_avatar(b"img", hair_length="long", eye_color="blue")
    assert result == []
    contents = captured.get("contents", [])
    assert any("long" in str(c) for c in contents)
    assert any("blue" in str(c) for c in contents)

import io
import json
import sys
import os
from unittest.mock import patch, MagicMock

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

# Patch auth before any blueprint import so the decorator is a no-op
_noop = lambda f: f  # noqa: E731


@pytest.fixture
def app():
    with patch("backend.middleware.auth.require_auth", _noop):
        from flask import Flask
        from backend.routes.avatar_routes import avatar_bp  # noqa: F401 — side-effect import

        _app = Flask(__name__)
        _app.config.update(TESTING=True, SECRET_KEY="test", JWT_SECRET_KEY="test")

        # Re-register with fresh blueprint each time to avoid state leakage
        from backend.routes.avatar_routes import avatar_bp as _bp
        _app.register_blueprint(_bp, url_prefix="/avatars")
        yield _app


@pytest.fixture
def client(app):
    with patch("backend.routes.avatar_routes.get_user_tier", return_value="premium"), \
         patch("backend.routes.avatar_routes.get_user_identifier", return_value="u1"):
        yield app.test_client()


# ---------------------------------------------------------------------------
# Validation tests
# ---------------------------------------------------------------------------

def test_missing_image_returns_400(client):
    r = client.post(
        "/avatars/tweak-gallery-avatar",
        data={"hair_length": "long"},
        content_type="multipart/form-data",
    )
    assert r.status_code == 400
    assert json.loads(r.data)["error_code"] == "MISSING_IMAGE"


def test_no_changes_returns_400(client):
    r = client.post(
        "/avatars/tweak-gallery-avatar",
        data={"image": (io.BytesIO(b"fake"), "a.webp")},
        content_type="multipart/form-data",
    )
    assert r.status_code == 400
    assert json.loads(r.data)["error_code"] == "NO_CHANGES"


def test_empty_string_changes_returns_400(client):
    """hair_length='' and eye_color='' should also trigger NO_CHANGES."""
    r = client.post(
        "/avatars/tweak-gallery-avatar",
        data={"image": (io.BytesIO(b"fake"), "a.webp"), "hair_length": "", "eye_color": ""},
        content_type="multipart/form-data",
    )
    assert r.status_code == 400
    assert json.loads(r.data)["error_code"] == "NO_CHANGES"


# ---------------------------------------------------------------------------
# Generation tests
# ---------------------------------------------------------------------------

def test_gemini_failure_returns_500(client):
    with patch(
        "backend.gemini_image_generator.GeminiImageGenerator.tweak_gallery_avatar",
        return_value=[],
    ):
        r = client.post(
            "/avatars/tweak-gallery-avatar",
            data={"image": (io.BytesIO(b"fake"), "a.webp"), "hair_length": "long"},
            content_type="multipart/form-data",
        )
        assert r.status_code == 500
        assert json.loads(r.data)["error_code"] == "GENERATION_FAILED"


def test_successful_tweak_returns_base64(client):
    mock_images = [{"image_data": "abc123==", "format": "png"}]
    with patch(
        "backend.gemini_image_generator.GeminiImageGenerator.tweak_gallery_avatar",
        return_value=mock_images,
    ) as mock_fn:
        r = client.post(
            "/avatars/tweak-gallery-avatar",
            data={
                "image": (io.BytesIO(b"real_webp_bytes"), "avatar_042.webp"),
                "hair_length": "long",
                "eye_color": "blue",
            },
            content_type="multipart/form-data",
        )
        assert r.status_code == 200
        d = json.loads(r.data)
        assert d["status"] == "success"
        assert d["tweaked_image_base64"] == "abc123=="

        # Verify correct params passed to Gemini
        call_kwargs = mock_fn.call_args
        assert call_kwargs.kwargs["hair_length"] == "long"
        assert call_kwargs.kwargs["eye_color"] == "blue"
        assert isinstance(call_kwargs.kwargs["image_bytes"], bytes)


def test_hair_only_tweak(client):
    mock_images = [{"image_data": "hair_only_b64", "format": "png"}]
    with patch(
        "backend.gemini_image_generator.GeminiImageGenerator.tweak_gallery_avatar",
        return_value=mock_images,
    ) as mock_fn:
        r = client.post(
            "/avatars/tweak-gallery-avatar",
            data={"image": (io.BytesIO(b"x"), "a.webp"), "hair_length": "curly"},
            content_type="multipart/form-data",
        )
        assert r.status_code == 200
        call_kwargs = mock_fn.call_args.kwargs
        assert call_kwargs["hair_length"] == "curly"
        assert call_kwargs["eye_color"] is None


def test_eye_only_tweak(client):
    mock_images = [{"image_data": "eye_b64", "format": "png"}]
    with patch(
        "backend.gemini_image_generator.GeminiImageGenerator.tweak_gallery_avatar",
        return_value=mock_images,
    ) as mock_fn:
        r = client.post(
            "/avatars/tweak-gallery-avatar",
            data={"image": (io.BytesIO(b"x"), "a.webp"), "eye_color": "green"},
            content_type="multipart/form-data",
        )
        assert r.status_code == 200
        call_kwargs = mock_fn.call_args.kwargs
        assert call_kwargs["hair_length"] is None
        assert call_kwargs["eye_color"] == "green"


# ---------------------------------------------------------------------------
# Rate limit: free users blocked
# ---------------------------------------------------------------------------

def test_free_user_blocked(app):
    with patch("backend.routes.avatar_routes.get_user_tier", return_value="free"), \
         patch("backend.routes.avatar_routes.get_user_identifier", return_value="free_u"):
        r = app.test_client().post(
            "/avatars/tweak-gallery-avatar",
            data={"image": (io.BytesIO(b"x"), "a.webp"), "hair_length": "long"},
            content_type="multipart/form-data",
        )
        assert r.status_code == 429
        assert json.loads(r.data)["error_code"] == "RATE_LIMIT_EXCEEDED"


# ---------------------------------------------------------------------------
# Unit tests: GeminiImageGenerator.tweak_gallery_avatar
# ---------------------------------------------------------------------------

def test_tweak_no_client_returns_empty():
    from backend.gemini_image_generator import GeminiImageGenerator
    g = GeminiImageGenerator(api_key=None)
    assert g.tweak_gallery_avatar(b"fake", hair_length="long") == []


def test_tweak_no_changes_returns_empty():
    from backend.gemini_image_generator import GeminiImageGenerator
    g = GeminiImageGenerator(api_key=None)
    assert g.tweak_gallery_avatar(b"fake") == []


def test_tweak_prompt_contains_changes():
    """Verify the edit prompt mentions the requested changes."""
    from backend.gemini_image_generator import GeminiImageGenerator

    captured = {}

    def mock_generate(model, contents, config):
        captured["contents"] = contents
        raise RuntimeError("stop here")

    g = GeminiImageGenerator.__new__(GeminiImageGenerator)
    g.api_key = "fake"
    g._model_name = "gemini-fake"
    g._request_timeout_seconds = 30
    mock_client = MagicMock()
    mock_client.models.generate_content.side_effect = mock_generate
    g._client = mock_client

    result = g.tweak_gallery_avatar(b"img", hair_length="long", eye_color="blue")
    assert result == []
    contents = captured.get("contents", [])
    assert any("long" in str(c) for c in contents)
    assert any("blue" in str(c) for c in contents)
