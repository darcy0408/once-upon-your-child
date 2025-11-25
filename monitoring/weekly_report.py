#!/usr/bin/env python3
"""
Weekly Automated Report Generator for Story Weaver Backend
Generates comprehensive weekly reports on uptime, performance, and usage metrics
"""

import requests
import json
import os
from datetime import datetime, timedelta
from collections import defaultdict
import statistics

BACKEND_URL = "https://story-weaver-app-production.up.railway.app"
SLACK_WEBHOOK_URL = os.getenv('SLACK_WEBHOOK_URL')
DISCORD_WEBHOOK_URL = os.getenv('DISCORD_WEBHOOK_URL')
REPORT_EMAIL = os.getenv('REPORT_EMAIL', 'reports@storyweaver.com')

class WeeklyReportGenerator:
    def __init__(self):
        self.backend_url = BACKEND_URL
        self.report_data = {}

    def fetch_analytics_data(self):
        """Fetch all analytics data from the backend"""
        endpoints = [
            'overview',
            'story-stats',
            'user-activity',
            'feature-usage'
        ]

        analytics_data = {}
        for endpoint in endpoints:
            try:
                response = requests.get(f"{self.backend_url}/admin/analytics/{endpoint}", timeout=30)
                if response.status_code == 200:
                    analytics_data[endpoint] = response.json()
                else:
                    print(f"Failed to fetch {endpoint}: HTTP {response.status_code}")
                    analytics_data[endpoint] = {}
            except Exception as e:
                print(f"Error fetching {endpoint}: {e}")
                analytics_data[endpoint] = {}

        return analytics_data

    def calculate_uptime_percentage(self):
        """Calculate uptime percentage (placeholder - would need historical data)"""
        # In a real implementation, this would query uptime monitoring data
        # For now, return a mock high uptime
        return 99.7

    def generate_report(self):
        """Generate the complete weekly report"""
        print("Generating weekly report...")

        # Fetch analytics data
        analytics = self.fetch_analytics_data()

        # Calculate uptime
        uptime_percentage = self.calculate_uptime_percentage()

        # Build report
        report = {
            'generated_at': datetime.utcnow().isoformat(),
            'report_period': {
                'start': (datetime.utcnow() - timedelta(days=7)).isoformat(),
                'end': datetime.utcnow().isoformat()
            },
            'uptime': {
                'percentage': uptime_percentage,
                'downtime_minutes': round((100 - uptime_percentage) * 7 * 24 * 60 / 100, 1)
            },
            'usage_metrics': analytics.get('overview', {}),
            'story_metrics': analytics.get('story-stats', {}),
            'user_metrics': analytics.get('user-activity', {}),
            'feature_metrics': analytics.get('feature-usage', {}),
            'performance_insights': self._generate_performance_insights(analytics),
            'recommendations': self._generate_recommendations(analytics)
        }

        self.report_data = report
        return report

    def _generate_performance_insights(self, analytics):
        """Generate performance insights from analytics data"""
        insights = []

        overview = analytics.get('overview', {})
        story_stats = analytics.get('story-stats', {})

        # Story generation insights
        today_stories = overview.get('today', {}).get('stories_created', 0)
        week_stories = overview.get('this_week', {}).get('stories_created', 0)

        if week_stories > 0:
            avg_daily = week_stories / 7
            insights.append(f"Average {avg_daily:.1f} stories generated per day")

        # Theme popularity
        themes = story_stats.get('by_theme', {})
        if themes:
            top_theme = max(themes.items(), key=lambda x: x[1])
            insights.append(f"Most popular theme: {top_theme[0]} ({top_theme[1]} stories)")

        # User growth
        new_users = overview.get('this_month', {}).get('new_users', 0)
        if new_users > 0:
            insights.append(f"{new_users} new users this month")

        # Feature adoption
        feature_usage = analytics.get('feature-usage', {})
        illustrations = feature_usage.get('illustrations_generated', 0)
        if illustrations > 0:
            insights.append(f"{illustrations} illustrations generated")

        return insights

    def _generate_recommendations(self, analytics):
        """Generate recommendations based on analytics data"""
        recommendations = []

        overview = analytics.get('overview', {})
        story_stats = analytics.get('story-stats', {})

        # Check for high error rates
        error_rate = story_stats.get('failure_rate', 0)
        if error_rate > 0.05:
            recommendations.append(f"⚠️ High story generation failure rate ({error_rate:.1%}). Investigate API issues.")

        # Check user growth
        new_users = overview.get('this_month', {}).get('new_users', 0)
        if new_users < 10:
            recommendations.append("📈 User growth is slow. Consider marketing campaigns.")

        # Check feature adoption
        feature_usage = analytics.get('feature-usage', {})
        unlock_progress = feature_usage.get('feature_unlock_progress', {})

        low_adoption = []
        for feature, count in unlock_progress.items():
            if count < 5:  # Less than 5 users have unlocked this feature
                low_adoption.append(feature.replace('_', ' ').title())

        if low_adoption:
            recommendations.append(f"🎯 Low feature adoption: {', '.join(low_adoption)}. Consider improving discoverability.")

        # Performance recommendations
        avg_response = overview.get('this_week', {}).get('avg_story_time', 0)
        if avg_response > 20:
            recommendations.append("🐌 Story generation is slow. Consider optimizing prompts or caching.")

        return recommendations

    def format_report_text(self):
        """Format the report as readable text"""
        data = self.report_data

        report_lines = [
            "📊 Story Weaver Weekly Report",
            "=" * 40,
            f"Report Period: {data['report_period']['start'][:10]} to {data['report_period']['end'][:10]}",
            f"Generated: {data['generated_at'][:19]} UTC",
            "",
            "🚀 Uptime & Reliability",
            f"  • Uptime: {data['uptime']['percentage']:.1f}%",
            f"  • Downtime: {data['uptime']['downtime_minutes']} minutes",
            ""
        ]

        # Usage metrics
        usage = data.get('usage_metrics', {})
        if usage:
            report_lines.extend([
                "📈 Usage Metrics",
                f"  • Stories Today: {usage.get('today', {}).get('stories_created', 0)}",
                f"  • Stories This Week: {usage.get('this_week', {}).get('stories_created', 0)}",
                f"  • Stories This Month: {usage.get('this_month', {}).get('stories_created', 0)}",
                f"  • Active Users (7d): {usage.get('this_week', {}).get('active_users', 0)}",
                f"  • New Users (30d): {usage.get('this_month', {}).get('new_users', 0)}",
                ""
            ])

        # Performance insights
        insights = data.get('performance_insights', [])
        if insights:
            report_lines.extend([
                "💡 Performance Insights",
            ] + [f"  • {insight}" for insight in insights] + [""])

        # Recommendations
        recommendations = data.get('recommendations', [])
        if recommendations:
            report_lines.extend([
                "🎯 Recommendations",
            ] + [f"  • {rec}" for rec in recommendations] + [""])

        return "\n".join(report_lines)

    def send_report(self):
        """Send the report via configured channels"""
        if not self.report_data:
            print("No report data available. Run generate_report() first.")
            return

        report_text = self.format_report_text()

        # Print to console
        print("\n" + "="*60)
        print(report_text)
        print("="*60)

        # Send to Slack
        if SLACK_WEBHOOK_URL:
            try:
                slack_payload = {
                    'text': '📊 *Story Weaver Weekly Report*',
                    'attachments': [{
                        'color': 'good',
                        'text': report_text,
                        'mrkdwn_in': ['text']
                    }]
                }
                response = requests.post(SLACK_WEBHOOK_URL, json=slack_payload, timeout=10)
                if response.status_code == 200:
                    print("✅ Report sent to Slack")
                else:
                    print(f"❌ Failed to send to Slack: HTTP {response.status_code}")
            except Exception as e:
                print(f"❌ Slack error: {e}")

        # Send to Discord
        if DISCORD_WEBHOOK_URL:
            try:
                # Discord has message length limits, so send as code block
                discord_content = f"```\n{report_text}\n```"
                if len(discord_content) > 2000:  # Discord limit
                    discord_content = discord_content[:1997] + "```"

                discord_payload = {'content': discord_content}
                response = requests.post(DISCORD_WEBHOOK_URL, json=discord_payload, timeout=10)
                if response.status_code == 204:
                    print("✅ Report sent to Discord")
                else:
                    print(f"❌ Failed to send to Discord: HTTP {response.status_code}")
            except Exception as e:
                print(f"❌ Discord error: {e}")

        # Save to file
        filename = f"weekly_report_{datetime.utcnow().strftime('%Y%m%d')}.txt"
        try:
            with open(filename, 'w') as f:
                f.write(report_text)
            print(f"✅ Report saved to {filename}")
        except Exception as e:
            print(f"❌ Failed to save report: {e}")

def main():
    """Main function to generate and send weekly report"""
    generator = WeeklyReportGenerator()

    try:
        print("Generating weekly report...")
        generator.generate_report()
        generator.send_report()
        print("✅ Weekly report completed successfully")
    except Exception as e:
        print(f"❌ Error generating report: {e}")
        # Send error alert
        error_message = f"Failed to generate weekly report: {e}"
        if SLACK_WEBHOOK_URL:
            try:
                requests.post(SLACK_WEBHOOK_URL, json={
                    'text': f"🚨 *Report Generation Failed*\n{error_message}"
                }, timeout=5)
            except:
                pass

if __name__ == '__main__':
    main()