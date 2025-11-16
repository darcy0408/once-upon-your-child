#!/usr/bin/env python3
"""
AI-Powered Predictive Scaling for Story Weaver
ML-based traffic prediction and automated resource scaling
"""

import os
import json
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Tuple
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
import joblib
import requests

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class PredictiveScaler:
    def __init__(self):
        self.model = None
        self.scaler = None
        self.model_path = "/models/scaling_model.pkl"
        self.scaler_path = "/models/scaling_scaler.pkl"
        self.metrics_history = []
        self.prediction_window = 24  # hours

        # Railway API configuration
        self.railway_token = os.getenv("RAILWAY_TOKEN")
        self.railway_project_id = os.getenv("RAILWAY_PROJECT_ID")

        # Scaling thresholds
        self.scale_up_threshold = 0.8  # Scale up when predicted usage > 80%
        self.scale_down_threshold = 0.3  # Scale down when predicted usage < 30%
        self.min_instances = 1
        self.max_instances = 10

    def collect_metrics(self) -> Dict[str, Any]:
        """Collect current system metrics for scaling decisions"""
        try:
            # In a real implementation, this would query Prometheus/Grafana APIs
            # For now, simulate based on time patterns

            current_hour = datetime.utcnow().hour
            current_day = datetime.utcnow().weekday()

            # Simulate traffic patterns (higher during evenings and weekends)
            base_traffic = 100
            hour_multiplier = self._get_hour_multiplier(current_hour)
            day_multiplier = self._get_day_multiplier(current_day)

            current_traffic = int(base_traffic * hour_multiplier * day_multiplier)

            # Add some randomness
            import random
            current_traffic = int(current_traffic * (0.8 + random.random() * 0.4))

            metrics = {
                'timestamp': datetime.utcnow().isoformat(),
                'cpu_usage': min(100, current_traffic / 10 + random.uniform(-10, 10)),
                'memory_usage': min(100, current_traffic / 8 + random.uniform(-5, 5)),
                'request_rate': current_traffic,
                'response_time': max(50, 200 - current_traffic / 5 + random.uniform(-20, 20)),
                'error_rate': max(0, random.uniform(0, 0.05)),
                'active_connections': current_traffic * 2,
                'hour_of_day': current_hour,
                'day_of_week': current_day,
                'is_weekend': 1 if current_day >= 5 else 0,
            }

            # Store in history for ML training
            self.metrics_history.append(metrics)
            if len(self.metrics_history) > 1000:  # Keep last 1000 data points
                self.metrics_history = self.metrics_history[-1000:]

            return metrics

        except Exception as e:
            logger.error(f"Metrics collection failed: {e}")
            return {}

    def _get_hour_multiplier(self, hour: int) -> float:
        """Get traffic multiplier based on hour of day"""
        # Peak hours: 7-9 PM (19-21), lower during night
        if 19 <= hour <= 21:
            return 2.5
        elif 7 <= hour <= 9 or 16 <= hour <= 18:
            return 1.8
        elif 22 <= hour <= 5:
            return 0.3
        else:
            return 1.0

    def _get_day_multiplier(self, day: int) -> float:
        """Get traffic multiplier based on day of week"""
        # Higher on weekends
        if day >= 5:  # Saturday/Sunday
            return 1.6
        elif day == 0:  # Monday (back to school/work)
            return 0.8
        else:
            return 1.0

    def train_predictive_model(self):
        """Train ML model for traffic prediction"""
        if len(self.metrics_history) < 50:
            logger.info("Not enough data for training, need at least 50 samples")
            return

        try:
            # Prepare data
            df = pd.DataFrame(self.metrics_history)

            # Features for prediction
            features = ['hour_of_day', 'day_of_week', 'is_weekend', 'cpu_usage', 'memory_usage']
            target = 'request_rate'

            X = df[features].fillna(0)
            y = df[target].fillna(0)

            # Split data
            X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

            # Scale features
            self.scaler = StandardScaler()
            X_train_scaled = self.scaler.fit_transform(X_train)
            X_test_scaled = self.scaler.transform(X_test)

            # Train model
            self.model = RandomForestRegressor(
                n_estimators=100,
                max_depth=10,
                random_state=42
            )
            self.model.fit(X_train_scaled, y_train)

            # Evaluate model
            train_score = self.model.score(X_train_scaled, y_train)
            test_score = self.model.score(X_test_scaled, y_test)

            logger.info(".3f"
            # Save model
            os.makedirs(os.path.dirname(self.model_path), exist_ok=True)
            joblib.dump(self.model, self.model_path)
            joblib.dump(self.scaler, self.scaler_path)

            logger.info("Predictive model trained and saved")

        except Exception as e:
            logger.error(f"Model training failed: {e}")

    def predict_resource_needs(self, hours_ahead: int = 1) -> Dict[str, Any]:
        """Predict resource needs for future time periods"""
        if not self.model or not self.scaler:
            # Load existing model if available
            try:
                self.model = joblib.load(self.model_path)
                self.scaler = joblib.load(self.scaler_path)
            except:
                logger.warning("No trained model available, using rule-based prediction")
                return self._rule_based_prediction(hours_ahead)

        try:
            # Get current metrics
            current_metrics = self.collect_metrics()
            if not current_metrics:
                return {}

            # Prepare prediction input
            future_time = datetime.utcnow() + timedelta(hours=hours_ahead)
            prediction_input = {
                'hour_of_day': future_time.hour,
                'day_of_week': future_time.weekday(),
                'is_weekend': 1 if future_time.weekday() >= 5 else 0,
                'cpu_usage': current_metrics.get('cpu_usage', 50),
                'memory_usage': current_metrics.get('memory_usage', 50),
            }

            # Make prediction
            input_df = pd.DataFrame([prediction_input])
            input_scaled = self.scaler.transform(input_df)
            predicted_traffic = self.model.predict(input_scaled)[0]

            # Calculate resource recommendations
            predicted_cpu = min(100, predicted_traffic / 10)
            predicted_memory = min(100, predicted_traffic / 8)
            recommended_instances = max(self.min_instances,
                                      min(self.max_instances,
                                          int(predicted_traffic / 50) + 1))

            return {
                'predicted_traffic': predicted_traffic,
                'predicted_cpu_usage': predicted_cpu,
                'predicted_memory_usage': predicted_memory,
                'recommended_instances': recommended_instances,
                'prediction_time': future_time.isoformat(),
                'confidence_score': 0.85,  # Placeholder - would calculate actual confidence
            }

        except Exception as e:
            logger.error(f"Prediction failed: {e}")
            return self._rule_based_prediction(hours_ahead)

    def _rule_based_prediction(self, hours_ahead: int) -> Dict[str, Any]:
        """Fallback rule-based prediction when ML model is unavailable"""
        future_time = datetime.utcnow() + timedelta(hours=hours_ahead)
        hour_multiplier = self._get_hour_multiplier(future_time.hour)
        day_multiplier = self._get_day_multiplier(future_time.weekday())

        predicted_traffic = int(100 * hour_multiplier * day_multiplier)
        recommended_instances = max(self.min_instances,
                                  min(self.max_instances,
                                      int(predicted_traffic / 50) + 1))

        return {
            'predicted_traffic': predicted_traffic,
            'predicted_cpu_usage': min(100, predicted_traffic / 10),
            'predicted_memory_usage': min(100, predicted_traffic / 8),
            'recommended_instances': recommended_instances,
            'prediction_time': future_time.isoformat(),
            'method': 'rule_based',
        }

    def should_scale(self) -> Dict[str, Any]:
        """Determine if scaling action is needed"""
        current_metrics = self.collect_metrics()
        prediction = self.predict_resource_needs(hours_ahead=1)

        if not current_metrics or not prediction:
            return {'action': 'none', 'reason': 'insufficient_data'}

        current_instances = self._get_current_instance_count()
        recommended_instances = prediction.get('recommended_instances', current_instances)

        # Scale up conditions
        if (current_metrics.get('cpu_usage', 0) > 80 or
            current_metrics.get('memory_usage', 0) > 80 or
            prediction.get('predicted_cpu_usage', 0) > self.scale_up_threshold * 100):
            if recommended_instances > current_instances:
                return {
                    'action': 'scale_up',
                    'from_instances': current_instances,
                    'to_instances': recommended_instances,
                    'reason': 'high_usage_or_prediction',
                    'metrics': current_metrics,
                    'prediction': prediction,
                }

        # Scale down conditions
        elif (current_metrics.get('cpu_usage', 0) < 30 and
              current_metrics.get('memory_usage', 0) < 30 and
              prediction.get('predicted_cpu_usage', 0) < self.scale_down_threshold * 100 and
              current_instances > self.min_instances):
            return {
                'action': 'scale_down',
                'from_instances': current_instances,
                'to_instances': max(self.min_instances, current_instances - 1),
                'reason': 'low_usage_prediction',
                'metrics': current_metrics,
                'prediction': prediction,
            }

        return {
            'action': 'maintain',
            'current_instances': current_instances,
            'reason': 'optimal_usage',
            'metrics': current_metrics,
        }

    def _get_current_instance_count(self) -> int:
        """Get current number of running instances"""
        # In a real implementation, this would query Railway API
        # For now, return a simulated value
        return 2

    def execute_scaling(self, scaling_decision: Dict[str, Any]) -> bool:
        """Execute scaling action via Railway API"""
        action = scaling_decision.get('action')
        if action not in ['scale_up', 'scale_down']:
            return False

        try:
            target_instances = scaling_decision.get('to_instances', 2)

            # Railway CLI command simulation
            # In production, this would use Railway API or CLI
            logger.info(f"Executing {action} to {target_instances} instances")

            # Simulate API call
            success = self._call_railway_api(action, target_instances)

            if success:
                logger.info(f"Successfully scaled {action} to {target_instances} instances")
                return True
            else:
                logger.error(f"Scaling {action} failed")
                return False

        except Exception as e:
            logger.error(f"Scaling execution failed: {e}")
            return False

    def _call_railway_api(self, action: str, instances: int) -> bool:
        """Call Railway API to execute scaling"""
        # This would be replaced with actual Railway API calls
        # For now, simulate success
        time.sleep(1)  # Simulate API call delay
        return True

    def get_scaling_report(self) -> Dict[str, Any]:
        """Generate comprehensive scaling report"""
        current_metrics = self.collect_metrics()
        prediction = self.predict_resource_needs()
        scaling_decision = self.should_scale()

        return {
            'timestamp': datetime.utcnow().isoformat(),
            'current_metrics': current_metrics,
            'prediction': prediction,
            'scaling_decision': scaling_decision,
            'model_status': 'trained' if self.model else 'untrained',
            'data_points': len(self.metrics_history),
        }

def main():
    """Main predictive scaling execution"""
    try:
        scaler = PredictiveScaler()

        # Collect metrics and train model periodically
        scaler.collect_metrics()

        # Train model if enough data
        if len(scaler.metrics_history) >= 50 and len(scaler.metrics_history) % 100 == 0:
            scaler.train_predictive_model()

        # Check scaling needs
        scaling_decision = scaler.should_scale()

        if scaling_decision['action'] != 'maintain':
            logger.info(f"Scaling decision: {scaling_decision}")
            success = scaler.execute_scaling(scaling_decision)
            if success:
                logger.info("Scaling executed successfully")
            else:
                logger.error("Scaling execution failed")
        else:
            logger.info("No scaling action needed")

        # Generate report
        report = scaler.get_scaling_report()
        print("=== Predictive Scaling Report ===")
        print(f"Action: {report['scaling_decision']['action']}")
        print(f"Current Traffic: {report['current_metrics'].get('request_rate', 'N/A')}")
        print(f"Predicted Traffic: {report['prediction'].get('predicted_traffic', 'N/A')}")
        print(f"Recommended Instances: {report['prediction'].get('recommended_instances', 'N/A')}")

        return 0

    except Exception as e:
        logger.error(f"Predictive scaling failed: {e}")
        return 1

if __name__ == "__main__":
    exit(main())