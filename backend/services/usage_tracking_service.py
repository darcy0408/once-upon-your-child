"""
API Usage Tracking Service
Tracks Gemini API usage and estimates costs
"""

import json
import logging
from collections import defaultdict
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional

logger = logging.getLogger(__name__)


@dataclass
class APICall:
    """Record of a single API call"""

    timestamp: str
    endpoint: str  # 'story', 'avatar', 'illustration', 'coloring'
    model: str  # 'gemini-2.0-flash', etc.
    input_tokens: int
    output_tokens: int
    estimated_cost: float
    is_mock: bool = False
    metadata: Optional[Dict] = None


class UsageTrackingService:
    """
    Tracks API usage and costs for Gemini API calls.

    Features:
    - Track all API calls with token counts
    - Estimate costs based on current pricing
    - Generate daily/weekly/monthly reports
    - Support mock mode (zero cost tracking)
    - Persist usage data to JSON file
    """

    # Gemini 2.5 Flash pricing (December 2025)
    PRICING = {
        "gemini-2.5-flash": {
            "input": 0.30 / 1_000_000,  # $0.30 per 1M input tokens
            "output": 2.50 / 1_000_000,  # $2.50 per 1M output tokens
        },
        "gemini-2.0-flash-exp": {
            # Experimental - free tier limits, estimate similar pricing
            "input": 0.30 / 1_000_000,
            "output": 2.50 / 1_000_000,
        },
        "gemini-2.0-flash": {
            "input": 0.30 / 1_000_000,
            "output": 2.50 / 1_000_000,
        },
    }

    # Average token counts for estimation when actual count not available
    AVG_TOKENS = {
        "story": {"input": 7000, "output": 500},
        "avatar": {"input": 500, "output": 100},
        "illustration": {"input": 500, "output": 100},
        "coloring": {"input": 500, "output": 100},
    }

    def __init__(self, storage_path: Optional[str] = None):
        """
        Initialize usage tracking service.

        Args:
            storage_path: Path to JSON file for storing usage data.
                         Defaults to backend/usage_data.json
        """
        if storage_path is None:
            backend_dir = Path(__file__).parent.parent
            storage_path = backend_dir / "usage_data.json"

        self.storage_path = Path(storage_path)
        self.calls: List[APICall] = []
        self._load_usage_data()

    def _load_usage_data(self):
        """Load existing usage data from JSON file"""
        if self.storage_path.exists():
            try:
                with open(self.storage_path, "r") as f:
                    data = json.load(f)
                    self.calls = [APICall(**call) for call in data]
                logger.info(
                    f"Loaded {len(self.calls)} API call records from {self.storage_path}"
                )
            except Exception as e:
                logger.warning(f"Failed to load usage data: {e}")
                self.calls = []
        else:
            logger.info("No existing usage data found, starting fresh")
            self.calls = []

    def _save_usage_data(self):
        """Save usage data to JSON file"""
        try:
            # Ensure directory exists
            self.storage_path.parent.mkdir(parents=True, exist_ok=True)

            with open(self.storage_path, "w") as f:
                data = [asdict(call) for call in self.calls]
                json.dump(data, f, indent=2)
            logger.debug(f"Saved {len(self.calls)} records to {self.storage_path}")
        except Exception as e:
            logger.error(f"Failed to save usage data: {e}")

    def track_call(
        self,
        endpoint: str,
        model: str = "gemini-2.0-flash",
        input_tokens: Optional[int] = None,
        output_tokens: Optional[int] = None,
        is_mock: bool = False,
        metadata: Optional[Dict] = None,
    ) -> APICall:
        """
        Track an API call and estimate its cost.

        Args:
            endpoint: Type of API call ('story', 'avatar', 'illustration', 'coloring')
            model: Gemini model used
            input_tokens: Number of input tokens (estimated if None)
            output_tokens: Number of output tokens (estimated if None)
            is_mock: Whether this was a mock call (zero cost)
            metadata: Optional metadata dict

        Returns:
            APICall record
        """
        # Use averages if tokens not provided
        if input_tokens is None:
            input_tokens = self.AVG_TOKENS.get(endpoint, {}).get("input", 1000)
        if output_tokens is None:
            output_tokens = self.AVG_TOKENS.get(endpoint, {}).get("output", 200)

        # Calculate cost
        if is_mock:
            estimated_cost = 0.0
        else:
            pricing = self.PRICING.get(model, self.PRICING["gemini-2.5-flash"])
            estimated_cost = (
                input_tokens * pricing["input"] + output_tokens * pricing["output"]
            )

        call = APICall(
            timestamp=datetime.now().isoformat(),
            endpoint=endpoint,
            model=model,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            estimated_cost=estimated_cost,
            is_mock=is_mock,
            metadata=metadata or {},
        )

        self.calls.append(call)
        self._save_usage_data()

        logger.info(
            f"Tracked {'MOCK' if is_mock else 'REAL'} API call: "
            f"{endpoint} ({input_tokens} in, {output_tokens} out, ${estimated_cost:.6f})"
        )

        return call

    def get_usage_summary(
        self,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        include_mock: bool = True,
    ) -> Dict:
        """
        Get usage summary for a date range.

        Args:
            start_date: Start date (defaults to 30 days ago)
            end_date: End date (defaults to now)
            include_mock: Whether to include mock calls in summary

        Returns:
            Dict with usage statistics
        """
        if end_date is None:
            end_date = datetime.now()
        if start_date is None:
            start_date = end_date - timedelta(days=30)

        # Filter calls by date range
        filtered_calls = [
            call
            for call in self.calls
            if start_date <= datetime.fromisoformat(call.timestamp) <= end_date
            and (include_mock or not call.is_mock)
        ]

        # Calculate totals
        total_calls = len(filtered_calls)
        total_cost = sum(call.estimated_cost for call in filtered_calls)
        total_input_tokens = sum(call.input_tokens for call in filtered_calls)
        total_output_tokens = sum(call.output_tokens for call in filtered_calls)

        # Breakdown by endpoint
        by_endpoint = defaultdict(
            lambda: {"count": 0, "cost": 0.0, "input_tokens": 0, "output_tokens": 0}
        )

        for call in filtered_calls:
            by_endpoint[call.endpoint]["count"] += 1
            by_endpoint[call.endpoint]["cost"] += call.estimated_cost
            by_endpoint[call.endpoint]["input_tokens"] += call.input_tokens
            by_endpoint[call.endpoint]["output_tokens"] += call.output_tokens

        # Breakdown by model
        by_model = defaultdict(
            lambda: {"count": 0, "cost": 0.0, "input_tokens": 0, "output_tokens": 0}
        )

        for call in filtered_calls:
            by_model[call.model]["count"] += 1
            by_model[call.model]["cost"] += call.estimated_cost
            by_model[call.model]["input_tokens"] += call.input_tokens
            by_model[call.model]["output_tokens"] += call.output_tokens

        # Mock vs Real breakdown
        mock_calls = [c for c in filtered_calls if c.is_mock]
        real_calls = [c for c in filtered_calls if not c.is_mock]

        return {
            "period": {
                "start": start_date.isoformat(),
                "end": end_date.isoformat(),
            },
            "totals": {
                "calls": total_calls,
                "cost": round(total_cost, 6),
                "input_tokens": total_input_tokens,
                "output_tokens": total_output_tokens,
                "total_tokens": total_input_tokens + total_output_tokens,
            },
            "by_endpoint": dict(by_endpoint),
            "by_model": dict(by_model),
            "mock_vs_real": {
                "mock_calls": len(mock_calls),
                "real_calls": len(real_calls),
                "mock_cost": 0.0,
                "real_cost": round(sum(c.estimated_cost for c in real_calls), 6),
            },
            "recent_calls": [
                {
                    "timestamp": call.timestamp,
                    "endpoint": call.endpoint,
                    "cost": round(call.estimated_cost, 6),
                    "is_mock": call.is_mock,
                }
                for call in filtered_calls[-10:]  # Last 10 calls
            ],
        }

    def get_daily_breakdown(self, days: int = 7) -> Dict:
        """
        Get daily breakdown of usage for the last N days.

        Args:
            days: Number of days to include

        Returns:
            Dict with daily statistics
        """
        end_date = datetime.now()
        start_date = end_date - timedelta(days=days)

        daily_stats = defaultdict(
            lambda: {
                "calls": 0,
                "cost": 0.0,
                "input_tokens": 0,
                "output_tokens": 0,
                "mock_calls": 0,
                "real_calls": 0,
            }
        )

        for call in self.calls:
            call_date = datetime.fromisoformat(call.timestamp)
            if start_date <= call_date <= end_date:
                day_key = call_date.strftime("%Y-%m-%d")
                daily_stats[day_key]["calls"] += 1
                daily_stats[day_key]["cost"] += call.estimated_cost
                daily_stats[day_key]["input_tokens"] += call.input_tokens
                daily_stats[day_key]["output_tokens"] += call.output_tokens

                if call.is_mock:
                    daily_stats[day_key]["mock_calls"] += 1
                else:
                    daily_stats[day_key]["real_calls"] += 1

        # Sort by date
        sorted_stats = dict(sorted(daily_stats.items()))

        return {"period_days": days, "daily": sorted_stats}

    def clear_old_data(self, days_to_keep: int = 90):
        """
        Remove usage data older than specified days.

        Args:
            days_to_keep: Number of days of data to keep
        """
        cutoff_date = datetime.now() - timedelta(days=days_to_keep)

        original_count = len(self.calls)
        self.calls = [
            call
            for call in self.calls
            if datetime.fromisoformat(call.timestamp) >= cutoff_date
        ]

        removed_count = original_count - len(self.calls)
        if removed_count > 0:
            self._save_usage_data()
            logger.info(
                f"Removed {removed_count} old usage records (keeping {days_to_keep} days)"
            )


# Global instance
_usage_tracker: Optional[UsageTrackingService] = None


def get_usage_tracker() -> UsageTrackingService:
    """Get global usage tracker instance"""
    global _usage_tracker
    if _usage_tracker is None:
        _usage_tracker = UsageTrackingService()
    return _usage_tracker
