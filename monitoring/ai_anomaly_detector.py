#!/usr/bin/env python3
"""
AI-Powered Anomaly Detection for Story Weaver
Intelligent alerting with contextual analysis and root cause identification
"""

import os
import json
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Tuple
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import DBSCAN
import joblib
import requests

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class AIAnomalyDetector:
    def __init__(self):
        self.isolation_forest = None
        self.scaler = None
        self.cluster_model = None
        self.model_path = "/models/anomaly_model.pkl"
        self.scaler_path = "/models/anomaly_scaler.pkl"
        self.cluster_path = "/models/cluster_model.pkl"
        self.metrics_history = []
        self.anomalies_history = []

        # Alert thresholds
        self.anomaly_score_threshold = -0.5  # Isolation Forest threshold
        self.min_samples_for_pattern = 10

        # Slack/webhook configuration
        self.slack_webhook = os.getenv("SLACK_WEBHOOK_URL")
        self.alert_cooldown = 300  # 5 minutes between similar alerts

    def collect_metrics(self) -> Dict[str, Any]:
        """Collect comprehensive system metrics"""
        try:
            current_time = datetime.utcnow()

            # Simulate comprehensive metrics collection
            # In production, this would query Prometheus, logs, etc.
            metrics = {
                'timestamp': current_time.isoformat(),
                'cpu_usage': 45.0 + np.random.normal(0, 5),
                'memory_usage': 60.0 + np.random.normal(0, 8),
                'disk_usage': 25.0 + np.random.normal(0, 3),
                'network_in': 1500000 + np.random.normal(0, 100000),
                'network_out': 2000000 + np.random.normal(0, 150000),
                'request_rate': 120 + np.random.normal(0, 15),
                'error_rate': 0.02 + np.random.normal(0, 0.01),
                'response_time_p50': 180 + np.random.normal(0, 20),
                'response_time_p95': 450 + np.random.normal(0, 50),
                'response_time_p99': 1200 + np.random.normal(0, 100),
                'active_connections': 85 + np.random.normal(0, 10),
                'database_connections': 12 + np.random.normal(0, 2),
                'cache_hit_rate': 0.85 + np.random.normal(0, 0.05),
                'story_generation_time': 8.5 + np.random.normal(0, 1.5),
                'api_latency': 120 + np.random.normal(0, 15),
                'hour_of_day': current_time.hour,
                'day_of_week': current_time.weekday(),
                'is_business_hours': 1 if 9 <= current_time.hour <= 17 else 0,
            }

            # Ensure values are within reasonable bounds
            for key, value in metrics.items():
                if isinstance(value, (int, float)) and key != 'timestamp':
                    if 'rate' in key or 'usage' in key:
                        metrics[key] = max(0, min(100 if 'usage' in key else 1000000, value))
                    elif 'time' in key or 'latency' in key:
                        metrics[key] = max(0, value)

            self.metrics_history.append(metrics)
            if len(self.metrics_history) > 2000:  # Keep last 2000 data points
                self.metrics_history = self.metrics_history[-2000:]

            return metrics

        except Exception as e:
            logger.error(f"Metrics collection failed: {e}")
            return {}

    def train_anomaly_model(self):
        """Train AI models for anomaly detection"""
        if len(self.metrics_history) < 100:
            logger.info("Not enough data for training, need at least 100 samples")
            return

        try:
            # Prepare data for training
            df = pd.DataFrame(self.metrics_history)

            # Select features for anomaly detection (exclude timestamps and categorical)
            feature_columns = [
                'cpu_usage', 'memory_usage', 'disk_usage', 'network_in', 'network_out',
                'request_rate', 'error_rate', 'response_time_p50', 'response_time_p95',
                'response_time_p99', 'active_connections', 'database_connections',
                'cache_hit_rate', 'story_generation_time', 'api_latency'
            ]

            X = df[feature_columns].fillna(method='ffill').fillna(0)

            # Scale features
            self.scaler = StandardScaler()
            X_scaled = self.scaler.fit_transform(X)

            # Train Isolation Forest for anomaly detection
            self.isolation_forest = IsolationForest(
                n_estimators=100,
                contamination=0.1,  # Expect 10% anomalies
                random_state=42,
                n_jobs=-1
            )
            self.isolation_forest.fit(X_scaled)

            # Train clustering model for pattern recognition
            self.cluster_model = DBSCAN(
                eps=0.5,
                min_samples=self.min_samples_for_pattern,
                n_jobs=-1
            )
            clusters = self.cluster_model.fit_predict(X_scaled)

            # Save models
            os.makedirs(os.path.dirname(self.model_path), exist_ok=True)
            joblib.dump(self.isolation_forest, self.model_path)
            joblib.dump(self.scaler, self.scaler_path)
            joblib.dump(self.cluster_model, self.cluster_path)

            logger.info(f"AI anomaly detection models trained on {len(X)} samples")

        except Exception as e:
            logger.error(f"Model training failed: {e}")

    def detect_anomalies(self, metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Detect anomalies in current metrics"""
        if not self.isolation_forest or not self.scaler:
            # Load existing models
            try:
                self.isolation_forest = joblib.load(self.model_path)
                self.scaler = joblib.load(self.scaler_path)
                self.cluster_model = joblib.load(self.cluster_path)
            except:
                logger.warning("No trained models available, using rule-based detection")
                return self._rule_based_anomaly_detection(metrics)

        try:
            # Prepare input data
            feature_columns = [
                'cpu_usage', 'memory_usage', 'disk_usage', 'network_in', 'network_out',
                'request_rate', 'error_rate', 'response_time_p50', 'response_time_p95',
                'response_time_p99', 'active_connections', 'database_connections',
                'cache_hit_rate', 'story_generation_time', 'api_latency'
            ]

            input_data = []
            for col in feature_columns:
                input_data.append(metrics.get(col, 0))

            input_df = pd.DataFrame([input_data], columns=feature_columns)
            input_scaled = self.scaler.transform(input_df)

            # Get anomaly score
            anomaly_score = self.isolation_forest.decision_function(input_scaled)[0]
            is_anomaly = anomaly_score < self.anomaly_score_threshold

            anomalies = []

            if is_anomaly:
                # Identify which metrics are anomalous
                anomalous_metrics = self._identify_anomalous_metrics(metrics, anomaly_score)

                for metric_info in anomalous_metrics:
                    anomaly = {
                        'timestamp': metrics['timestamp'],
                        'metric': metric_info['metric'],
                        'value': metric_info['value'],
                        'expected_range': metric_info['expected_range'],
                        'deviation': metric_info['deviation'],
                        'severity': metric_info['severity'],
                        'anomaly_score': anomaly_score,
                        'context': self._generate_context(metrics, metric_info),
                        'recommended_actions': self._generate_recommendations(metric_info),
                        'root_cause_hypothesis': self._analyze_root_cause(metrics, metric_info),
                    }
                    anomalies.append(anomaly)

            # Store anomalies for pattern analysis
            self.anomalies_history.extend(anomalies)
            if len(self.anomalies_history) > 500:
                self.anomalies_history = self.anomalies_history[-500:]

            return anomalies

        except Exception as e:
            logger.error(f"Anomaly detection failed: {e}")
            return self._rule_based_anomaly_detection(metrics)

    def _rule_based_anomaly_detection(self, metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Fallback rule-based anomaly detection"""
        anomalies = []

        # Simple threshold-based rules
        rules = {
            'cpu_usage': {'threshold': 85, 'severity': 'high'},
            'memory_usage': {'threshold': 90, 'severity': 'high'},
            'error_rate': {'threshold': 0.05, 'severity': 'critical'},
            'response_time_p95': {'threshold': 1000, 'severity': 'medium'},
            'response_time_p99': {'threshold': 2000, 'severity': 'high'},
        }

        for metric, config in rules.items():
            value = metrics.get(metric, 0)
            if value > config['threshold']:
                anomalies.append({
                    'timestamp': metrics['timestamp'],
                    'metric': metric,
                    'value': value,
                    'expected_range': f"< {config['threshold']}",
                    'deviation': f"{((value - config['threshold']) / config['threshold'] * 100):.1f}% above threshold",
                    'severity': config['severity'],
                    'anomaly_score': -0.8,  # Simulated score
                    'context': f"Basic threshold exceeded for {metric}",
                    'recommended_actions': [f"Investigate high {metric.replace('_', ' ')}"],
                    'root_cause_hypothesis': f"Potential resource constraint or traffic spike affecting {metric}",
                })

        return anomalies

    def _identify_anomalous_metrics(self, metrics: Dict[str, Any], anomaly_score: float) -> List[Dict[str, Any]]:
        """Identify which specific metrics are contributing to the anomaly"""
        anomalous_metrics = []

        # Calculate z-scores for each metric based on recent history
        if len(self.metrics_history) >= 20:
            recent_metrics = self.metrics_history[-20:]
            df_recent = pd.DataFrame(recent_metrics)

            for metric in ['cpu_usage', 'memory_usage', 'response_time_p95', 'error_rate', 'request_rate']:
                if metric in df_recent.columns:
                    values = df_recent[metric].dropna()
                    if len(values) > 0:
                        mean_val = values.mean()
                        std_val = values.std()

                        if std_val > 0:
                            current_val = metrics.get(metric, mean_val)
                            z_score = (current_val - mean_val) / std_val

                            if abs(z_score) > 2:  # More than 2 standard deviations
                                severity = 'critical' if abs(z_score) > 3 else 'high' if abs(z_score) > 2.5 else 'medium'

                                anomalous_metrics.append({
                                    'metric': metric,
                                    'value': current_val,
                                    'expected_range': f"{mean_val - std_val:.1f} - {mean_val + std_val:.1f}",
                                    'deviation': f"{z_score:.1f}σ from mean",
                                    'severity': severity,
                                })

        return anomalous_metrics

    def _generate_context(self, metrics: Dict[str, Any], metric_info: Dict[str, Any]) -> str:
        """Generate contextual information about the anomaly"""
        metric = metric_info['metric']
        context_parts = []

        # Time-based context
        hour = metrics.get('hour_of_day', 0)
        if hour < 6:
            context_parts.append("during early morning hours")
        elif hour < 12:
            context_parts.append("during morning hours")
        elif hour < 18:
            context_parts.append("during business hours")
        else:
            context_parts.append("during evening hours")

        # Load context
        request_rate = metrics.get('request_rate', 0)
        if request_rate > 200:
            context_parts.append("under high traffic load")
        elif request_rate > 100:
            context_parts.append("under moderate traffic load")
        else:
            context_parts.append("under normal traffic load")

        # Related metrics context
        if metric == 'response_time_p95' and metrics.get('cpu_usage', 0) > 80:
            context_parts.append("potentially related to high CPU usage")
        elif metric == 'error_rate' and metrics.get('memory_usage', 0) > 85:
            context_parts.append("potentially related to high memory usage")

        return "Anomaly detected " + " and ".join(context_parts)

    def _generate_recommendations(self, metric_info: Dict[str, Any]) -> List[str]:
        """Generate actionable recommendations for the anomaly"""
        metric = metric_info['metric']
        severity = metric_info['severity']

        recommendations = []

        if metric == 'cpu_usage':
            recommendations.extend([
                "Check for CPU-intensive processes or queries",
                "Consider scaling up instance size temporarily",
                "Review database query performance",
                "Check for memory leaks in application code"
            ])
        elif metric == 'memory_usage':
            recommendations.extend([
                "Monitor for memory leaks in application",
                "Check database connection pool usage",
                "Review cache memory consumption",
                "Consider increasing instance memory"
            ])
        elif 'response_time' in metric:
            recommendations.extend([
                "Check database query performance",
                "Review API endpoint optimization",
                "Monitor external service dependencies",
                "Check for N+1 query problems"
            ])
        elif metric == 'error_rate':
            recommendations.extend([
                "Check application logs for error patterns",
                "Review recent code deployments",
                "Monitor external API dependencies",
                "Check database connectivity issues"
            ])

        if severity == 'critical':
            recommendations.insert(0, "URGENT: Immediate investigation required")
        elif severity == 'high':
            recommendations.insert(0, "HIGH PRIORITY: Investigate within 30 minutes")

        return recommendations

    def _analyze_root_cause(self, metrics: Dict[str, Any], metric_info: Dict[str, Any]) -> str:
        """Analyze potential root causes for the anomaly"""
        metric = metric_info['metric']

        hypotheses = []

        # Correlate with other metrics
        if metric == 'response_time_p95':
            if metrics.get('cpu_usage', 0) > 80:
                hypotheses.append("High CPU usage causing request queuing")
            if metrics.get('database_connections', 0) > 15:
                hypotheses.append("Database connection pool exhaustion")
            if metrics.get('cache_hit_rate', 1) < 0.7:
                hypotheses.append("Low cache hit rate causing increased database load")

        elif metric == 'error_rate':
            if metrics.get('memory_usage', 0) > 90:
                hypotheses.append("Memory pressure causing application crashes")
            if metrics.get('network_out', 0) > 3000000:
                hypotheses.append("High network traffic causing timeouts")

        elif metric == 'cpu_usage':
            if metrics.get('request_rate', 0) > 200:
                hypotheses.append("High request volume overwhelming CPU")
            if metrics.get('story_generation_time', 0) > 15:
                hypotheses.append("Slow AI processing consuming CPU resources")

        if not hypotheses:
            hypotheses.append("Unknown root cause - requires manual investigation")

        return "; ".join(hypotheses)

    def send_alert(self, anomaly: Dict[str, Any]):
        """Send intelligent alert with context and recommendations"""
        if not self.slack_webhook:
            logger.warning("No Slack webhook configured, skipping alert")
            return

        # Check cooldown to avoid alert spam
        current_time = time.time()
        if hasattr(self, '_last_alert_time'):
            if current_time - self._last_alert_time < self.alert_cooldown:
                logger.info("Alert cooldown active, skipping alert")
                return

        try:
            severity_emoji = {
                'critical': '🚨',
                'high': '⚠️',
                'medium': 'ℹ️',
                'low': '📊'
            }

            emoji = severity_emoji.get(anomaly['severity'], '❓')

            message = {
                "text": f"{emoji} *{anomaly['severity'].upper()}* Anomaly Detected",
                "blocks": [
                    {
                        "type": "header",
                        "text": {
                            "type": "plain_text",
                            "text": f"{emoji} {anomaly['severity'].upper()} Anomaly: {anomaly['metric']}"
                        }
                    },
                    {
                        "type": "section",
                        "fields": [
                            {
                                "type": "mrkdwn",
                                "text": f"*Metric:* {anomaly['metric'].replace('_', ' ').title()}"
                            },
                            {
                                "type": "mrkdwn",
                                "text": f"*Value:* {anomaly['value']:.2f}"
                            },
                            {
                                "type": "mrkdwn",
                                "text": f"*Expected:* {anomaly['expected_range']}"
                            },
                            {
                                "type": "mrkdwn",
                                "text": f"*Deviation:* {anomaly['deviation']}"
                            }
                        ]
                    },
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"*Context:* {anomaly['context']}"
                        }
                    },
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"*Root Cause Hypothesis:* {anomaly['root_cause_hypothesis']}"
                        }
                    },
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"*Recommended Actions:*\n" + "\n".join(f"• {action}" for action in anomaly['recommended_actions'])
                        }
                    }
                ]
            }

            response = requests.post(self.slack_webhook, json=message)
            response.raise_for_status()

            self._last_alert_time = current_time
            logger.info(f"Alert sent for {anomaly['metric']} anomaly")

        except Exception as e:
            logger.error(f"Failed to send alert: {e}")

    def get_anomaly_report(self) -> Dict[str, Any]:
        """Generate comprehensive anomaly detection report"""
        recent_anomalies = self.anomalies_history[-10:] if self.anomalies_history else []

        # Analyze patterns
        severity_counts = {}
        metric_counts = {}

        for anomaly in recent_anomalies:
            severity = anomaly.get('severity', 'unknown')
            metric = anomaly.get('metric', 'unknown')

            severity_counts[severity] = severity_counts.get(severity, 0) + 1
            metric_counts[metric] = metric_counts.get(metric, 0) + 1

        return {
            'timestamp': datetime.utcnow().isoformat(),
            'model_status': 'trained' if self.isolation_forest else 'untrained',
            'data_points': len(self.metrics_history),
            'recent_anomalies_count': len(recent_anomalies),
            'severity_distribution': severity_counts,
            'metric_distribution': metric_counts,
            'recent_anomalies': recent_anomalies,
            'anomaly_patterns': self._analyze_patterns(),
        }

    def _analyze_patterns(self) -> List[Dict[str, Any]]:
        """Analyze patterns in anomaly data"""
        if len(self.anomalies_history) < 5:
            return []

        patterns = []

        # Group anomalies by metric and time
        metric_groups = {}
        for anomaly in self.anomalies_history[-50:]:  # Last 50 anomalies
            metric = anomaly.get('metric')
            if metric:
                if metric not in metric_groups:
                    metric_groups[metric] = []
                metric_groups[metric].append(anomaly)

        # Find recurring patterns
        for metric, anomalies in metric_groups.items():
            if len(anomalies) >= 3:
                # Check if anomalies occur at similar times
                hours = [datetime.fromisoformat(a['timestamp']).hour for a in anomalies]
                if len(set(hours)) <= 2:  # Same or adjacent hours
                    patterns.append({
                        'pattern_type': 'time_based',
                        'metric': metric,
                        'description': f"Recurring {metric} anomalies around hour {max(set(hours), key=hours.count)}",
                        'frequency': len(anomalies),
                        'recommendation': f"Schedule maintenance or scaling during off-peak hours"
                    })

        return patterns

def main():
    """Main AI anomaly detection execution"""
    try:
        detector = AIAnomalyDetector()

        # Collect current metrics
        metrics = detector.collect_metrics()
        if not metrics:
            logger.error("Failed to collect metrics")
            return 1

        # Train model periodically
        if len(detector.metrics_history) >= 100 and len(detector.metrics_history) % 200 == 0:
            detector.train_anomaly_model()

        # Detect anomalies
        anomalies = detector.detect_anomalies(metrics)

        if anomalies:
            logger.info(f"Detected {len(anomalies)} anomalies")
            for anomaly in anomalies:
                logger.warning(f"Anomaly: {anomaly['metric']} - {anomaly['severity']} severity")
                detector.send_alert(anomaly)
        else:
            logger.info("No anomalies detected")

        # Generate report
        report = detector.get_anomaly_report()
        print("=== AI Anomaly Detection Report ===")
        print(f"Model Status: {report['model_status']}")
        print(f"Data Points: {report['data_points']}")
        print(f"Recent Anomalies: {report['recent_anomalies_count']}")
        print(f"Patterns Found: {len(report['anomaly_patterns'])}")

        return 0

    except Exception as e:
        logger.error(f"AI anomaly detection failed: {e}")
        return 1

if __name__ == "__main__":
    exit(main())