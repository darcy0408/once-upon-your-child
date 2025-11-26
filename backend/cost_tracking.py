"""
Cost Tracking Module for Story Weaver
Tracks Gemini API usage costs and provides budget monitoring
"""

import os
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
from ..database import db

# Cost estimates based on Gemini API pricing (as of 2024)
# These are approximate and should be updated based on actual pricing
COST_RATES = {
    'gemini-1.5-flash': {
        'input_tokens': 0.00000015,    # $0.15 per million tokens
        'output_tokens': 0.0000006,    # $0.60 per million tokens
    },
    'gemini-1.5-pro': {
        'input_tokens': 0.00000125,    # $1.25 per million tokens
        'output_tokens': 0.000005,      # $5.00 per million tokens
    }
}

# Default model if not specified
DEFAULT_MODEL = 'gemini-1.5-flash'

# Budget limits
DAILY_BUDGET_LIMIT = 10.0    # $10 per day
WEEKLY_BUDGET_LIMIT = 50.0   # $50 per week

# Cost event model (in-memory for now, could be moved to database)
class CostEvent:
    def __init__(self, operation: str, user_id: str, user_tier: str,
                 cost: float, tokens_used: Optional[int] = None,
                 model: Optional[str] = None):
        self.operation = operation
        self.user_id = user_id
        self.user_tier = user_tier
        self.cost = cost
        self.tokens_used = tokens_used
        self.model = model or DEFAULT_MODEL
        self.timestamp = datetime.utcnow()

    def to_dict(self) -> Dict[str, Any]:
        return {
            'operation': self.operation,
            'user_id': self.user_id,
            'user_tier': self.user_tier,
            'cost': self.cost,
            'tokens_used': self.tokens_used,
            'model': self.model,
            'timestamp': self.timestamp.isoformat()
        }

# In-memory storage for cost events (in production, use database)
_cost_events = []

def track_cost(operation: str, user_id: str, user_tier: str,
               tokens_used: Optional[int] = None, model: Optional[str] = None) -> float:
    """
    Track API cost for an operation

    Args:
        operation: Type of operation (story_generation, image_generation, etc.)
        user_id: User identifier
        user_tier: User's subscription tier
        tokens_used: Number of tokens used (if available)
        model: Gemini model used

    Returns:
        Calculated cost in USD
    """
    # Don't track costs for BYOK users (they pay directly)
    if user_tier == 'byok':
        return 0.0

    # Estimate cost based on operation type if tokens not provided
    if tokens_used is None:
        cost = _estimate_cost_by_operation(operation)
    else:
        cost = _calculate_token_cost(tokens_used, model or DEFAULT_MODEL)

    # Create cost event
    event = CostEvent(operation, user_id, user_tier, cost, tokens_used, model)
    _cost_events.append(event)

    # Log the cost event
    logging.info(f"Cost tracked: {operation} for user {user_id} ({user_tier}): ${cost:.6f}")

    # Check budget limits
    _check_budget_limits()

    return cost

def _estimate_cost_by_operation(operation: str) -> float:
    """Estimate cost based on operation type (fallback when token count unavailable)"""
    estimates = {
        'story_generation': 0.002,      # ~$0.002 per story
        'interactive_choice': 0.001,    # ~$0.001 per choice
        'image_generation': 0.01,       # ~$0.01 per image
        'coloring_page': 0.005,         # ~$0.005 per coloring page
    }
    return estimates.get(operation, 0.001)  # Default small cost

def _calculate_token_cost(tokens_used: int, model: str) -> float:
    """Calculate cost based on token usage and model"""
    if model not in COST_RATES:
        model = DEFAULT_MODEL

    rates = COST_RATES[model]

    # For simplicity, assume 70% input tokens, 30% output tokens
    # In reality, you'd get this breakdown from the API response
    input_tokens = int(tokens_used * 0.7)
    output_tokens = tokens_used - input_tokens

    input_cost = input_tokens * rates['input_tokens']
    output_cost = output_tokens * rates['output_tokens']

    return input_cost + output_cost

def _check_budget_limits():
    """Check if daily or weekly budget limits have been exceeded"""
    now = datetime.utcnow()

    # Calculate daily costs
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    daily_costs = [event.cost for event in _cost_events
                   if event.timestamp >= day_start]

    daily_total = sum(daily_costs)

    # Calculate weekly costs
    week_start = day_start - timedelta(days=now.weekday())
    weekly_costs = [event.cost for event in _cost_events
                    if event.timestamp >= week_start]

    weekly_total = sum(weekly_costs)

    # Check limits and alert
    if daily_total > DAILY_BUDGET_LIMIT:
        _send_budget_alert('daily', daily_total, DAILY_BUDGET_LIMIT)

    if weekly_total > WEEKLY_BUDGET_LIMIT:
        _send_budget_alert('weekly', weekly_total, WEEKLY_BUDGET_LIMIT)

def _send_budget_alert(period: str, actual: float, limit: float):
    """Send budget alert notification"""
    message = f"🚨 API Cost Alert: {period.capitalize()} budget exceeded!\n"
    message += f"Limit: ${limit:.2f}\n"
    message += f"Actual: ${actual:.2f}\n"
    message += f"Over by: ${actual - limit:.2f}"

    # Log to application logs
    logging.warning(message)

    # Send to external services if configured
    slack_webhook = os.getenv('SLACK_WEBHOOK_URL')
    if slack_webhook:
        try:
            import requests
            payload = {
                'text': f"🚨 *Story Weaver Cost Alert*\n{message}",
                'attachments': [{
                    'color': 'danger',
                    'fields': [
                        {'title': 'Period', 'value': period, 'short': True},
                        {'title': 'Limit', 'value': f"${limit:.2f}", 'short': True},
                        {'title': 'Actual', 'value': f"${actual:.2f}", 'short': True},
                        {'title': 'Over Budget', 'value': f"${actual - limit:.2f}", 'short': True}
                    ]
                }]
            }
            requests.post(slack_webhook, json=payload, timeout=5)
        except Exception as e:
            logging.error(f"Failed to send Slack alert: {e}")

def get_cost_report(days: int = 7) -> Dict[str, Any]:
    """Generate cost report for the specified number of days"""
    cutoff = datetime.utcnow() - timedelta(days=days)

    # Filter events within time period
    relevant_events = [event for event in _cost_events
                      if event.timestamp >= cutoff]

    # Group by date and operation
    daily_costs = {}
    operation_costs = {}
    model_costs = {}

    for event in relevant_events:
        date_key = event.timestamp.date().isoformat()

        # Daily totals
        if date_key not in daily_costs:
            daily_costs[date_key] = 0
        daily_costs[date_key] += event.cost

        # Operation totals
        if event.operation not in operation_costs:
            operation_costs[event.operation] = {'cost': 0, 'count': 0}
        operation_costs[event.operation]['cost'] += event.cost
        operation_costs[event.operation]['count'] += 1

        # Model totals
        if event.model not in model_costs:
            model_costs[event.model] = 0
        model_costs[event.model] += event.cost

    return {
        'period_days': days,
        'total_cost': sum(event.cost for event in relevant_events),
        'total_operations': len(relevant_events),
        'daily_breakdown': daily_costs,
        'operation_breakdown': operation_costs,
        'model_breakdown': model_costs,
        'budget_limits': {
            'daily': DAILY_BUDGET_LIMIT,
            'weekly': WEEKLY_BUDGET_LIMIT
        },
        'generated_at': datetime.utcnow().isoformat()
    }

def get_daily_total() -> float:
    """Get total costs for today"""
    today = datetime.utcnow().date()
    today_events = [event for event in _cost_events
                    if event.timestamp.date() == today]
    return sum(event.cost for event in today_events)

def get_weekly_total() -> float:
    """Get total costs for this week"""
    now = datetime.utcnow()
    week_start = now.replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=now.weekday())
    week_events = [event for event in _cost_events
                   if event.timestamp >= week_start]
    return sum(event.cost for event in week_events)

def clear_old_events(days_to_keep: int = 30):
    """Clear cost events older than specified days to prevent memory bloat"""
    cutoff = datetime.utcnow() - timedelta(days=days_to_keep)
    global _cost_events
    _cost_events = [event for event in _cost_events if event.timestamp >= cutoff]