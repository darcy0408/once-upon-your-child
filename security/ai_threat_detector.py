#!/usr/bin/env python3
"""
AI-Powered Threat Detection for Story Weaver
Intelligent security monitoring and automated threat response
"""

import os
import json
import time
import logging
import hashlib
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
from collections import defaultdict, deque
import re
import requests

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class AIThreatDetector:
    def __init__(self):
        self.threat_patterns = self._load_threat_patterns()
        self.baseline_metrics = {}
        self.anomaly_history = deque(maxlen=1000)
        self.threat_indicators = defaultdict(list)
        self.suspicious_activities = []

        # Threat detection thresholds
        self.anomaly_threshold = 3.0  # Standard deviations
        self.brute_force_threshold = 5  # Failed attempts per minute
        self.data_exfiltration_threshold = 1000000  # Bytes per minute

        # Known threat signatures
        self.threat_signatures = {
            'sql_injection': re.compile(r'(\b(union|select|insert|delete|update|drop|create)\b.*\b(and|or)\b)', re.IGNORECASE),
            'xss_attempt': re.compile(r'<script[^>]*>.*?</script>', re.IGNORECASE),
            'path_traversal': re.compile(r'\.\./|\.\.\\'),
            'command_injection': re.compile(r'[;&|`$()]'),
            'suspicious_headers': ['X-Forwarded-For', 'X-Real-IP', 'CF-Connecting-IP']
        }

    def _load_threat_patterns(self) -> Dict[str, Any]:
        """Load known threat patterns and signatures"""
        return {
            'api_abuse': {
                'patterns': ['rapid_requests', 'unusual_endpoints', 'suspicious_payloads'],
                'indicators': ['high_error_rate', 'unusual_user_agents', 'geographic_anomalies']
            },
            'authentication_attacks': {
                'patterns': ['brute_force', 'credential_stuffing', 'session_hijacking'],
                'indicators': ['multiple_failed_logins', 'unusual_login_times', 'new_device_logins']
            },
            'data_exfiltration': {
                'patterns': ['large_downloads', 'unusual_data_access', 'bulk_exports'],
                'indicators': ['high_bandwidth_usage', 'unusual_file_access', 'bulk_data_queries']
            },
            'injection_attacks': {
                'patterns': ['sql_injection', 'xss', 'command_injection'],
                'indicators': ['malformed_queries', 'script_tags', 'system_commands']
            },
            'reconnaissance': {
                'patterns': ['port_scanning', 'endpoint_enumeration', 'version_detection'],
                'indicators': ['unusual_404s', 'system_endpoint_access', 'information_disclosure']
            }
        }

    def analyze_request(self, request_data: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze an incoming request for security threats"""
        analysis = {
            'timestamp': datetime.utcnow().isoformat(),
            'threat_score': 0.0,
            'threat_level': 'low',
            'detected_threats': [],
            'recommendations': [],
            'requires_action': False
        }

        # Extract request components
        ip = request_data.get('ip', '')
        user_agent = request_data.get('user_agent', '')
        endpoint = request_data.get('endpoint', '')
        method = request_data.get('method', '')
        payload = request_data.get('payload', '')
        headers = request_data.get('headers', {})

        # Run threat detection checks
        threats = []

        # Check for injection attacks
        injection_threats = self._detect_injection_attacks(payload, headers)
        threats.extend(injection_threats)

        # Check for suspicious patterns
        pattern_threats = self._detect_suspicious_patterns(request_data)
        threats.extend(pattern_threats)

        # Check for brute force attempts
        brute_force_threats = self._detect_brute_force(ip, endpoint)
        threats.extend(brute_force_threats)

        # Check for anomalous behavior
        anomaly_threats = self._detect_anomalous_behavior(request_data)
        threats.extend(anomaly_threats)

        # Calculate overall threat score
        analysis['detected_threats'] = threats
        analysis['threat_score'] = sum(threat.get('score', 0) for threat in threats)

        # Determine threat level
        if analysis['threat_score'] >= 8.0:
            analysis['threat_level'] = 'critical'
            analysis['requires_action'] = True
        elif analysis['threat_score'] >= 5.0:
            analysis['threat_level'] = 'high'
            analysis['requires_action'] = True
        elif analysis['threat_score'] >= 3.0:
            analysis['threat_level'] = 'medium'

        # Generate recommendations
        analysis['recommendations'] = self._generate_threat_recommendations(threats, analysis['threat_level'])

        # Log significant threats
        if analysis['requires_action']:
            self._log_threat(analysis)
            self.suspicious_activities.append(analysis)

        return analysis

    def _detect_injection_attacks(self, payload: str, headers: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Detect SQL injection, XSS, and other injection attacks"""
        threats = []

        # Check payload for injection patterns
        if payload:
            for attack_type, pattern in self.threat_signatures.items():
                if pattern.search(str(payload)):
                    threats.append({
                        'type': attack_type,
                        'severity': 'high',
                        'score': 3.0,
                        'description': f'Detected {attack_type.replace("_", " ")} pattern in request payload',
                        'evidence': pattern.pattern,
                        'category': 'injection_attack'
                    })

        # Check headers for suspicious content
        for header_name, header_value in headers.items():
            if header_name in self.threat_signatures['suspicious_headers']:
                if self._is_suspicious_header_value(header_value):
                    threats.append({
                        'type': 'header_manipulation',
                        'severity': 'medium',
                        'score': 2.0,
                        'description': f'Suspicious {header_name} header value',
                        'evidence': str(header_value)[:100],
                        'category': 'header_attack'
                    })

        return threats

    def _detect_suspicious_patterns(self, request_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Detect suspicious request patterns"""
        threats = []

        ip = request_data.get('ip', '')
        user_agent = request_data.get('user_agent', '')
        endpoint = request_data.get('endpoint', '')
        method = request_data.get('method', '')

        # Check for unusual user agents
        if self._is_suspicious_user_agent(user_agent):
            threats.append({
                'type': 'suspicious_user_agent',
                'severity': 'low',
                'score': 1.0,
                'description': 'Unusual or suspicious user agent string',
                'evidence': user_agent[:100],
                'category': 'reconnaissance'
            })

        # Check for unusual endpoints
        if self._is_suspicious_endpoint(endpoint):
            threats.append({
                'type': 'unusual_endpoint_access',
                'severity': 'medium',
                'score': 2.0,
                'description': 'Access to unusual or sensitive endpoint',
                'evidence': endpoint,
                'category': 'reconnaissance'
            })

        # Check for unusual HTTP methods
        if method not in ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS']:
            threats.append({
                'type': 'unusual_http_method',
                'severity': 'low',
                'score': 1.0,
                'description': f'Unusual HTTP method: {method}',
                'evidence': method,
                'category': 'reconnaissance'
            })

        return threats

    def _detect_brute_force(self, ip: str, endpoint: str) -> List[Dict[str, Any]]:
        """Detect brute force attacks"""
        threats = []

        # Track failed attempts by IP
        failed_key = f"failed_attempts:{ip}"
        recent_failures = len(self.threat_indicators.get(failed_key, []))

        if recent_failures >= self.brute_force_threshold:
            threats.append({
                'type': 'brute_force_attempt',
                'severity': 'high',
                'score': 4.0,
                'description': f'Brute force attack detected from IP {ip}',
                'evidence': f'{recent_failures} failed attempts in last minute',
                'category': 'authentication_attack'
            })

        # Track endpoint-specific attacks
        endpoint_key = f"endpoint_attacks:{endpoint}"
        endpoint_attacks = len(self.threat_indicators.get(endpoint_key, []))

        if endpoint_attacks >= 10:
            threats.append({
                'type': 'endpoint_abuse',
                'severity': 'medium',
                'score': 2.5,
                'description': f'Excessive requests to endpoint {endpoint}',
                'evidence': f'{endpoint_attacks} requests in short time period',
                'category': 'api_abuse'
            })

        return threats

    def _detect_anomalous_behavior(self, request_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Detect anomalous behavior using statistical analysis"""
        threats = []

        # Compare current request patterns to baseline
        current_metrics = self._extract_request_metrics(request_data)

        for metric_name, current_value in current_metrics.items():
            baseline = self.baseline_metrics.get(metric_name, {})
            if baseline:
                mean = baseline.get('mean', current_value)
                std = baseline.get('std', 1)

                if std > 0:
                    z_score = abs(current_value - mean) / std
                    if z_score > self.anomaly_threshold:
                        threats.append({
                            'type': 'anomalous_behavior',
                            'severity': 'medium' if z_score < 4 else 'high',
                            'score': min(z_score, 5.0),
                            'description': f'Anomalous {metric_name}: {current_value} (expected ~{mean:.1f})',
                            'evidence': f'Z-score: {z_score:.2f}',
                            'category': 'anomalous_activity'
                        })

        return threats

    def _extract_request_metrics(self, request_data: Dict[str, Any]) -> Dict[str, float]:
        """Extract numerical metrics from request data"""
        metrics = {}

        # Request size
        payload = request_data.get('payload', '')
        if payload:
            metrics['payload_size'] = len(str(payload))

        # Header count
        headers = request_data.get('headers', {})
        metrics['header_count'] = len(headers)

        # Query parameter count
        query_params = request_data.get('query_params', {})
        metrics['query_param_count'] = len(query_params)

        return metrics

    def _is_suspicious_user_agent(self, user_agent: str) -> bool:
        """Check if user agent is suspicious"""
        suspicious_patterns = [
            r'^$',  # Empty
            r'python|curl|wget|scrapy',  # Automation tools
            r'sqlmap|nikto|dirbuster',  # Security tools
            r'^[a-zA-Z0-9]{10,}$',  # Random strings
        ]

        for pattern in suspicious_patterns:
            if re.search(pattern, user_agent, re.IGNORECASE):
                return True

        return False

    def _is_suspicious_endpoint(self, endpoint: str) -> bool:
        """Check if endpoint access is suspicious"""
        sensitive_endpoints = [
            '/admin', '/phpmyadmin', '/wp-admin', '/.env', '/.git',
            '/server-status', '/phpinfo', '/web.config', '/crossdomain.xml'
        ]

        for sensitive in sensitive_endpoints:
            if sensitive in endpoint.lower():
                return True

        return False

    def _is_suspicious_header_value(self, value: str) -> bool:
        """Check if header value is suspicious"""
        # Check for multiple IPs (proxy chaining)
        if ',' in str(value):
            ips = [ip.strip() for ip in str(value).split(',')]
            if len(ips) > 3:  # More than 3 proxies
                return True

        # Check for obviously fake IPs
        if str(value) in ['127.0.0.1', '0.0.0.0', 'localhost']:
            return True

        return False

    def _generate_threat_recommendations(self, threats: List[Dict[str, Any]], threat_level: str) -> List[str]:
        """Generate recommendations based on detected threats"""
        recommendations = []

        if threat_level in ['high', 'critical']:
            recommendations.append("🚨 IMMEDIATE ACTION REQUIRED: Block suspicious IP and investigate")

        threat_types = set(threat['type'] for threat in threats)

        if 'sql_injection' in threat_types:
            recommendations.append("Implement prepared statements and input sanitization")

        if 'brute_force_attempt' in threat_types:
            recommendations.append("Implement account lockout and CAPTCHA for failed logins")

        if 'anomalous_behavior' in threat_types:
            recommendations.append("Review baseline metrics and update anomaly detection thresholds")

        if 'unusual_endpoint_access' in threat_types:
            recommendations.append("Audit endpoint permissions and implement rate limiting")

        if not recommendations:
            recommendations.append("Monitor the identified threats and update security rules")

        return recommendations

    def _log_threat(self, threat_analysis: Dict[str, Any]):
        """Log significant threats for analysis"""
        logger.warning(f"THREAT DETECTED: {threat_analysis['threat_level']} "
                      f"score {threat_analysis['threat_score']:.1f} - "
                      f"{len(threat_analysis['detected_threats'])} indicators")

        # Store in anomaly history for pattern analysis
        self.anomaly_history.append(threat_analysis)

    def update_baseline(self, metrics_data: List[Dict[str, Any]]):
        """Update baseline metrics for anomaly detection"""
        if not metrics_data:
            return

        # Calculate baseline statistics
        metric_values = defaultdict(list)

        for data in metrics_data[-1000:]:  # Use last 1000 data points
            for metric_name, value in self._extract_request_metrics(data).items():
                metric_values[metric_name].append(value)

        # Calculate mean and standard deviation for each metric
        for metric_name, values in metric_values.items():
            if len(values) >= 10:  # Need minimum samples
                self.baseline_metrics[metric_name] = {
                    'mean': sum(values) / len(values),
                    'std': (sum((x - (sum(values) / len(values))) ** 2 for x in values) / len(values)) ** 0.5,
                    'min': min(values),
                    'max': max(values),
                    'sample_size': len(values)
                }

        logger.info(f"Updated baseline metrics for {len(self.baseline_metrics)} indicators")

    def get_threat_report(self) -> Dict[str, Any]:
        """Generate comprehensive threat detection report"""
        recent_threats = list(self.anomaly_history)[-50:] if self.anomaly_history else []

        # Analyze threat patterns
        threat_summary = defaultdict(int)
        severity_counts = defaultdict(int)
        category_counts = defaultdict(int)

        for threat in recent_threats:
            for detected in threat.get('detected_threats', []):
                threat_summary[detected['type']] += 1
                severity_counts[detected['severity']] += 1
                category_counts[detected.get('category', 'unknown')] += 1

        return {
            'timestamp': datetime.utcnow().isoformat(),
            'total_threats_detected': len(recent_threats),
            'threat_summary': dict(threat_summary),
            'severity_distribution': dict(severity_counts),
            'category_distribution': dict(category_counts),
            'baseline_metrics_count': len(self.baseline_metrics),
            'recent_threats': recent_threats[-10:],  # Last 10 threats
            'threat_trends': self._analyze_threat_trends(recent_threats)
        }

    def _analyze_threat_trends(self, threats: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analyze threat trends over time"""
        if len(threats) < 5:
            return {'insufficient_data': True}

        # Group by hour
        hourly_threats = defaultdict(int)

        for threat in threats[-100:]:  # Last 100 threats
            timestamp = datetime.fromisoformat(threat['timestamp'])
            hour_key = timestamp.strftime('%Y-%m-%d-%H')
            hourly_threats[hour_key] += 1

        # Calculate trend
        hours = sorted(hourly_threats.keys())[-24:]  # Last 24 hours
        if len(hours) >= 6:
            recent_avg = sum(hourly_threats[h] for h in hours[-6:]) / 6
            earlier_avg = sum(hourly_threats[h] for h in hours[:-6]) / max(1, len(hours) - 6)

            if recent_avg > earlier_avg * 1.5:
                trend = 'increasing'
            elif recent_avg < earlier_avg * 0.7:
                trend = 'decreasing'
            else:
                trend = 'stable'
        else:
            trend = 'insufficient_data'

        return {
            'trend': trend,
            'recent_avg': recent_avg if 'recent_avg' in locals() else 0,
            'data_points': len(hours)
        }

    def add_failed_attempt(self, ip: str, endpoint: str, reason: str = "authentication_failure"):
        """Record a failed security attempt"""
        timestamp = datetime.utcnow()

        # Clean up old entries (keep last 5 minutes)
        cutoff = timestamp - timedelta(minutes=5)
        self.threat_indicators[f"failed_attempts:{ip}"] = [
            t for t in self.threat_indicators[f"failed_attempts:{ip}"]
            if t > cutoff
        ]

        # Add new failure
        self.threat_indicators[f"failed_attempts:{ip}"].append(timestamp)
        self.threat_indicators[f"endpoint_attacks:{endpoint}"].append(timestamp)

        # Check for immediate blocking
        recent_failures = len(self.threat_indicators[f"failed_attempts:{ip}"])
        if recent_failures >= self.brute_force_threshold * 2:
            logger.warning(f"IP {ip} blocked due to excessive failed attempts")

def main():
    """Main threat detection execution"""
    try:
        detector = AIThreatDetector()

        # Example threat analysis
        test_request = {
            'ip': '192.168.1.100',
            'user_agent': 'Mozilla/5.0 (compatible; security-scanner/1.0)',
            'endpoint': '/api/admin/users',
            'method': 'GET',
            'payload': '',
            'headers': {'X-Forwarded-For': '127.0.0.1, 192.168.1.1, 10.0.0.1'},
            'query_params': {}
        }

        analysis = detector.analyze_request(test_request)

        print("=== AI Threat Detection Analysis ===")
        print(f"Threat Score: {analysis['threat_score']:.1f}")
        print(f"Threat Level: {analysis['threat_level']}")
        print(f"Requires Action: {analysis['requires_action']}")

        if analysis['detected_threats']:
            print(f"\nDetected Threats ({len(analysis['detected_threats'])}):")
            for threat in analysis['detected_threats']:
                print(f"  • {threat['type']} ({threat['severity']}): {threat['description']}")

        if analysis['recommendations']:
            print(f"\nRecommendations:")
            for rec in analysis['recommendations']:
                print(f"  • {rec}")

        # Generate threat report
        report = detector.get_threat_report()
        print(f"\nThreat Report Summary:")
        print(f"  Total Threats: {report['total_threats_detected']}")
        print(f"  Baseline Metrics: {report['baseline_metrics_count']}")
        print(f"  Threat Trend: {report['threat_trends'].get('trend', 'unknown')}")

        return 0

    except Exception as e:
        logger.error(f"Threat detection failed: {e}")
        return 1

if __name__ == "__main__":
    exit(main())