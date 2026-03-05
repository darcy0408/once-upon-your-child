from datetime import datetime, timedelta

from backend.services import usage_tracking_service as usage_module
from backend.services.usage_tracking_service import APICall, UsageTrackingService


class TestUsageTrackingService:
    def test_track_call_estimates_cost_and_persists(self, tmp_path):
        storage = tmp_path / "usage_data.json"
        service = UsageTrackingService(storage_path=str(storage))

        call = service.track_call(
            endpoint="story",
            model="gemini-2.5-flash",
            input_tokens=1000,
            output_tokens=500,
            is_mock=False,
        )

        expected_cost = (1000 * service.PRICING["gemini-2.5-flash"]["input"]) + (
            500 * service.PRICING["gemini-2.5-flash"]["output"]
        )
        reloaded = UsageTrackingService(storage_path=str(storage))

        assert abs(call.estimated_cost - expected_cost) < 1e-12
        assert len(reloaded.calls) == 1
        assert reloaded.calls[0].endpoint == "story"

    def test_track_call_mock_has_zero_cost(self, tmp_path):
        service = UsageTrackingService(storage_path=str(tmp_path / "mock.json"))

        call = service.track_call(endpoint="avatar", is_mock=True)

        assert call.estimated_cost == 0.0
        assert call.input_tokens == service.AVG_TOKENS["avatar"]["input"]
        assert call.output_tokens == service.AVG_TOKENS["avatar"]["output"]

    def test_get_usage_summary_filters_mock_calls(self, tmp_path):
        service = UsageTrackingService(storage_path=str(tmp_path / "summary.json"))
        now = datetime.now()
        service.calls = [
            APICall(
                timestamp=(now - timedelta(days=1)).isoformat(),
                endpoint="story",
                model="gemini-2.5-flash",
                input_tokens=100,
                output_tokens=50,
                estimated_cost=0.01,
                is_mock=False,
                metadata={},
            ),
            APICall(
                timestamp=(now - timedelta(hours=2)).isoformat(),
                endpoint="avatar",
                model="gemini-2.5-flash",
                input_tokens=50,
                output_tokens=20,
                estimated_cost=0.0,
                is_mock=True,
                metadata={},
            ),
        ]

        summary = service.get_usage_summary(
            start_date=now - timedelta(days=2),
            end_date=now,
            include_mock=False,
        )

        assert summary["totals"]["calls"] == 1
        assert summary["mock_vs_real"]["mock_calls"] == 0
        assert summary["mock_vs_real"]["real_calls"] == 1
        assert "story" in summary["by_endpoint"]

    def test_get_daily_breakdown_groups_by_day(self, tmp_path):
        service = UsageTrackingService(storage_path=str(tmp_path / "daily.json"))
        now = datetime.now()
        day_key = now.strftime("%Y-%m-%d")
        service.calls = [
            APICall(
                timestamp=now.isoformat(),
                endpoint="story",
                model="gemini-2.5-flash",
                input_tokens=10,
                output_tokens=5,
                estimated_cost=0.001,
                is_mock=False,
                metadata={},
            ),
            APICall(
                timestamp=now.isoformat(),
                endpoint="avatar",
                model="gemini-2.5-flash",
                input_tokens=8,
                output_tokens=4,
                estimated_cost=0.0,
                is_mock=True,
                metadata={},
            ),
        ]

        breakdown = service.get_daily_breakdown(days=1)

        assert day_key in breakdown["daily"]
        assert breakdown["daily"][day_key]["calls"] == 2
        assert breakdown["daily"][day_key]["real_calls"] == 1
        assert breakdown["daily"][day_key]["mock_calls"] == 1

    def test_clear_old_data_removes_expired_records(self, tmp_path):
        service = UsageTrackingService(storage_path=str(tmp_path / "cleanup.json"))
        now = datetime.now()
        service.calls = [
            APICall(
                timestamp=(now - timedelta(days=120)).isoformat(),
                endpoint="story",
                model="gemini-2.5-flash",
                input_tokens=10,
                output_tokens=5,
                estimated_cost=0.001,
                is_mock=False,
                metadata={},
            ),
            APICall(
                timestamp=(now - timedelta(days=5)).isoformat(),
                endpoint="story",
                model="gemini-2.5-flash",
                input_tokens=10,
                output_tokens=5,
                estimated_cost=0.001,
                is_mock=False,
                metadata={},
            ),
        ]

        service.clear_old_data(days_to_keep=30)

        assert len(service.calls) == 1

    def test_get_usage_tracker_returns_singleton(self, tmp_path, monkeypatch):
        usage_module._usage_tracker = None

        class TempTracker(UsageTrackingService):
            def __init__(self):
                super().__init__(storage_path=str(tmp_path / "singleton.json"))

        monkeypatch.setattr(usage_module, "UsageTrackingService", TempTracker)

        tracker_one = usage_module.get_usage_tracker()
        tracker_two = usage_module.get_usage_tracker()

        assert tracker_one is tracker_two
