"""MT-455 / MT-457: one definition of "production", asserted at startup.

Production is decided by the loaded config class (IS_PRODUCTION), not by
RAILWAY_ENVIRONMENT. So a production boot on any host — Docker, another
platform, a Railway environment with a different name — still closes the
test-scaffolding endpoints, and refuses to start without a real database
and secret.
"""

import pytest
from flask import Flask

from backend.app import _run_security_assertions
from backend.config import (
    DevelopmentConfig,
    ProductionConfig,
    TestingConfig,
    env_is_production,
)
from backend.utils.app_helpers import is_production

STRONG_SECRET = "s" * 64


# --- the rule -------------------------------------------------------------


@pytest.mark.parametrize(
    "name, expected",
    [
        ("prod", True),
        ("production", True),
        ("staging", True),  # unrecognised -> fail closed
        ("", True),
        ("dev", False),
        ("development", False),
        ("testing", False),
        (" Testing ", False),
    ],
)
def test_env_is_production_names(name, expected):
    assert env_is_production(name) is expected


def test_env_is_production_reads_flask_env(monkeypatch):
    monkeypatch.setenv("FLASK_ENV", "dev")
    assert env_is_production() is False
    monkeypatch.setenv("FLASK_ENV", "prod")
    assert env_is_production() is True
    # Unset is production, not development.
    monkeypatch.delenv("FLASK_ENV")
    assert env_is_production() is True


def test_config_classes_declare_production():
    assert ProductionConfig.IS_PRODUCTION is True
    assert DevelopmentConfig.IS_PRODUCTION is False
    assert TestingConfig.IS_PRODUCTION is False


def test_is_production_follows_app_config_not_railway(app, monkeypatch):
    # Railway's variable no longer decides anything on its own.
    monkeypatch.setenv("RAILWAY_ENVIRONMENT", "production")
    assert is_production() is False

    monkeypatch.delenv("RAILWAY_ENVIRONMENT")
    monkeypatch.setitem(app.config, "IS_PRODUCTION", True)
    assert is_production() is True


# --- gates on a production boot that is not Railway "production" ----------


@pytest.fixture
def non_railway_production(app, monkeypatch):
    monkeypatch.delenv("RAILWAY_ENVIRONMENT", raising=False)
    monkeypatch.setitem(app.config, "IS_PRODUCTION", True)
    return app


def test_test_scaffolding_is_closed(non_railway_production, client):
    assert client.post("/setup-test-account").status_code == 404
    login = client.post("/auth/login", json={"username": "u", "password": "p"})
    assert login.status_code == 404
    assert client.post("/generate-story-mock", json={}).status_code == 404


def test_hsts_is_sent(non_railway_production, client):
    response = client.get("/health")
    assert "Strict-Transport-Security" in response.headers


def test_scaffolding_still_open_outside_production(client):
    assert client.post("/setup-test-account").status_code in (200, 201)
    assert "Strict-Transport-Security" not in client.get("/health").headers


# --- startup assertions ---------------------------------------------------


def _app_with(**config):
    app = Flask(__name__)
    app.config.update(
        IS_PRODUCTION=True,
        JWT_SECRET_KEY=STRONG_SECRET,
        SECRET_KEY=STRONG_SECRET,
        SQLALCHEMY_DATABASE_URI="postgresql://db.internal/app",
    )
    app.config.update(config)
    return app


@pytest.fixture
def prod_env(monkeypatch):
    monkeypatch.setenv("REDIS_URL", "redis://redis.internal:6379/0")
    monkeypatch.delenv("RAILWAY_ENVIRONMENT", raising=False)


def test_healthy_production_boot_passes(prod_env):
    _run_security_assertions(_app_with(), "production")


def test_production_refuses_sqlite_fallback(prod_env):
    with pytest.raises(RuntimeError, match="DATABASE_URL"):
        _run_security_assertions(
            _app_with(SQLALCHEMY_DATABASE_URI="sqlite:///app.db"), "production"
        )


def test_production_refuses_fallback_secret_key(prod_env):
    with pytest.raises(RuntimeError, match="SECRET_KEY"):
        _run_security_assertions(
            _app_with(SECRET_KEY="dev-secret_key-fallback"), "production"
        )


def test_development_may_use_sqlite(prod_env):
    _run_security_assertions(
        _app_with(IS_PRODUCTION=False, SQLALCHEMY_DATABASE_URI="sqlite:///dev.db"),
        "dev",
    )


def test_railway_production_refuses_dev_config(prod_env, monkeypatch):
    monkeypatch.setenv("RAILWAY_ENVIRONMENT", "production")
    with pytest.raises(RuntimeError, match="FLASK_ENV"):
        _run_security_assertions(_app_with(IS_PRODUCTION=False), "dev")
