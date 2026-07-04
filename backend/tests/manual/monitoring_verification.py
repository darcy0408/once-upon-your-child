import os
import sys
from functools import wraps
from unittest.mock import MagicMock, patch

# Ensure backend module is importable
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../..")))

from backend.app import create_app


def make_passthrough_decorator(*args, **kwargs):
    """Always return a decorator that does nothing but preserves function name.

    This handles both syntaxes:
    - @decorator("arg")  - returns decorator
    - @decorator         - returns decorator (if first arg is callable)
    """

    def decorator(f):
        @wraps(f)
        def wrapper(*a, **kw):
            return f(*a, **kw)

        return wrapper

    return decorator


def create_mock_limiter():
    """Create a mock Limiter that properly preserves decorated function names."""
    mock_limiter = MagicMock()
    mock_limiter.limit = make_passthrough_decorator
    mock_limiter.exempt = make_passthrough_decorator
    mock_limiter.shared_limit = make_passthrough_decorator
    return mock_limiter


def create_mock_cache():
    """Create a mock Cache that properly preserves decorated function names."""
    mock_cache = MagicMock()
    mock_cache.cached = make_passthrough_decorator
    mock_cache.memoize = make_passthrough_decorator
    return mock_cache


def test_sentry_init_production():
    """Verify Sentry initializes in production with correct DSN and sampling."""
    mock_limiter = create_mock_limiter()
    mock_cache = create_mock_cache()

    with patch("backend.app.sentry_sdk") as mock_sentry:
        with patch.dict(
            os.environ,
            {
                "SENTRY_DSN": "https://fake@sentry.io/123",
                "JWT_SECRET_KEY": "test",
                "SECRET_KEY": "test",
            },
        ):
            with patch("backend.app.db"), patch("backend.app.CORS"), patch(
                "backend.app.Limiter", return_value=mock_limiter
            ), patch("backend.app.Cache", return_value=mock_cache):

                create_app("production")

                mock_sentry.init.assert_called_once()
                call_args = mock_sentry.init.call_args[1]
                assert call_args["dsn"] == "https://fake@sentry.io/123"
                assert call_args["environment"] == "production"
                assert call_args["traces_sample_rate"] == 0.1
                assert call_args["profiles_sample_rate"] == 0.0
                assert call_args["before_send"] is not None


def test_sentry_skip_testing():
    """Verify Sentry does NOT initialize in testing mode."""
    mock_limiter = create_mock_limiter()
    mock_cache = create_mock_cache()

    with patch("backend.app.sentry_sdk") as mock_sentry:
        with patch.dict(
            os.environ,
            {
                "SENTRY_DSN": "https://fake@sentry.io/123",
                "JWT_SECRET_KEY": "test",
                "SECRET_KEY": "test",
            },
        ):
            with patch("backend.app.db"), patch("backend.app.CORS"), patch(
                "backend.app.Limiter", return_value=mock_limiter
            ), patch("backend.app.Cache", return_value=mock_cache):

                create_app("testing")

                mock_sentry.init.assert_not_called()
