#!/usr/bin/env python3
"""
Revenue Optimization and Analytics for Story Weaver
Subscription analytics, conversion optimization, and revenue forecasting
"""

import os
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
from collections import defaultdict
import statistics

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class RevenueAnalytics:
    def __init__(self):
        self.subscription_events = []
        self.revenue_data = []
        self.user_lifecycle = defaultdict(dict)

        # Pricing tiers
        self.pricing_tiers = {
            'free': {'price': 0, 'features': ['basic_stories', 'limited_characters']},
            'premium_monthly': {'price': 9.99, 'features': ['unlimited_stories', 'premium_characters', 'offline_access']},
            'premium_yearly': {'price': 99.99, 'features': ['unlimited_stories', 'premium_characters', 'offline_access', 'family_sharing']},
            'family_plan': {'price': 14.99, 'features': ['unlimited_stories', 'premium_characters', 'offline_access', 'up_to_6_users']}
        }

    def track_subscription_event(self, user_id: str, event_type: str, event_data: Dict[str, Any]):
        """Track subscription-related events"""
        event = {
            'user_id': user_id,
            'event_type': event_type,
            'timestamp': datetime.utcnow().isoformat(),
            'data': event_data
        }

        self.subscription_events.append(event)

        # Update user lifecycle
        self._update_user_lifecycle(user_id, event)

        # Track revenue if applicable
        if event_type in ['subscription_started', 'subscription_renewed']:
            self._track_revenue(user_id, event)

        logger.info(f"Tracked subscription event: {event_type} for user {user_id}")

    def _update_user_lifecycle(self, user_id: str, event: Dict[str, Any]):
        """Update user subscription lifecycle"""
        lifecycle = self.user_lifecycle[user_id]

        event_type = event['event_type']
        event_data = event['data']

        if event_type == 'user_registered':
            lifecycle['registration_date'] = event['timestamp']
            lifecycle['current_tier'] = 'free'
            lifecycle['lifecycle_stage'] = 'trial'

        elif event_type == 'subscription_started':
            lifecycle['subscription_start'] = event['timestamp']
            lifecycle['current_tier'] = event_data.get('tier', 'premium_monthly')
            lifecycle['lifecycle_stage'] = 'subscriber'
            lifecycle['first_subscription_date'] = lifecycle.get('first_subscription_date', event['timestamp'])

        elif event_type == 'subscription_cancelled':
            lifecycle['subscription_end'] = event['timestamp']
            lifecycle['cancellation_reason'] = event_data.get('reason')
            lifecycle['lifecycle_stage'] = 'churned'

        elif event_type == 'subscription_renewed':
            lifecycle['last_renewal'] = event['timestamp']
            lifecycle['renewal_count'] = lifecycle.get('renewal_count', 0) + 1

        elif event_type == 'trial_started':
            lifecycle['trial_start'] = event['timestamp']
            lifecycle['lifecycle_stage'] = 'trial'

        elif event_type == 'trial_ended':
            lifecycle['trial_end'] = event['timestamp']
            if lifecycle.get('current_tier') == 'free':
                lifecycle['lifecycle_stage'] = 'free_user'

    def _track_revenue(self, user_id: str, event: Dict[str, Any]):
        """Track revenue from subscription events"""
        event_data = event['data']
        tier = event_data.get('tier', 'premium_monthly')

        if tier in self.pricing_tiers:
            revenue_entry = {
                'user_id': user_id,
                'timestamp': event['timestamp'],
                'tier': tier,
                'amount': self.pricing_tiers[tier]['price'],
                'event_type': event['event_type'],
                'billing_cycle': event_data.get('billing_cycle', 'monthly'),
                'currency': 'USD'
            }

            self.revenue_data.append(revenue_entry)

    def calculate_conversion_funnel(self) -> Dict[str, Any]:
        """Calculate subscription conversion funnel"""
        # Get unique users at each stage
        registered_users = set()
        trial_users = set()
        subscribed_users = set()
        renewed_users = set()

        for event in self.subscription_events:
            user_id = event['user_id']
            event_type = event['event_type']

            if event_type == 'user_registered':
                registered_users.add(user_id)
            elif event_type == 'trial_started':
                trial_users.add(user_id)
            elif event_type == 'subscription_started':
                subscribed_users.add(user_id)
            elif event_type == 'subscription_renewed':
                renewed_users.add(user_id)

        total_registered = len(registered_users)
        total_trial = len(trial_users)
        total_subscribed = len(subscribed_users)
        total_renewed = len(renewed_users)

        funnel = {
            'registered': total_registered,
            'trial_started': total_trial,
            'subscribed': total_subscribed,
            'renewed': total_renewed,
            'conversion_rates': {
                'registration_to_trial': (total_trial / total_registered * 100) if total_registered > 0 else 0,
                'trial_to_subscription': (total_subscribed / total_trial * 100) if total_trial > 0 else 0,
                'subscription_to_renewal': (total_renewed / total_subscribed * 100) if total_subscribed > 0 else 0,
                'overall_conversion': (total_subscribed / total_registered * 100) if total_registered > 0 else 0
            },
            'funnel_dropoff': {
                'registration_to_trial': total_registered - total_trial,
                'trial_to_subscription': total_trial - total_subscribed,
                'subscription_to_renewal': total_subscribed - total_renewed
            }
        }

        return funnel

    def analyze_subscription_metrics(self) -> Dict[str, Any]:
        """Analyze subscription metrics and KPIs"""
        # Calculate MRR (Monthly Recurring Revenue)
        current_subscribers = defaultdict(int)
        revenue_by_tier = defaultdict(float)

        for user_id, lifecycle in self.user_lifecycle.items():
            tier = lifecycle.get('current_tier', 'free')
            if tier != 'free' and lifecycle.get('lifecycle_stage') == 'subscriber':
                current_subscribers[tier] += 1
                revenue_by_tier[tier] += self.pricing_tiers[tier]['price']

        total_mrr = sum(revenue_by_tier.values())

        # Calculate churn rate
        churned_users = sum(1 for lifecycle in self.user_lifecycle.values()
                          if lifecycle.get('lifecycle_stage') == 'churned')

        total_ever_subscribed = sum(1 for lifecycle in self.user_lifecycle.values()
                                  if lifecycle.get('first_subscription_date'))

        churn_rate = (churned_users / total_ever_subscribed * 100) if total_ever_subscribed > 0 else 0

        # Calculate LTV (Lifetime Value)
        avg_ltv = self._calculate_average_ltv()

        # Calculate ARPU (Average Revenue Per User)
        total_users = len(self.user_lifecycle)
        arpu = total_mrr / total_users if total_users > 0 else 0

        return {
            'monthly_recurring_revenue': {
                'total_mrr': round(total_mrr, 2),
                'by_tier': dict(revenue_by_tier),
                'active_subscribers': dict(current_subscribers)
            },
            'churn_metrics': {
                'churned_users': churned_users,
                'total_ever_subscribed': total_ever_subscribed,
                'churn_rate_percent': round(churn_rate, 2),
                'churn_rate_monthly': round(churn_rate / 12, 2)  # Monthly churn rate
            },
            'lifetime_metrics': {
                'average_ltv': round(avg_ltv, 2),
                'arpu': round(arpu, 2),
                'ltv_to_cac_ratio': round(avg_ltv / max(arpu, 1), 2)  # Assuming CAC ≈ ARPU for simplicity
            },
            'subscription_distribution': self._analyze_subscription_distribution()
        }

    def _calculate_average_ltv(self) -> float:
        """Calculate average customer lifetime value"""
        ltv_values = []

        for user_id, lifecycle in self.user_lifecycle.items():
            if lifecycle.get('first_subscription_date'):
                # Calculate revenue generated by this user
                user_revenue = sum(r['amount'] for r in self.revenue_data if r['user_id'] == user_id)
                ltv_values.append(user_revenue)

        return statistics.mean(ltv_values) if ltv_values else 0

    def _analyze_subscription_distribution(self) -> Dict[str, Any]:
        """Analyze subscription tier distribution"""
        tier_counts = defaultdict(int)

        for lifecycle in self.user_lifecycle.values():
            tier = lifecycle.get('current_tier', 'free')
            tier_counts[tier] += 1

        total_users = sum(tier_counts.values())

        return {
            'by_tier': dict(tier_counts),
            'percentages': {tier: round(count / total_users * 100, 1) for tier, count in tier_counts.items()} if total_users > 0 else {},
            'premium_ratio': round((total_users - tier_counts.get('free', 0)) / total_users * 100, 1) if total_users > 0 else 0
        }

    def forecast_revenue(self, months_ahead: int = 12) -> Dict[str, Any]:
        """Forecast future revenue based on current trends"""
        # Simple forecasting based on current MRR and churn rates
        current_metrics = self.analyze_subscription_metrics()

        current_mrr = current_metrics['monthly_recurring_revenue']['total_mrr']
        monthly_churn_rate = current_metrics['churn_metrics']['churn_rate_monthly'] / 100

        forecast = []
        projected_mrr = current_mrr

        for month in range(1, months_ahead + 1):
            # Apply churn and assume 5% monthly growth from new subscribers
            projected_mrr = projected_mrr * (1 - monthly_churn_rate) * 1.05

            forecast.append({
                'month': month,
                'projected_mrr': round(projected_mrr, 2),
                'growth_rate': round(((projected_mrr / current_mrr) - 1) * 100, 1)
            })

        return {
            'forecast_period_months': months_ahead,
            'current_mrr': current_mrr,
            'forecast': forecast,
            'assumptions': {
                'monthly_churn_rate': round(monthly_churn_rate * 100, 2),
                'monthly_growth_rate': 5.0,
                'confidence_level': 'medium'
            }
        }

    def identify_optimization_opportunities(self) -> Dict[str, Any]:
        """Identify revenue optimization opportunities"""
        metrics = self.analyze_subscription_metrics()
        funnel = self.calculate_conversion_funnel()

        opportunities = []

        # Low conversion opportunities
        if funnel['conversion_rates']['trial_to_subscription'] < 20:
            opportunities.append({
                'type': 'conversion_optimization',
                'title': 'Improve Trial to Subscription Conversion',
                'current_rate': round(funnel['conversion_rates']['trial_to_subscription'], 1),
                'target_rate': 25.0,
                'potential_revenue_increase': round(metrics['monthly_recurring_revenue']['total_mrr'] * 0.25, 2),
                'recommendations': [
                    'Enhance onboarding experience',
                    'Add progress indicators during trial',
                    'Implement usage-based upgrade prompts'
                ]
            })

        # High churn opportunities
        if metrics['churn_metrics']['churn_rate_monthly'] > 5:
            opportunities.append({
                'type': 'retention_optimization',
                'title': 'Reduce Monthly Churn Rate',
                'current_rate': metrics['churn_metrics']['churn_rate_monthly'],
                'target_rate': 3.0,
                'potential_savings': round(metrics['monthly_recurring_revenue']['total_mrr'] * 0.02, 2),
                'recommendations': [
                    'Implement win-back campaigns',
                    'Add customer success touchpoints',
                    'Improve product experience based on usage patterns'
                ]
            })

        # Pricing optimization
        premium_ratio = metrics['subscription_distribution']['premium_ratio']
        if premium_ratio < 15:
            opportunities.append({
                'type': 'pricing_optimization',
                'title': 'Increase Premium Subscription Ratio',
                'current_ratio': premium_ratio,
                'target_ratio': 20.0,
                'potential_revenue_increase': round(metrics['monthly_recurring_revenue']['total_mrr'] * 0.33, 2),
                'recommendations': [
                    'Optimize pricing page presentation',
                    'Implement freemium feature limitations',
                    'Add premium feature previews'
                ]
            })

        # LTV optimization
        ltv_to_cac = metrics['lifetime_metrics']['ltv_to_cac_ratio']
        if ltv_to_cac < 3:
            opportunities.append({
                'type': 'ltv_optimization',
                'title': 'Improve LTV to CAC Ratio',
                'current_ratio': ltv_to_cac,
                'target_ratio': 3.0,
                'recommendations': [
                    'Implement referral programs',
                    'Add account expansion opportunities',
                    'Improve product stickiness'
                ]
            })

        return {
            'opportunities': opportunities,
            'total_potential_impact': sum(opp.get('potential_revenue_increase', 0) + opp.get('potential_savings', 0) for opp in opportunities),
            'prioritized_actions': sorted(opportunities, key=lambda x: x.get('potential_revenue_increase', 0) + x.get('potential_savings', 0), reverse=True)
        }

    def generate_revenue_report(self) -> Dict[str, Any]:
        """Generate comprehensive revenue analytics report"""
        conversion_funnel = self.calculate_conversion_funnel()
        subscription_metrics = self.analyze_subscription_metrics()
        revenue_forecast = self.forecast_revenue()
        optimization_opps = self.identify_optimization_opportunities()

        return {
            'report_generated': datetime.utcnow().isoformat(),
            'conversion_funnel': conversion_funnel,
            'subscription_metrics': subscription_metrics,
            'revenue_forecast': revenue_forecast,
            'optimization_opportunities': optimization_opps,
            'key_insights': self._generate_key_insights(conversion_funnel, subscription_metrics),
            'recommendations': self._generate_revenue_recommendations(optimization_opps)
        }

    def _generate_key_insights(self, funnel: Dict[str, Any], metrics: Dict[str, Any]) -> List[str]:
        """Generate key business insights"""
        insights = []

        # Conversion insights
        trial_conversion = funnel['conversion_rates']['trial_to_subscription']
        if trial_conversion > 25:
            insights.append(f"Excellent trial conversion rate of {trial_conversion:.1f}% - trial experience is effective")
        elif trial_conversion < 15:
            insights.append(f"Low trial conversion rate of {trial_conversion:.1f}% - trial experience needs improvement")

        # Revenue insights
        mrr = metrics['monthly_recurring_revenue']['total_mrr']
        insights.append(f"Current MRR: ${mrr:.2f} with {metrics['monthly_recurring_revenue']['active_subscribers'].get('premium_monthly', 0)} monthly subscribers")

        # Churn insights
        churn_rate = metrics['churn_metrics']['churn_rate_monthly']
        if churn_rate < 3:
            insights.append(f"Healthy churn rate of {churn_rate:.1f}% per month")
        else:
            insights.append(f"High churn rate of {churn_rate:.1f}% per month requires attention")

        # LTV insights
        ltv = metrics['lifetime_metrics']['average_ltv']
        arpu = metrics['lifetime_metrics']['arpu']
        if ltv > arpu * 2:
            insights.append(f"Strong LTV (${ltv:.2f}) relative to ARPU (${arpu:.2f}) indicates good customer value")
        else:
            insights.append(f"LTV (${ltv:.2f}) could be improved relative to ARPU (${arpu:.2f})")

        return insights

    def _generate_revenue_recommendations(self, optimization_opps: Dict[str, Any]) -> List[str]:
        """Generate actionable revenue recommendations"""
        recommendations = []

        # Add top optimization opportunities
        for opp in optimization_opps['prioritized_actions'][:3]:
            recommendations.append(f"🚀 {opp['title']}: {opp['recommendations'][0]}")

        # General recommendations
        recommendations.extend([
            "Implement A/B testing for pricing page variations",
            "Set up automated email campaigns for trial users",
            "Monitor and optimize onboarding flow completion rates",
            "Consider annual plan discounts to improve LTV",
            "Implement usage-based upgrade prompts in the app"
        ])

        return recommendations

def main():
    """Main revenue analytics execution"""
    try:
        analytics = RevenueAnalytics()

        # Simulate subscription events
        users = ['user_1', 'user_2', 'user_3', 'user_4', 'user_5', 'user_6', 'user_7', 'user_8']

        for i, user in enumerate(users):
            # Register user
            analytics.track_subscription_event(user, 'user_registered', {})

            # Start trial for some users
            if i % 3 != 0:  # 2/3 start trial
                analytics.track_subscription_event(user, 'trial_started', {})

                # Convert some trial users to paid
                if i % 2 == 0:  # Half of trial users convert
                    tier = 'premium_monthly' if i % 4 != 0 else 'premium_yearly'
                    analytics.track_subscription_event(user, 'subscription_started', {'tier': tier})

                    # Some renew
                    if i % 6 == 0:  # Few renew multiple times
                        analytics.track_subscription_event(user, 'subscription_renewed', {'tier': tier})

        # Generate reports
        print("=== Revenue Analytics Report ===")

        conversion_funnel = analytics.calculate_conversion_funnel()
        print(f"\nConversion Funnel:")
        print(f"  Registered: {conversion_funnel['registered']}")
        print(f"  Trial Started: {conversion_funnel['trial_started']}")
        print(f"  Subscribed: {conversion_funnel['subscribed']}")
        print(f"  Renewed: {conversion_funnel['renewed']}")

        print(f"\nConversion Rates:")
        for stage, rate in conversion_funnel['conversion_rates'].items():
            print(f"  {stage.replace('_', ' ').title()}: {rate:.1f}%")

        subscription_metrics = analytics.analyze_subscription_metrics()
        mrr = subscription_metrics['monthly_recurring_revenue']
        print(f"\nRevenue Metrics:")
        print(f"  Total MRR: ${mrr['total_mrr']:.2f}")
        print(f"  Active Subscribers: {sum(mrr['active_subscribers'].values())}")
        print(f"  Churn Rate: {subscription_metrics['churn_metrics']['churn_rate_monthly']:.1f}%/month")
        print(f"  Average LTV: ${subscription_metrics['lifetime_metrics']['average_ltv']:.2f}")

        forecast = analytics.forecast_revenue(6)
        print(f"\nRevenue Forecast (6 months):")
        for month_data in forecast['forecast'][-3:]:  # Show last 3 months
            print(f"  Month {month_data['month']}: ${month_data['projected_mrr']:.2f} ({month_data['growth_rate']:+.1f}%)")

        optimization = analytics.identify_optimization_opportunities()
        print(f"\nTop Optimization Opportunities:")
        for opp in optimization['prioritized_actions'][:2]:
            impact = opp.get('potential_revenue_increase', 0) + opp.get('potential_savings', 0)
            print(f"  {opp['title']}: +${impact:.2f} potential impact")

        return 0

    except Exception as e:
        logger.error(f"Revenue analytics failed: {e}")
        return 1

if __name__ == "__main__":
    exit(main())