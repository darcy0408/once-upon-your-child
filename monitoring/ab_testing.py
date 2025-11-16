#!/usr/bin/env python3
"""
A/B Testing Framework for Story Weaver
Content performance testing and optimization
"""

import os
import json
import logging
import random
import hashlib
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

class ABTestingFramework:
    def __init__(self):
        self.experiments = {}
        self.experiment_results = defaultdict(dict)
        self.user_assignments = defaultdict(dict)  # user_id -> experiment -> variant

        # Statistical significance thresholds
        self.confidence_threshold = 0.95  # 95% confidence
        self.minimum_sample_size = 100  # Minimum samples per variant

    def create_experiment(self, experiment_id: str, name: str, variants: Dict[str, Any],
                         target_metric: str, hypothesis: str = "") -> bool:
        """Create a new A/B test experiment"""
        if experiment_id in self.experiments:
            logger.warning(f"Experiment {experiment_id} already exists")
            return False

        if len(variants) < 2:
            logger.error("Experiment must have at least 2 variants")
            return False

        experiment = {
            'id': experiment_id,
            'name': name,
            'variants': variants,
            'target_metric': target_metric,
            'hypothesis': hypothesis,
            'created_at': datetime.utcnow().isoformat(),
            'status': 'active',
            'variant_weights': self._calculate_variant_weights(variants),
            'total_assignments': 0,
            'variant_assignments': {variant_id: 0 for variant_id in variants.keys()}
        }

        self.experiments[experiment_id] = experiment
        logger.info(f"Created experiment {experiment_id} with {len(variants)} variants")
        return True

    def _calculate_variant_weights(self, variants: Dict[str, Any]) -> Dict[str, float]:
        """Calculate traffic distribution weights for variants"""
        # Default to equal distribution, but allow custom weights
        total_weight = 0
        weights = {}

        for variant_id, variant_config in variants.items():
            weight = variant_config.get('weight', 1.0)
            weights[variant_id] = weight
            total_weight += weight

        # Normalize weights
        return {vid: weight/total_weight for vid, weight in weights.items()}

    def assign_user_to_variant(self, user_id: str, experiment_id: str) -> Optional[str]:
        """Assign a user to a variant using consistent hashing"""
        if experiment_id not in self.experiments:
            logger.warning(f"Experiment {experiment_id} not found")
            return None

        experiment = self.experiments[experiment_id]
        if experiment['status'] != 'active':
            return None

        # Check if user already assigned
        if user_id in self.user_assignments and experiment_id in self.user_assignments[user_id]:
            return self.user_assignments[user_id][experiment_id]

        # Use consistent hashing for variant assignment
        hash_input = f"{user_id}:{experiment_id}".encode('utf-8')
        hash_value = int(hashlib.md5(hash_input).hexdigest(), 16) / (2**128 - 1)

        # Assign based on cumulative weights
        cumulative_weight = 0.0
        for variant_id, weight in experiment['variant_weights'].items():
            cumulative_weight += weight
            if hash_value <= cumulative_weight:
                # Record assignment
                if user_id not in self.user_assignments:
                    self.user_assignments[user_id] = {}
                self.user_assignments[user_id][experiment_id] = variant_id

                experiment['total_assignments'] += 1
                experiment['variant_assignments'][variant_id] += 1

                return variant_id

        # Fallback (should not reach here)
        return list(experiment['variants'].keys())[0]

    def track_metric(self, user_id: str, experiment_id: str, metric_name: str, value: float):
        """Track a metric value for a user in an experiment"""
        if experiment_id not in self.experiments:
            return

        variant = self.user_assignments.get(user_id, {}).get(experiment_id)
        if not variant:
            return

        if experiment_id not in self.experiment_results:
            self.experiment_results[experiment_id] = {}

        if variant not in self.experiment_results[experiment_id]:
            self.experiment_results[experiment_id][variant] = defaultdict(list)

        self.experiment_results[experiment_id][variant][metric_name].append({
            'user_id': user_id,
            'value': value,
            'timestamp': datetime.utcnow().isoformat()
        })

    def get_experiment_results(self, experiment_id: str) -> Dict[str, Any]:
        """Get comprehensive results for an experiment"""
        if experiment_id not in self.experiments:
            return {'error': 'Experiment not found'}

        experiment = self.experiments[experiment_id]
        results = self.experiment_results.get(experiment_id, {})

        analysis = {
            'experiment_id': experiment_id,
            'experiment_name': experiment['name'],
            'status': experiment['status'],
            'target_metric': experiment['target_metric'],
            'total_assignments': experiment['total_assignments'],
            'variant_performance': {},
            'statistical_significance': {},
            'recommendations': []
        }

        # Analyze each variant
        target_metric = experiment['target_metric']
        variant_metrics = {}

        for variant_id, variant_data in results.items():
            if target_metric in variant_data:
                values = [entry['value'] for entry in variant_data[target_metric]]
                variant_metrics[variant_id] = {
                    'sample_size': len(values),
                    'mean': statistics.mean(values) if values else 0,
                    'median': statistics.median(values) if values else 0,
                    'std_dev': statistics.stdev(values) if len(values) > 1 else 0,
                    'min': min(values) if values else 0,
                    'max': max(values) if values else 0
                }

        analysis['variant_performance'] = variant_metrics

        # Statistical significance testing
        if len(variant_metrics) >= 2 and all(v['sample_size'] >= self.minimum_sample_size for v in variant_metrics.values()):
            analysis['statistical_significance'] = self._calculate_statistical_significance(
                variant_metrics, target_metric
            )

        # Generate recommendations
        analysis['recommendations'] = self._generate_experiment_recommendations(
            experiment, variant_metrics
        )

        return analysis

    def _calculate_statistical_significance(self, variant_metrics: Dict[str, Dict[str, Any]],
                                         target_metric: str) -> Dict[str, Any]:
        """Calculate statistical significance between variants"""
        significance_results = {}

        variants = list(variant_metrics.keys())
        if len(variants) < 2:
            return significance_results

        # Simple t-test approximation (in production, use scipy.stats)
        for i in range(len(variants)):
            for j in range(i+1, len(variants)):
                variant_a = variants[i]
                variant_b = variants[j]

                data_a = variant_metrics[variant_a]
                data_b = variant_metrics[variant_b]

                # Calculate Cohen's d effect size
                mean_diff = data_a['mean'] - data_b['mean']
                pooled_std = ((data_a['std_dev'] ** 2 + data_b['std_dev'] ** 2) / 2) ** 0.5

                if pooled_std > 0:
                    effect_size = abs(mean_diff) / pooled_std
                else:
                    effect_size = 0

                # Determine significance level (simplified)
                confidence_level = 'high' if effect_size > 0.8 else 'medium' if effect_size > 0.5 else 'low'

                significance_results[f"{variant_a}_vs_{variant_b}"] = {
                    'effect_size': effect_size,
                    'confidence_level': confidence_level,
                    'winner': variant_a if data_a['mean'] > data_b['mean'] else variant_b,
                    'improvement': f"{abs(mean_diff/data_b['mean']*100):.1f}%" if data_b['mean'] != 0 else "N/A"
                }

        return significance_results

    def _generate_experiment_recommendations(self, experiment: Dict[str, Any],
                                           variant_metrics: Dict[str, Dict[str, Any]]) -> List[str]:
        """Generate recommendations based on experiment results"""
        recommendations = []

        # Check sample sizes
        small_samples = [vid for vid, metrics in variant_metrics.items()
                        if metrics['sample_size'] < self.minimum_sample_size]
        if small_samples:
            recommendations.append(f"Continue experiment - variants {', '.join(small_samples)} need more data")

        # Check for clear winners
        if len(variant_metrics) >= 2:
            sorted_variants = sorted(variant_metrics.items(),
                                   key=lambda x: x[1]['mean'], reverse=True)
            best_variant = sorted_variants[0][0]
            best_mean = sorted_variants[0][1]['mean']
            second_best_mean = sorted_variants[1][1]['mean'] if len(sorted_variants) > 1 else 0

            if best_mean > second_best_mean * 1.1:  # 10% improvement
                recommendations.append(f"Strong recommendation: Deploy variant '{best_variant}' - shows {((best_mean/second_best_mean-1)*100):.1f}% improvement")

        # Check experiment duration
        created_at = datetime.fromisoformat(experiment['created_at'])
        duration_days = (datetime.utcnow() - created_at).days

        if duration_days < 7:
            recommendations.append("Experiment running for less than a week - allow more time for conclusive results")
        elif duration_days > 30:
            recommendations.append("Experiment has been running for over 30 days - consider concluding and implementing winner")

        return recommendations

    def stop_experiment(self, experiment_id: str) -> bool:
        """Stop an experiment and finalize results"""
        if experiment_id not in self.experiments:
            return False

        self.experiments[experiment_id]['status'] = 'completed'
        self.experiments[experiment_id]['completed_at'] = datetime.utcnow().isoformat()

        logger.info(f"Stopped experiment {experiment_id}")
        return True

    def get_active_experiments(self) -> List[Dict[str, Any]]:
        """Get all active experiments"""
        return [exp for exp in self.experiments.values() if exp['status'] == 'active']

    def get_experiment_summary(self) -> Dict[str, Any]:
        """Get summary of all experiments"""
        active_experiments = len([e for e in self.experiments.values() if e['status'] == 'active'])
        completed_experiments = len([e for e in self.experiments.values() if e['status'] == 'completed'])

        total_assignments = sum(exp['total_assignments'] for exp in self.experiments.values())

        return {
            'total_experiments': len(self.experiments),
            'active_experiments': active_experiments,
            'completed_experiments': completed_experiments,
            'total_user_assignments': total_assignments,
            'experiments': list(self.experiments.keys())
        }

class ContentPerformanceTester:
    def __init__(self, ab_framework: ABTestingFramework):
        self.ab_framework = ab_framework
        self.content_experiments = {}

    def create_story_theme_experiment(self, theme_a: str, theme_b: str,
                                    target_age_group: str = "all") -> str:
        """Create A/B test for story themes"""
        experiment_id = f"theme_test_{theme_a.lower().replace(' ', '_')}_vs_{theme_b.lower().replace(' ', '_')}"

        variants = {
            'variant_a': {
                'theme': theme_a,
                'description': f"Stories with {theme_a} theme",
                'weight': 0.5
            },
            'variant_b': {
                'theme': theme_b,
                'description': f"Stories with {theme_b} theme",
                'weight': 0.5
            }
        }

        success = self.ab_framework.create_experiment(
            experiment_id=experiment_id,
            name=f"Story Theme Comparison: {theme_a} vs {theme_b}",
            variants=variants,
            target_metric='user_engagement_score',
            hypothesis=f"Stories with {theme_a} theme will have higher user engagement than {theme_b}"
        )

        if success:
            self.content_experiments[experiment_id] = {
                'type': 'story_theme',
                'target_age_group': target_age_group,
                'variants': variants
            }

        return experiment_id if success else ""

    def create_feature_experiment(self, feature_name: str, control_description: str,
                                variant_description: str) -> str:
        """Create A/B test for feature variations"""
        experiment_id = f"feature_test_{feature_name.lower().replace(' ', '_')}"

        variants = {
            'control': {
                'feature_enabled': False,
                'description': control_description,
                'weight': 0.5
            },
            'variant': {
                'feature_enabled': True,
                'description': variant_description,
                'weight': 0.5
            }
        }

        success = self.ab_framework.create_experiment(
            experiment_id=experiment_id,
            name=f"Feature Test: {feature_name}",
            variants=variants,
            target_metric='feature_usage_rate',
            hypothesis=f"Enabling {feature_name} will improve user engagement"
        )

        if success:
            self.content_experiments[experiment_id] = {
                'type': 'feature_test',
                'feature_name': feature_name,
                'variants': variants
            }

        return experiment_id if success else ""

    def get_content_performance_report(self) -> Dict[str, Any]:
        """Generate comprehensive content performance report"""
        report = {
            'timestamp': datetime.utcnow().isoformat(),
            'active_experiments': len(self.content_experiments),
            'experiment_results': {},
            'top_performing_themes': [],
            'content_recommendations': []
        }

        # Get results for all content experiments
        for experiment_id in self.content_experiments.keys():
            results = self.ab_framework.get_experiment_results(experiment_id)
            if 'error' not in results:
                report['experiment_results'][experiment_id] = results

        # Analyze theme performance across experiments
        theme_performance = self._analyze_theme_performance(report['experiment_results'])
        report['top_performing_themes'] = theme_performance

        # Generate content recommendations
        report['content_recommendations'] = self._generate_content_recommendations(theme_performance)

        return report

    def _analyze_theme_performance(self, experiment_results: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Analyze which story themes perform best"""
        theme_scores = defaultdict(list)

        for exp_id, results in experiment_results.items():
            if exp_id in self.content_experiments and self.content_experiments[exp_id]['type'] == 'story_theme':
                exp_config = self.content_experiments[exp_id]

                for variant_id, performance in results.get('variant_performance', {}).items():
                    theme = exp_config['variants'][variant_id]['theme']
                    score = performance.get('mean', 0)
                    theme_scores[theme].append(score)

        # Calculate average scores
        theme_averages = []
        for theme, scores in theme_scores.items():
            if scores:
                avg_score = statistics.mean(scores)
                theme_averages.append({
                    'theme': theme,
                    'average_score': avg_score,
                    'experiment_count': len(scores)
                })

        # Sort by performance
        theme_averages.sort(key=lambda x: x['average_score'], reverse=True)
        return theme_averages

    def _generate_content_recommendations(self, theme_performance: List[Dict[str, Any]]) -> List[str]:
        """Generate content optimization recommendations"""
        recommendations = []

        if theme_performance:
            top_theme = theme_performance[0]['theme']
            recommendations.append(f"Prioritize content creation around '{top_theme}' theme - shows highest engagement")

            if len(theme_performance) > 1:
                bottom_theme = theme_performance[-1]['theme']
                recommendations.append(f"Consider reducing focus on '{bottom_theme}' theme - lower engagement scores")

        # General recommendations
        recommendations.extend([
            "Run A/B tests on new story themes before full rollout",
            "Monitor engagement metrics for seasonal theme variations",
            "Consider user age groups when selecting story themes",
            "Use A/B testing results to inform content strategy"
        ])

        return recommendations

def main():
    """Main A/B testing execution"""
    try:
        # Initialize framework
        ab_framework = ABTestingFramework()
        content_tester = ContentPerformanceTester(ab_framework)

        # Create sample experiments
        theme_exp = content_tester.create_story_theme_experiment(
            "Adventure in the Forest", "Space Exploration"
        )

        feature_exp = content_tester.create_feature_experiment(
            "Interactive Stories",
            "Standard linear stories",
            "Branching interactive storylines"
        )

        # Simulate user assignments and tracking
        users = [f'user_{i}' for i in range(1, 201)]  # 200 users

        for user in users:
            # Assign to theme experiment
            theme_variant = ab_framework.assign_user_to_variant(user, theme_exp)

            # Simulate engagement scores
            base_score = 70 + random.uniform(-20, 20)
            if theme_variant == 'variant_a':
                base_score += random.uniform(-5, 10)  # Theme A might perform slightly better
            else:
                base_score += random.uniform(-10, 5)

            ab_framework.track_metric(user, theme_exp, 'user_engagement_score', base_score)

            # Assign to feature experiment
            feature_variant = ab_framework.assign_user_to_variant(user, feature_exp)

            # Simulate feature usage
            usage_rate = 0.6 + random.uniform(-0.3, 0.3)
            if feature_variant == 'variant':
                usage_rate += random.uniform(-0.1, 0.2)  # Interactive feature might have different usage

            ab_framework.track_metric(user, feature_exp, 'feature_usage_rate', usage_rate)

        # Get results
        theme_results = ab_framework.get_experiment_results(theme_exp)
        feature_results = ab_framework.get_experiment_results(feature_exp)

        print("=== A/B Testing Results ===")

        print(f"\nTheme Experiment: {theme_results.get('experiment_name', 'N/A')}")
        print(f"Total Assignments: {theme_results.get('total_assignments', 0)}")

        for variant, performance in theme_results.get('variant_performance', {}).items():
            theme_name = content_tester.content_experiments[theme_exp]['variants'][variant]['theme']
            print(f"  {theme_name}: {performance['sample_size']} users, "
                  f"avg score {performance['mean']:.1f}")

        print(f"\nFeature Experiment: {feature_results.get('experiment_name', 'N/A')}")
        print(f"Total Assignments: {feature_results.get('total_assignments', 0)}")

        for variant, performance in feature_results.get('variant_performance', {}).items():
            desc = content_tester.content_experiments[feature_exp]['variants'][variant]['description']
            print(f"  {desc}: {performance['sample_size']} users, "
                  f"usage rate {performance['mean']:.2%}")

        # Content performance report
        content_report = content_tester.get_content_performance_report()
        print(f"\nContent Performance:")
        print(f"Active Experiments: {content_report['active_experiments']}")

        if content_report['top_performing_themes']:
            top_theme = content_report['top_performing_themes'][0]
            print(f"Top Performing Theme: {top_theme['theme']} "
                  f"(avg score: {top_theme['average_score']:.1f})")

        print(f"\nRecommendations:")
        for rec in content_report['content_recommendations'][:3]:
            print(f"  • {rec}")

        return 0

    except Exception as e:
        logger.error(f"A/B testing failed: {e}")
        return 1

if __name__ == "__main__":
    exit(main())