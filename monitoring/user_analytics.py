#!/usr/bin/env python3
"""
Advanced User Behavior Analytics for Story Weaver
Segmentation, cohort analysis, and user journey tracking
"""

import os
import json
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
from collections import defaultdict
import pandas as pd
import numpy as np
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
import joblib

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class UserAnalyticsEngine:
    def __init__(self):
        self.user_events = []
        self.user_profiles = {}
        self.segmentation_model = None
        self.scaler = None
        self.model_path = "/models/user_segmentation.pkl"

        # Analytics configuration
        self.session_timeout = 30  # minutes
        self.retention_periods = [1, 3, 7, 14, 30, 90]  # days

    def track_event(self, user_id: str, event_type: str, event_data: Dict[str, Any],
                   timestamp: Optional[datetime] = None):
        """Track a user event for analytics"""
        if timestamp is None:
            timestamp = datetime.utcnow()

        event = {
            'user_id': user_id,
            'event_type': event_type,
            'timestamp': timestamp.isoformat(),
            'data': event_data,
            'session_id': self._get_or_create_session(user_id, timestamp)
        }

        self.user_events.append(event)

        # Update user profile
        self._update_user_profile(user_id, event)

        # Keep only last 100k events for memory efficiency
        if len(self.user_events) > 100000:
            self.user_events = self.user_events[-50000:]

    def _get_or_create_session(self, user_id: str, timestamp: datetime) -> str:
        """Get existing session or create new one"""
        # Simple session logic - in production, use proper session management
        recent_events = [e for e in self.user_events[-100:]
                        if e['user_id'] == user_id]

        if recent_events:
            last_event_time = datetime.fromisoformat(recent_events[-1]['timestamp'])
            time_diff = (timestamp - last_event_time).total_seconds() / 60

            if time_diff < self.session_timeout:
                return recent_events[-1]['session_id']

        # Create new session
        return f"session_{user_id}_{int(timestamp.timestamp())}"

    def _update_user_profile(self, user_id: str, event: Dict[str, Any]):
        """Update user profile based on event"""
        if user_id not in self.user_profiles:
            self.user_profiles[user_id] = {
                'first_seen': event['timestamp'],
                'last_seen': event['timestamp'],
                'total_events': 0,
                'event_types': defaultdict(int),
                'sessions_count': 0,
                'total_session_time': 0,
                'stories_generated': 0,
                'feelings_explored': set(),
                'subscription_status': 'free',
                'age_group': None,
                'engagement_score': 0,
                'retention_days': 0
            }

        profile = self.user_profiles[user_id]
        profile['last_seen'] = event['timestamp']
        profile['total_events'] += 1
        profile['event_types'][event['event_type']] += 1

        # Update specific metrics based on event type
        if event['event_type'] == 'story_generated':
            profile['stories_generated'] += 1
        elif event['event_type'] == 'feeling_selected':
            feeling = event['data'].get('feeling')
            if feeling:
                profile['feelings_explored'].add(feeling)
        elif event['event_type'] == 'subscription_purchased':
            profile['subscription_status'] = 'premium'

        # Calculate engagement score
        profile['engagement_score'] = self._calculate_engagement_score(profile)

    def _calculate_engagement_score(self, profile: Dict[str, Any]) -> float:
        """Calculate user engagement score (0-100)"""
        score = 0

        # Stories generated (max 30 points)
        score += min(profile['stories_generated'] * 2, 30)

        # Feelings explored (max 20 points)
        score += min(len(profile['feelings_explored']) * 2, 20)

        # Session frequency (max 20 points)
        sessions_per_week = profile.get('sessions_per_week', 0)
        score += min(sessions_per_week * 5, 20)

        # Account age bonus (max 15 points)
        if profile.get('first_seen'):
            account_age_days = (datetime.utcnow() -
                              datetime.fromisoformat(profile['first_seen'])).days
            score += min(account_age_days / 10, 15)

        # Premium user bonus (10 points)
        if profile.get('subscription_status') == 'premium':
            score += 10

        return min(score, 100)

    def create_user_segments(self) -> Dict[str, List[str]]:
        """Create user segments using clustering analysis"""
        if len(self.user_profiles) < 10:
            return self._create_rule_based_segments()

        # Prepare data for clustering
        user_data = []
        user_ids = []

        for user_id, profile in self.user_profiles.items():
            features = [
                profile['total_events'],
                profile['stories_generated'],
                len(profile['feelings_explored']),
                profile['engagement_score'],
                1 if profile['subscription_status'] == 'premium' else 0,
                profile.get('sessions_per_week', 0),
            ]
            user_data.append(features)
            user_ids.append(user_id)

        # Scale features
        if not self.scaler:
            self.scaler = StandardScaler()
        X_scaled = self.scaler.fit_transform(user_data)

        # Perform clustering
        if not self.segmentation_model:
            self.segmentation_model = KMeans(n_clusters=5, random_state=42)
        clusters = self.segmentation_model.fit_predict(X_scaled)

        # Group users by cluster
        segments = defaultdict(list)
        for user_id, cluster in zip(user_ids, clusters):
            segment_name = f"segment_{cluster}"
            segments[segment_name].append(user_id)

        # Save model
        os.makedirs(os.path.dirname(self.model_path), exist_ok=True)
        joblib.dump(self.segmentation_model, self.model_path)
        joblib.dump(self.scaler, self.model_path.replace('.pkl', '_scaler.pkl'))

        return dict(segments)

    def _create_rule_based_segments(self) -> Dict[str, List[str]]:
        """Create segments using simple rules when ML isn't feasible"""
        segments = {
            'high_engagement': [],
            'medium_engagement': [],
            'low_engagement': [],
            'premium_users': [],
            'new_users': []
        }

        for user_id, profile in self.user_profiles.items():
            engagement = profile['engagement_score']

            if profile['subscription_status'] == 'premium':
                segments['premium_users'].append(user_id)
            elif engagement >= 70:
                segments['high_engagement'].append(user_id)
            elif engagement >= 40:
                segments['medium_engagement'].append(user_id)
            else:
                segments['low_engagement'].append(user_id)

            # Check if new user (last 7 days)
            if profile.get('first_seen'):
                first_seen = datetime.fromisoformat(profile['first_seen'])
                if (datetime.utcnow() - first_seen).days <= 7:
                    segments['new_users'].append(user_id)

        return segments

    def analyze_cohorts(self) -> Dict[str, Any]:
        """Perform cohort analysis for user retention"""
        cohorts = {}

        # Group users by signup week
        signup_cohorts = defaultdict(list)

        for user_id, profile in self.user_profiles.items():
            if profile.get('first_seen'):
                signup_date = datetime.fromisoformat(profile['first_seen'])
                cohort_key = signup_date.strftime('%Y-%W')  # Year-Week format
                signup_cohorts[cohort_key].append((user_id, profile))

        # Analyze retention for each cohort
        for cohort_key, users in signup_cohorts.items():
            cohort_start = datetime.strptime(cohort_key + '-1', '%Y-%W-%w')  # Monday of the week

            retention_rates = {}
            for period in self.retention_periods:
                period_end = cohort_start + timedelta(days=period)
                active_users = 0

                for user_id, profile in users:
                    if profile.get('last_seen'):
                        last_seen = datetime.fromisoformat(profile['last_seen'])
                        if last_seen >= period_end:
                            active_users += 1

                retention_rates[period] = active_users / len(users) if users else 0

            cohorts[cohort_key] = {
                'cohort_size': len(users),
                'retention_rates': retention_rates,
                'average_engagement': sum(p['engagement_score'] for _, p in users) / len(users),
                'premium_conversion': sum(1 for _, p in users if p['subscription_status'] == 'premium') / len(users)
            }

        return cohorts

    def analyze_user_journey(self, user_id: str) -> Dict[str, Any]:
        """Analyze the complete journey of a specific user"""
        user_events = [e for e in self.user_events if e['user_id'] == user_id]
        user_events.sort(key=lambda x: x['timestamp'])

        if not user_events:
            return {'error': 'User not found'}

        profile = self.user_profiles.get(user_id, {})

        # Analyze journey phases
        journey_phases = {
            'onboarding': [],
            'exploration': [],
            'engagement': [],
            'retention': []
        }

        first_event_time = datetime.fromisoformat(user_events[0]['timestamp'])

        for event in user_events:
            event_time = datetime.fromisoformat(event['timestamp'])
            days_since_first = (event_time - first_event_time).days

            if days_since_first <= 1:
                journey_phases['onboarding'].append(event)
            elif days_since_first <= 7:
                journey_phases['exploration'].append(event)
            elif days_since_first <= 30:
                journey_phases['engagement'].append(event)
            else:
                journey_phases['retention'].append(event)

        # Calculate journey metrics
        journey_metrics = {
            'total_events': len(user_events),
            'total_sessions': len(set(e['session_id'] for e in user_events)),
            'avg_session_length': self._calculate_avg_session_length(user_events),
            'most_common_event': max(set(e['event_type'] for e in user_events),
                                   key=lambda x: sum(1 for e in user_events if e['event_type'] == x)),
            'journey_phases': {phase: len(events) for phase, events in journey_phases.items()},
            'engagement_trend': self._calculate_engagement_trend(user_events),
            'conversion_events': [e for e in user_events if 'subscription' in e['event_type']],
        }

        return {
            'user_id': user_id,
            'profile': profile,
            'journey_metrics': journey_metrics,
            'phase_analysis': journey_phases,
            'recommendations': self._generate_user_recommendations(user_id, journey_metrics)
        }

    def _calculate_avg_session_length(self, events: List[Dict[str, Any]]) -> float:
        """Calculate average session length in minutes"""
        sessions = defaultdict(list)

        for event in events:
            sessions[event['session_id']].append(datetime.fromisoformat(event['timestamp']))

        session_lengths = []
        for session_events in sessions.values():
            if len(session_events) > 1:
                session_events.sort()
                length = (session_events[-1] - session_events[0]).total_seconds() / 60
                session_lengths.append(length)

        return sum(session_lengths) / len(session_lengths) if session_lengths else 0

    def _calculate_engagement_trend(self, events: List[Dict[str, Any]]) -> str:
        """Calculate engagement trend over time"""
        if len(events) < 5:
            return 'insufficient_data'

        # Group events by week
        weekly_counts = defaultdict(int)
        first_event = datetime.fromisoformat(events[0]['timestamp'])

        for event in events:
            event_time = datetime.fromisoformat(event['timestamp'])
            weeks_since_start = (event_time - first_event).days // 7
            weekly_counts[weeks_since_start] += 1

        # Calculate trend
        weeks = sorted(weekly_counts.keys())
        if len(weeks) >= 3:
            recent_avg = sum(weekly_counts[w] for w in weeks[-3:]) / 3
            earlier_avg = sum(weekly_counts[w] for w in weeks[:-3]) / max(1, len(weeks) - 3)

            if recent_avg > earlier_avg * 1.2:
                return 'increasing'
            elif recent_avg < earlier_avg * 0.8:
                return 'decreasing'
            else:
                return 'stable'

        return 'stable'

    def _generate_user_recommendations(self, user_id: str, metrics: Dict[str, Any]) -> List[str]:
        """Generate personalized recommendations for user engagement"""
        recommendations = []

        if metrics['total_events'] < 5:
            recommendations.append("Send onboarding tutorial to increase initial engagement")

        if metrics.get('avg_session_length', 0) < 5:
            recommendations.append("Optimize user interface for better user experience")

        if metrics['most_common_event'] == 'story_generated' and metrics['total_events'] > 20:
            recommendations.append("User is highly engaged - consider premium feature suggestions")

        engagement_trend = metrics.get('engagement_trend', 'stable')
        if engagement_trend == 'decreasing':
            recommendations.append("Implement re-engagement campaign for declining users")

        return recommendations

    def get_analytics_dashboard(self) -> Dict[str, Any]:
        """Generate comprehensive analytics dashboard data"""
        segments = self.create_user_segments()
        cohorts = self.analyze_cohorts()

        # Calculate aggregate metrics
        total_users = len(self.user_profiles)
        active_users_7d = sum(1 for p in self.user_profiles.values()
                            if (datetime.utcnow() - datetime.fromisoformat(p['last_seen'])).days <= 7)
        premium_users = sum(1 for p in self.user_profiles.values()
                          if p['subscription_status'] == 'premium')

        total_stories = sum(p['stories_generated'] for p in self.user_profiles.values())
        avg_engagement = sum(p['engagement_score'] for p in self.user_profiles.values()) / total_users

        # Event type distribution
        event_types = defaultdict(int)
        for event in self.user_events[-10000:]:  # Last 10k events
            event_types[event['event_type']] += 1

        return {
            'timestamp': datetime.utcnow().isoformat(),
            'summary_metrics': {
                'total_users': total_users,
                'active_users_7d': active_users_7d,
                'premium_users': premium_users,
                'premium_conversion_rate': premium_users / total_users if total_users > 0 else 0,
                'total_stories_generated': total_stories,
                'avg_engagement_score': round(avg_engagement, 1),
                'stories_per_user': total_stories / total_users if total_users > 0 else 0
            },
            'user_segments': segments,
            'cohort_analysis': cohorts,
            'event_distribution': dict(event_types),
            'engagement_distribution': self._calculate_engagement_distribution(),
            'top_performing_segments': self._identify_top_segments(segments)
        }

    def _calculate_engagement_distribution(self) -> Dict[str, int]:
        """Calculate distribution of users by engagement level"""
        distribution = {'high': 0, 'medium': 0, 'low': 0}

        for profile in self.user_profiles.values():
            score = profile['engagement_score']
            if score >= 70:
                distribution['high'] += 1
            elif score >= 40:
                distribution['medium'] += 1
            else:
                distribution['low'] += 1

        return distribution

    def _identify_top_segments(self, segments: Dict[str, List[str]]) -> List[Dict[str, Any]]:
        """Identify top performing user segments"""
        segment_metrics = []

        for segment_name, user_ids in segments.items():
            if not user_ids:
                continue

            segment_profiles = [self.user_profiles[uid] for uid in user_ids if uid in self.user_profiles]

            if segment_profiles:
                avg_engagement = sum(p['engagement_score'] for p in segment_profiles) / len(segment_profiles)
                premium_rate = sum(1 for p in segment_profiles if p['subscription_status'] == 'premium') / len(segment_profiles)
                avg_stories = sum(p['stories_generated'] for p in segment_profiles) / len(segment_profiles)

                segment_metrics.append({
                    'segment': segment_name,
                    'size': len(user_ids),
                    'avg_engagement': round(avg_engagement, 1),
                    'premium_rate': round(premium_rate, 3),
                    'avg_stories': round(avg_stories, 1)
                })

        # Sort by engagement score
        segment_metrics.sort(key=lambda x: x['avg_engagement'], reverse=True)
        return segment_metrics[:5]  # Top 5 segments

def main():
    """Main analytics execution"""
    try:
        analytics = UserAnalyticsEngine()

        # Simulate some user events for demonstration
        users = ['user_1', 'user_2', 'user_3', 'user_4', 'user_5']

        for i, user in enumerate(users):
            # Simulate user journey
            analytics.track_event(user, 'app_opened', {})
            analytics.track_event(user, 'feeling_selected', {'feeling': f'feeling_{i%3}'})

            for j in range(i + 1):  # Different engagement levels
                analytics.track_event(user, 'story_generated', {'theme': f'theme_{j}'})

            if i % 2 == 0:  # Some users become premium
                analytics.track_event(user, 'subscription_purchased', {'plan': 'premium'})

        # Generate analytics dashboard
        dashboard = analytics.get_analytics_dashboard()

        print("=== User Behavior Analytics Dashboard ===")
        print(f"Total Users: {dashboard['summary_metrics']['total_users']}")
        print(f"Active Users (7d): {dashboard['summary_metrics']['active_users_7d']}")
        print(f"Premium Users: {dashboard['summary_metrics']['premium_users']}")
        print(".1f")
        print(".1f")
        print(f"Stories Generated: {dashboard['summary_metrics']['total_stories_generated']}")

        print(f"\nEngagement Distribution: {dashboard['engagement_distribution']}")

        print(f"\nTop Segments:")
        for segment in dashboard['top_performing_segments'][:3]:
            print(f"  {segment['segment']}: {segment['size']} users, "
                  f"engagement {segment['avg_engagement']}, "
                  f"premium rate {segment['premium_rate']:.1%}")

        # Analyze a specific user journey
        if users:
            journey = analytics.analyze_user_journey(users[0])
            print(f"\nUser Journey Analysis for {users[0]}:")
            print(f"  Total Events: {journey['journey_metrics']['total_events']}")
            print(f"  Stories Generated: {journey['profile']['stories_generated']}")
            print(f"  Engagement Score: {journey['profile']['engagement_score']}")

        return 0

    except Exception as e:
        logger.error(f"Analytics failed: {e}")
        return 1

if __name__ == "__main__":
    exit(main())