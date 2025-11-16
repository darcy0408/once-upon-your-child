#!/usr/bin/env python3
"""
Story Weaver Cost Monitoring and Optimization
Real-time cost analysis with budget alerts and optimization recommendations
"""

import os
import json
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class CostMonitor:
    def __init__(self):
        self.budget_limits = {
            'monthly_infrastructure': 500.0,  # $500/month
            'monthly_api_calls': 100.0,       # $100/month
            'monthly_storage': 50.0,          # $50/month
            'monthly_total': 800.0            # $800/month total
        }

        # Cost per unit (example rates - adjust based on actual provider)
        self.cost_rates = {
            'railway_instance_hour': 0.0001,    # $0.0001 per hour per instance
            'redis_mb_hour': 0.00002,           # $0.00002 per MB per hour
            'api_call': 0.0001,                 # $0.0001 per API call
            'storage_gb_month': 0.10,           # $0.10 per GB per month
            'cdn_gb_transfer': 0.05             # $0.05 per GB transferred
        }

    def get_current_costs(self) -> Dict[str, float]:
        """Get current month's costs from various sources"""
        current_month = datetime.utcnow().strftime("%Y-%m")

        # In a real implementation, this would query actual cloud provider APIs
        # For now, we'll simulate based on usage metrics

        costs = {
            'infrastructure': self._calculate_infrastructure_cost(),
            'api_calls': self._calculate_api_cost(),
            'storage': self._calculate_storage_cost(),
            'cdn': self._calculate_cdn_cost(),
            'monitoring': self._calculate_monitoring_cost(),
        }

        costs['total'] = sum(costs.values())
        return costs

    def _calculate_infrastructure_cost(self) -> float:
        """Calculate Railway infrastructure costs"""
        # Simulate based on uptime and instance count
        hours_this_month = datetime.utcnow().day * 24  # Rough estimate
        instance_count = 2  # Assume 2 instances running
        return hours_this_month * instance_count * self.cost_rates['railway_instance_hour']

    def _calculate_api_cost(self) -> float:
        """Calculate API call costs"""
        # This would query actual API usage metrics
        # For simulation, assume 100k API calls this month
        api_calls = 100000
        return api_calls * self.cost_rates['api_call']

    def _calculate_storage_cost(self) -> float:
        """Calculate storage costs"""
        # Assume 10GB of database storage
        storage_gb = 10
        return storage_gb * self.cost_rates['storage_gb_month']

    def _calculate_cdn_cost(self) -> float:
        """Calculate CDN transfer costs"""
        # Assume 100GB of CDN transfer this month
        transfer_gb = 100
        return transfer_gb * self.cost_rates['cdn_gb_transfer']

    def _calculate_monitoring_cost(self) -> float:
        """Calculate monitoring costs"""
        # Fixed monthly cost for monitoring services
        return 25.0  # $25/month for monitoring stack

    def check_budget_alerts(self, costs: Dict[str, float]) -> List[Dict[str, Any]]:
        """Check if any costs exceed budget limits"""
        alerts = []

        for category, limit in self.budget_limits.items():
            if category in costs and costs[category] > limit:
                alerts.append({
                    'type': 'budget_exceeded',
                    'category': category,
                    'current_cost': costs[category],
                    'limit': limit,
                    'overage': costs[category] - limit,
                    'severity': 'critical' if costs[category] > limit * 1.2 else 'warning'
                })

        # Check total budget
        if costs['total'] > self.budget_limits['monthly_total']:
            alerts.append({
                'type': 'total_budget_exceeded',
                'current_cost': costs['total'],
                'limit': self.budget_limits['monthly_total'],
                'overage': costs['total'] - self.budget_limits['monthly_total'],
                'severity': 'critical'
            })

        return alerts

    def generate_optimization_recommendations(self, costs: Dict[str, float]) -> List[Dict[str, Any]]:
        """Generate cost optimization recommendations"""
        recommendations = []

        # Infrastructure optimization
        if costs['infrastructure'] > self.budget_limits['monthly_infrastructure'] * 0.8:
            recommendations.append({
                'category': 'infrastructure',
                'recommendation': 'Consider implementing auto-scaling to reduce instance hours during low traffic',
                'potential_savings': costs['infrastructure'] * 0.3,  # 30% potential savings
                'difficulty': 'medium'
            })

        # API optimization
        if costs['api_calls'] > self.budget_limits['monthly_api_calls'] * 0.8:
            recommendations.append({
                'category': 'api_calls',
                'recommendation': 'Implement more aggressive caching to reduce API calls',
                'potential_savings': costs['api_calls'] * 0.4,  # 40% potential savings
                'difficulty': 'easy'
            })

        # Storage optimization
        if costs['storage'] > self.budget_limits['monthly_storage'] * 0.8:
            recommendations.append({
                'category': 'storage',
                'recommendation': 'Implement automated data archiving and cleanup policies',
                'potential_savings': costs['storage'] * 0.5,  # 50% potential savings
                'difficulty': 'medium'
            })

        # CDN optimization
        if costs['cdn'] > 20:  # If CDN costs are high
            recommendations.append({
                'category': 'cdn',
                'recommendation': 'Optimize asset compression and implement better caching headers',
                'potential_savings': costs['cdn'] * 0.25,  # 25% potential savings
                'difficulty': 'easy'
            })

        return recommendations

    def generate_cost_report(self) -> Dict[str, Any]:
        """Generate comprehensive cost report"""
        costs = self.get_current_costs()
        alerts = self.check_budget_alerts(costs)
        recommendations = self.generate_optimization_recommendations(costs)

        report = {
            'timestamp': datetime.utcnow().isoformat(),
            'period': 'monthly',
            'costs': costs,
            'budget_limits': self.budget_limits,
            'budget_utilization': {
                category: (costs.get(category.replace('monthly_', ''), 0) / limit) * 100
                for category, limit in self.budget_limits.items()
            },
            'alerts': alerts,
            'recommendations': recommendations,
            'summary': {
                'total_cost': costs['total'],
                'budget_remaining': self.budget_limits['monthly_total'] - costs['total'],
                'alert_count': len(alerts),
                'recommendation_count': len(recommendations)
            }
        }

        return report

    def export_cost_metrics(self) -> Dict[str, Any]:
        """Export cost metrics for monitoring systems"""
        costs = self.get_current_costs()

        # Format for Prometheus metrics
        metrics = {
            'infrastructure_cost_total': costs['infrastructure'],
            'api_cost_total': costs['api_calls'],
            'storage_cost_total': costs['storage'],
            'cdn_cost_total': costs['cdn'],
            'monitoring_cost_total': costs['monitoring'],
            'total_cost': costs['total']
        }

        return metrics

def main():
    """Main cost monitoring execution"""
    try:
        monitor = CostMonitor()
        report = monitor.generate_cost_report()

        # Print report
        print("=== Story Weaver Cost Report ===")
        print(f"Generated: {report['timestamp']}")
        print(f"Total Cost: ${report['costs']['total']:.2f}")
        print(f"Budget Remaining: ${report['summary']['budget_remaining']:.2f}")
        print(f"Alerts: {report['summary']['alert_count']}")
        print(f"Recommendations: {report['summary']['recommendation_count']}")

        # Print alerts
        if report['alerts']:
            print("\n🚨 BUDGET ALERTS:")
            for alert in report['alerts']:
                print(f"  {alert['severity'].upper()}: {alert['category']} exceeded by ${alert['overage']:.2f}")

        # Print recommendations
        if report['recommendations']:
            print("\n💡 OPTIMIZATION RECOMMENDATIONS:")
            for rec in report['recommendations']:
                print(f"  {rec['category'].upper()}: {rec['recommendation']}")
                print(".2f"                print(f"    Difficulty: {rec['difficulty']}")

        # Export metrics for monitoring
        metrics = monitor.export_cost_metrics()
        print(f"\n📊 Metrics exported: {len(metrics)} cost metrics")

        return 0

    except Exception as e:
        logger.error(f"Cost monitoring failed: {e}")
        return 1

if __name__ == "__main__":
    exit(main())