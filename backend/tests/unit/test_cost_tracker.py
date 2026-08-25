"""Tests for backend/services/cost_tracker.py — durable spend telemetry (MT-402).

Covers the OpenAI/Azure cost helper math, the budget alert with its
once-per-period dedupe, and the admin cost-report aggregation that replaced
the retired in-memory backend/cost_tracking.py.
"""

import pytest

from backend.models.audit_log import AuditLog
from backend.services.cost_tracker import (
    azure_tts_cost,
    get_cost_report,
    log_api_cost,
    openai_image_cost,
    openai_text_cost,
    openai_transcription_cost,
)

# ---- Helper math ----


def test_openai_text_cost_gpt5_mini():
    # 1M input at $0.25 + 1M output at $2.00
    assert openai_text_cost(1_000_000, 1_000_000) == pytest.approx(2.25)


def test_openai_text_cost_gpt4o_mini_rates():
    assert openai_text_cost(1_000_000, 1_000_000, model="gpt-4o-mini") == pytest.approx(
        0.75
    )


def test_openai_text_cost_unknown_model_falls_back_to_gpt5_mini():
    # An unrecognized model must cost like the workhorse model, never $0.
    assert openai_text_cost(1_000_000, 0, model="mystery-model") == pytest.approx(0.25)


def test_openai_image_cost_token_rates():
    # $5 text-in, $8 image-in, $30 image-out per 1M tokens
    assert openai_image_cost(1000, 1000, 1000) == pytest.approx(0.043)


def test_openai_transcription_cost_per_minute():
    assert openai_transcription_cost(60, "gpt-4o-mini-transcribe") == pytest.approx(
        0.003
    )
    assert openai_transcription_cost(60, "gpt-4o-transcribe") == pytest.approx(0.006)
    # Unknown model falls back to the pricier rate rather than $0.
    assert openai_transcription_cost(60, "mystery") == pytest.approx(0.006)


def test_azure_tts_cost():
    assert azure_tts_cost(1_000_000) == pytest.approx(16.0)


def test_negative_units_do_not_go_negative():
    assert openai_text_cost(-5, -5) == 0.0
    assert openai_image_cost(-1, -1, -1) == 0.0
    assert openai_transcription_cost(-1) == 0.0
    assert azure_tts_cost(-100) == 0.0


# ---- Durable logging + budget alerting ----


def _cost_rows():
    return AuditLog.query.filter_by(event_type="api_cost_incurred").all()


def _alert_rows():
    return AuditLog.query.filter_by(event_type="budget_alert_sent").all()


def test_log_api_cost_writes_audit_row(app):
    log_api_cost(
        provider="openai",
        feature="story_text",
        cost_usd=0.001234,
        user_id="user-1",
        units=5000,
        unit_kind="tokens",
        extra={"model": "gpt-5-mini"},
    )
    rows = _cost_rows()
    assert len(rows) == 1
    data = rows[0].event_data
    assert data["provider"] == "openai"
    assert data["feature"] == "story_text"
    assert data["cost_usd"] == pytest.approx(0.001234)
    assert data["units"] == 5000
    assert data["model"] == "gpt-5-mini"
    assert rows[0].user_id == "user-1"


def test_budget_alert_fires_once_per_period(app, monkeypatch):
    monkeypatch.delenv("SLACK_WEBHOOK_URL", raising=False)
    monkeypatch.setenv("AI_BUDGET_DAILY_USD", "0.005")
    monkeypatch.setenv("AI_BUDGET_WEEKLY_USD", "1000")

    log_api_cost(provider="openai", feature="story_text", cost_usd=0.01)
    alerts = _alert_rows()
    assert len(alerts) == 1
    assert alerts[0].event_data["period"] == "daily"
    assert alerts[0].event_data["limit_usd"] == pytest.approx(0.005)

    # A second over-budget call must NOT send a second alert (dedupe).
    log_api_cost(provider="openai", feature="story_text", cost_usd=0.01)
    assert len(_alert_rows()) == 1


def test_budget_under_limit_sends_no_alert(app, monkeypatch):
    monkeypatch.setenv("AI_BUDGET_DAILY_USD", "10")
    monkeypatch.setenv("AI_BUDGET_WEEKLY_USD", "50")
    log_api_cost(provider="openai", feature="story_text", cost_usd=0.01)
    assert _alert_rows() == []


def test_daily_and_weekly_alerts_dedupe_separately(app, monkeypatch):
    monkeypatch.delenv("SLACK_WEBHOOK_URL", raising=False)
    monkeypatch.setenv("AI_BUDGET_DAILY_USD", "0.005")
    monkeypatch.setenv("AI_BUDGET_WEEKLY_USD", "0.005")
    log_api_cost(provider="openai", feature="story_text", cost_usd=0.01)
    assert sorted(row.event_data["period"] for row in _alert_rows()) == [
        "daily",
        "weekly",
    ]


def test_log_api_cost_never_raises_without_app_context():
    # Outside any Flask app context both the audit write and the budget check
    # fail internally; the public never-raises contract must hold regardless.
    log_api_cost(provider="openai", feature="story_text", cost_usd=0.01)


# ---- Report aggregation ----


def test_cost_report_aggregates_rows(app):
    log_api_cost(
        provider="openai",
        feature="story_text",
        cost_usd=0.002,
        user_id="u1",
        extra={"model": "gpt-5-mini"},
    )
    log_api_cost(
        provider="openai",
        feature="story_text",
        cost_usd=0.003,
        user_id="u1",
        extra={"model": "gpt-5-mini"},
    )
    log_api_cost(provider="azure", feature="tts", cost_usd=0.05, user_id="u2")

    report = get_cost_report(days=7)
    assert report["total_calls"] == 3
    assert report["total_cost_usd"] == pytest.approx(0.055)
    assert report["feature_breakdown"]["story_text"]["calls"] == 2
    assert report["feature_breakdown"]["story_text"]["cost_usd"] == pytest.approx(0.005)
    assert report["provider_breakdown"]["azure"] == pytest.approx(0.05)
    assert report["model_breakdown"]["gpt-5-mini"] == pytest.approx(0.005)
    assert report["budget"]["today_usd"] == pytest.approx(0.055)
    assert set(report["budget"]) == {
        "daily_limit_usd",
        "weekly_limit_usd",
        "today_usd",
        "this_week_usd",
    }


def test_cost_report_ignores_other_event_types(app):
    from backend.utils.audit import audit_log

    audit_log("story_generated", user_id="u1", data={"tier": "free"})
    report = get_cost_report(days=7)
    assert report["total_calls"] == 0
    assert report["total_cost_usd"] == 0.0


def test_cost_report_clamps_days(app):
    assert get_cost_report(days=500)["period_days"] == 90
    assert get_cost_report(days=0)["period_days"] == 1
