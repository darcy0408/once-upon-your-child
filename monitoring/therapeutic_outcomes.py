#!/usr/bin/env python3
"""
Therapeutic Outcome Tracking for Story Weaver
Measure emotional learning effectiveness and therapeutic impact
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

class TherapeuticOutcomeTracker:
    def __init__(self):
        self.outcome_data = []
        self.emotional_journeys = defaultdict(list)
        self.therapeutic_metrics = defaultdict(dict)

        # Emotional intelligence indicators
        self.ei_indicators = {
            'emotional_awareness': ['feeling_recognition', 'emotion_labeling', 'intensity_understanding'],
            'emotional_regulation': ['coping_strategy_usage', 'impulse_control', 'stress_management'],
            'social_emotional_learning': ['empathy_development', 'relationship_building', 'conflict_resolution'],
            'resilience_building': ['adaptability', 'optimism', 'problem_solving']
        }

    def track_therapeutic_session(self, user_id: str, session_data: Dict[str, Any]):
        """Track a therapeutic session outcome"""
        session_record = {
            'user_id': user_id,
            'timestamp': datetime.utcnow().isoformat(),
            'session_type': session_data.get('type', 'story_therapy'),
            'feeling_before': session_data.get('feeling_before'),
            'feeling_after': session_data.get('feeling_after'),
            'intensity_before': session_data.get('intensity_before', 5),
            'intensity_after': session_data.get('intensity_after', 3),
            'coping_strategies_used': session_data.get('coping_strategies', []),
            'story_theme': session_data.get('theme'),
            'age_group': session_data.get('age_group'),
            'session_duration': session_data.get('duration_minutes', 10),
            'user_feedback': session_data.get('feedback'),
            'therapeutic_goals': session_data.get('goals', []),
        }

        self.outcome_data.append(session_record)
        self.emotional_journeys[user_id].append(session_record)

        # Update therapeutic metrics
        self._update_therapeutic_metrics(user_id, session_record)

        # Keep only last 1000 sessions for memory efficiency
        if len(self.outcome_data) > 1000:
            self.outcome_data = self.outcome_data[-500:]

        logger.info(f"Tracked therapeutic session for user {user_id}")

    def _update_therapeutic_metrics(self, user_id: str, session: Dict[str, Any]):
        """Update therapeutic metrics for a user"""
        metrics = self.therapeutic_metrics[user_id]

        # Emotional regulation effectiveness
        intensity_reduction = session['intensity_before'] - session['intensity_after']
        metrics['avg_intensity_reduction'] = metrics.get('avg_intensity_reduction', 0) * 0.9 + intensity_reduction * 0.1

        # Coping strategy effectiveness
        if session['coping_strategies_used']:
            metrics['coping_strategy_usage'] = metrics.get('coping_strategy_usage', 0) + 1

        # Session engagement
        metrics['total_sessions'] = metrics.get('total_sessions', 0) + 1
        metrics['total_engagement_time'] = metrics.get('total_engagement_time', 0) + session['session_duration']

        # Emotional vocabulary growth
        feelings_explored = set()
        if session['feeling_before']:
            feelings_explored.add(session['feeling_before'])
        if session['feeling_after']:
            feelings_explored.add(session['feeling_after'])

        current_vocab = metrics.get('emotional_vocabulary', set())
        current_vocab.update(feelings_explored)
        metrics['emotional_vocabulary'] = current_vocab
        metrics['vocabulary_size'] = len(current_vocab)

        # Therapeutic progress indicators
        metrics['last_session_date'] = session['timestamp']

    def calculate_emotional_intelligence_score(self, user_id: str) -> Dict[str, Any]:
        """Calculate emotional intelligence score based on therapeutic data"""
        if user_id not in self.therapeutic_metrics:
            return {'overall_score': 0, 'components': {}}

        metrics = self.therapeutic_metrics[user_id]
        sessions = self.emotional_journeys[user_id]

        ei_scores = {}

        # Emotional Awareness (0-100)
        vocabulary_size = metrics.get('vocabulary_size', 0)
        awareness_score = min(100, vocabulary_size * 10)  # 10 emotions = 100 points
        ei_scores['emotional_awareness'] = awareness_score

        # Emotional Regulation (0-100)
        avg_reduction = metrics.get('avg_intensity_reduction', 0)
        regulation_score = min(100, max(0, (avg_reduction / 5) * 100))  # 5-point reduction = 100 points
        ei_scores['emotional_regulation'] = regulation_score

        # Therapeutic Engagement (0-100)
        total_sessions = metrics.get('total_sessions', 0)
        engagement_score = min(100, total_sessions * 5)  # 20 sessions = 100 points
        ei_scores['therapeutic_engagement'] = engagement_score

        # Coping Strategy Mastery (0-100)
        coping_usage = metrics.get('coping_strategy_usage', 0)
        coping_score = min(100, coping_usage * 10)  # 10 coping uses = 100 points
        ei_scores['coping_mastery'] = coping_score

        # Overall EI Score
        overall_score = statistics.mean(ei_scores.values()) if ei_scores else 0

        return {
            'overall_score': round(overall_score, 1),
            'components': ei_scores,
            'assessment': self._interpret_ei_score(overall_score),
            'recommendations': self._generate_ei_recommendations(ei_scores)
        }

    def _interpret_ei_score(self, score: float) -> str:
        """Interpret emotional intelligence score"""
        if score >= 80:
            return "Excellent emotional intelligence development"
        elif score >= 60:
            return "Good emotional intelligence with room for growth"
        elif score >= 40:
            return "Developing emotional intelligence"
        elif score >= 20:
            return "Beginning emotional intelligence development"
        else:
            return "Early stage emotional intelligence exploration"

    def _generate_ei_recommendations(self, ei_scores: Dict[str, float]) -> List[str]:
        """Generate personalized EI development recommendations"""
        recommendations = []

        if ei_scores.get('emotional_awareness', 0) < 50:
            recommendations.append("Focus on exploring and naming different emotions through stories")

        if ei_scores.get('emotional_regulation', 0) < 50:
            recommendations.append("Practice coping strategies and emotional regulation techniques")

        if ei_scores.get('therapeutic_engagement', 0) < 50:
            recommendations.append("Increase frequency of therapeutic story sessions")

        if ei_scores.get('coping_mastery', 0) < 50:
            recommendations.append("Learn and practice specific coping strategies for different emotions")

        if not recommendations:
            recommendations.append("Continue excellent emotional intelligence development")

        return recommendations

    def analyze_therapeutic_effectiveness(self) -> Dict[str, Any]:
        """Analyze overall therapeutic effectiveness across all users"""
        if not self.outcome_data:
            return {'error': 'No therapeutic data available'}

        # Aggregate metrics
        total_sessions = len(self.outcome_data)
        unique_users = len(set(session['user_id'] for session in self.outcome_data))

        # Effectiveness metrics
        intensity_reductions = []
        session_durations = []
        coping_strategies_used = 0

        for session in self.outcome_data:
            if session.get('intensity_before') and session.get('intensity_after'):
                reduction = session['intensity_before'] - session['intensity_after']
                intensity_reductions.append(reduction)

            session_durations.append(session.get('session_duration', 10))

            if session.get('coping_strategies_used'):
                coping_strategies_used += len(session['coping_strategies_used'])

        # Calculate averages
        avg_intensity_reduction = statistics.mean(intensity_reductions) if intensity_reductions else 0
        avg_session_duration = statistics.mean(session_durations) if session_durations else 0

        # Age group analysis
        age_group_effectiveness = self._analyze_age_group_effectiveness()

        # Emotional theme effectiveness
        theme_effectiveness = self._analyze_theme_effectiveness()

        return {
            'summary': {
                'total_sessions': total_sessions,
                'unique_users': unique_users,
                'avg_intensity_reduction': round(avg_intensity_reduction, 2),
                'avg_session_duration': round(avg_session_duration, 1),
                'total_coping_strategies_used': coping_strategies_used,
                'sessions_per_user': round(total_sessions / unique_users, 1) if unique_users > 0 else 0
            },
            'effectiveness_metrics': {
                'emotional_regulation_success': self._calculate_success_rate(intensity_reductions),
                'user_engagement_level': self._calculate_engagement_level(session_durations),
                'therapeutic_retention': self._calculate_retention_rate(),
            },
            'age_group_analysis': age_group_effectiveness,
            'theme_effectiveness': theme_effectiveness,
            'trends': self._analyze_therapeutic_trends(),
        }

    def _calculate_success_rate(self, intensity_reductions: List[float]) -> str:
        """Calculate therapeutic success rate"""
        if not intensity_reductions:
            return "insufficient_data"

        successful_sessions = sum(1 for r in intensity_reductions if r > 0)
        success_rate = successful_sessions / len(intensity_reductions)

        if success_rate >= 0.8:
            return "excellent"
        elif success_rate >= 0.6:
            return "good"
        elif success_rate >= 0.4:
            return "moderate"
        else:
            return "needs_improvement"

    def _calculate_engagement_level(self, durations: List[float]) -> str:
        """Calculate user engagement level"""
        if not durations:
            return "insufficient_data"

        avg_duration = statistics.mean(durations)

        if avg_duration >= 15:
            return "highly_engaged"
        elif avg_duration >= 10:
            return "moderately_engaged"
        elif avg_duration >= 5:
            return "somewhat_engaged"
        else:
            return "low_engagement"

    def _calculate_retention_rate(self) -> float:
        """Calculate therapeutic retention rate"""
        if not self.therapeutic_metrics:
            return 0.0

        # Users active in last 30 days
        thirty_days_ago = datetime.utcnow() - timedelta(days=30)
        active_users = 0

        for user_id, metrics in self.therapeutic_metrics.items():
            last_session = metrics.get('last_session_date')
            if last_session:
                last_session_dt = datetime.fromisoformat(last_session)
                if last_session_dt >= thirty_days_ago:
                    active_users += 1

        return active_users / len(self.therapeutic_metrics) if self.therapeutic_metrics else 0.0

    def _analyze_age_group_effectiveness(self) -> Dict[str, Any]:
        """Analyze therapeutic effectiveness by age group"""
        age_groups = defaultdict(list)

        for session in self.outcome_data:
            age_group = session.get('age_group', 'unknown')
            if session.get('intensity_before') and session.get('intensity_after'):
                reduction = session['intensity_before'] - session['intensity_after']
                age_groups[age_group].append(reduction)

        results = {}
        for age_group, reductions in age_groups.items():
            if reductions:
                avg_reduction = statistics.mean(reductions)
                success_rate = sum(1 for r in reductions if r > 0) / len(reductions)
                results[age_group] = {
                    'avg_intensity_reduction': round(avg_reduction, 2),
                    'success_rate': round(success_rate, 3),
                    'session_count': len(reductions)
                }

        return dict(results)

    def _analyze_theme_effectiveness(self) -> Dict[str, Any]:
        """Analyze therapeutic effectiveness by story theme"""
        themes = defaultdict(list)

        for session in self.outcome_data:
            theme = session.get('story_theme', 'unknown')
            if session.get('intensity_before') and session.get('intensity_after'):
                reduction = session['intensity_before'] - session['intensity_after']
                themes[theme].append(reduction)

        results = {}
        for theme, reductions in themes.items():
            if reductions:
                avg_reduction = statistics.mean(reductions)
                results[theme] = {
                    'avg_intensity_reduction': round(avg_reduction, 2),
                    'session_count': len(reductions),
                    'effectiveness_rank': 'high' if avg_reduction >= 2 else 'medium' if avg_reduction >= 1 else 'low'
                }

        return dict(results)

    def _analyze_therapeutic_trends(self) -> Dict[str, Any]:
        """Analyze therapeutic trends over time"""
        if len(self.outcome_data) < 10:
            return {'error': 'insufficient_data'}

        # Group by week
        weekly_stats = defaultdict(list)

        for session in self.outcome_data:
            session_date = datetime.fromisoformat(session['timestamp'])
            week_key = session_date.strftime('%Y-%W')

            if session.get('intensity_before') and session.get('intensity_after'):
                reduction = session['intensity_before'] - session['intensity_after']
                weekly_stats[week_key].append(reduction)

        # Calculate trends
        weeks = sorted(weekly_stats.keys())[-8:]  # Last 8 weeks
        weekly_avg_reductions = []

        for week in weeks:
            if weekly_stats[week]:
                avg_reduction = statistics.mean(weekly_stats[week])
                weekly_avg_reductions.append(avg_reduction)

        trend = 'stable'
        if len(weekly_avg_reductions) >= 3:
            recent_avg = statistics.mean(weekly_avg_reductions[-3:])
            earlier_avg = statistics.mean(weekly_avg_reductions[:-3])

            if recent_avg > earlier_avg * 1.1:
                trend = 'improving'
            elif recent_avg < earlier_avg * 0.9:
                trend = 'declining'

        return {
            'trend': trend,
            'recent_performance': round(recent_avg, 2) if 'recent_avg' in locals() else 0,
            'data_points': len(weekly_avg_reductions)
        }

    def generate_therapeutic_report(self, user_id: Optional[str] = None) -> Dict[str, Any]:
        """Generate comprehensive therapeutic outcome report"""
        if user_id:
            # Individual user report
            ei_score = self.calculate_emotional_intelligence_score(user_id)
            journey = self.emotional_journeys.get(user_id, [])

            return {
                'report_type': 'individual',
                'user_id': user_id,
                'emotional_intelligence': ei_score,
                'session_history': journey[-10:],  # Last 10 sessions
                'progress_metrics': self.therapeutic_metrics.get(user_id, {}),
                'recommendations': ei_score.get('recommendations', [])
            }
        else:
            # Aggregate report
            effectiveness = self.analyze_therapeutic_effectiveness()

            return {
                'report_type': 'aggregate',
                'generated_at': datetime.utcnow().isoformat(),
                'overall_effectiveness': effectiveness,
                'top_performing_themes': sorted(
                    effectiveness.get('theme_effectiveness', {}).items(),
                    key=lambda x: x[1]['avg_intensity_reduction'],
                    reverse=True
                )[:5],
                'age_group_insights': effectiveness.get('age_group_analysis', {}),
            }

def main():
    """Main therapeutic tracking execution"""
    try:
        tracker = TherapeuticOutcomeTracker()

        # Simulate therapeutic session data
        sample_sessions = [
            {
                'user_id': 'user_1',
                'type': 'story_therapy',
                'feeling_before': 'anxious',
                'feeling_after': 'calm',
                'intensity_before': 8,
                'intensity_after': 3,
                'coping_strategies': ['deep_breathing', 'positive_thinking'],
                'theme': 'friendship',
                'age_group': '8-12',
                'duration_minutes': 12,
                'goals': ['emotional_regulation', 'social_skills']
            },
            {
                'user_id': 'user_2',
                'type': 'story_therapy',
                'feeling_before': 'frustrated',
                'feeling_after': 'determined',
                'intensity_before': 7,
                'intensity_after': 4,
                'coping_strategies': ['problem_solving', 'encouragement'],
                'theme': 'overcoming_challenges',
                'age_group': '5-8',
                'duration_minutes': 15,
                'goals': ['resilience', 'problem_solving']
            },
            {
                'user_id': 'user_1',
                'type': 'story_therapy',
                'feeling_before': 'sad',
                'feeling_after': 'hopeful',
                'intensity_before': 6,
                'intensity_after': 2,
                'coping_strategies': ['gratitude', 'support_network'],
                'theme': 'family',
                'age_group': '8-12',
                'duration_minutes': 10,
                'goals': ['emotional_awareness', 'social_support']
            }
        ]

        # Track sessions
        for session in sample_sessions:
            tracker.track_therapeutic_session(session['user_id'], session)

        # Generate reports
        print("=== Therapeutic Outcome Tracking Report ===")

        # Individual user report
        user_report = tracker.generate_therapeutic_report('user_1')
        print(f"\nUser Emotional Intelligence Score: {user_report['emotional_intelligence']['overall_score']}/100")
        print(f"Assessment: {user_report['emotional_intelligence']['assessment']}")

        # Aggregate effectiveness report
        effectiveness = tracker.analyze_therapeutic_effectiveness()
        summary = effectiveness['summary']
        print(f"\nTherapeutic Effectiveness Summary:")
        print(f"  Total Sessions: {summary['total_sessions']}")
        print(f"  Unique Users: {summary['unique_users']}")
        print(".2f")
        print(".1f")
        print(f"  Sessions per User: {summary['summary']['sessions_per_user']}")

        metrics = effectiveness['effectiveness_metrics']
        print(f"  Emotional Regulation Success: {metrics['emotional_regulation_success']}")
        print(f"  User Engagement Level: {metrics['user_engagement_level']}")
        print(".1%")

        # Theme effectiveness
        themes = effectiveness.get('theme_effectiveness', {})
        if themes:
            top_theme = max(themes.items(), key=lambda x: x[1]['avg_intensity_reduction'])
            print(f"  Top Performing Theme: {top_theme[0]} "
                  f"(avg reduction: {top_theme[1]['avg_intensity_reduction']})")

        return 0

    except Exception as e:
        logger.error(f"Therapeutic tracking failed: {e}")
        return 1

if __name__ == "__main__":
    exit(main())