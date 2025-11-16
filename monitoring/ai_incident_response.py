#!/usr/bin/env python3
"""
AI-Powered Incident Response Assistant
Automated troubleshooting and root cause analysis for Story Weaver
"""

import os
import json
import logging
import re
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import requests

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class IncidentResponseAI:
    def __init__(self):
        self.incident_history = []
        self.knowledge_base = self._load_knowledge_base()
        self.openai_api_key = os.getenv("OPENAI_API_KEY")
        self.slack_webhook = os.getenv("SLACK_WEBHOOK_URL")

        # Incident response playbooks
        self.playbooks = {
            'high_cpu': self._cpu_incident_playbook,
            'high_memory': self._memory_incident_playbook,
            'slow_responses': self._response_time_playbook,
            'high_errors': self._error_rate_playbook,
            'database_issues': self._database_playbook,
            'cache_failures': self._cache_playbook,
        }

    def _load_knowledge_base(self) -> Dict[str, Any]:
        """Load historical incident data and solutions"""
        return {
            'common_issues': {
                'cpu_spikes': {
                    'symptoms': ['high cpu usage', 'slow responses', 'timeout errors'],
                    'causes': ['memory leaks', 'inefficient queries', 'traffic spikes', 'background jobs'],
                    'solutions': [
                        'Check database query performance',
                        'Review memory usage patterns',
                        'Scale up instance temporarily',
                        'Optimize background job scheduling'
                    ]
                },
                'memory_issues': {
                    'symptoms': ['high memory usage', 'out of memory errors', 'application restarts'],
                    'causes': ['memory leaks', 'large data processing', 'cache overflow', 'connection pool issues'],
                    'solutions': [
                        'Check for memory leaks in application code',
                        'Optimize database connection pooling',
                        'Implement memory limits and garbage collection tuning',
                        'Scale up instance memory'
                    ]
                },
                'database_problems': {
                    'symptoms': ['slow queries', 'connection timeouts', 'deadlocks'],
                    'causes': ['missing indexes', 'connection pool exhaustion', 'lock contention', 'disk I/O issues'],
                    'solutions': [
                        'Add database indexes for slow queries',
                        'Optimize connection pool settings',
                        'Review transaction isolation levels',
                        'Check disk I/O performance'
                    ]
                }
            },
            'resolution_patterns': [],
            'system_components': {
                'backend': ['flask', 'sqlalchemy', 'redis', 'postgresql'],
                'frontend': ['flutter', 'firebase', 'cdn'],
                'infrastructure': ['railway', 'docker', 'monitoring']
            }
        }

    def analyze_incident(self, incident_data: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze incident data and provide AI-powered insights"""
        incident_type = self._classify_incident(incident_data)
        root_cause = self._analyze_root_cause(incident_data, incident_type)
        recommendations = self._generate_recommendations(incident_data, incident_type, root_cause)

        analysis = {
            'incident_id': f"INC-{datetime.utcnow().strftime('%Y%m%d-%H%M%S')}",
            'timestamp': datetime.utcnow().isoformat(),
            'incident_type': incident_type,
            'severity': incident_data.get('severity', 'unknown'),
            'root_cause_analysis': root_cause,
            'recommendations': recommendations,
            'confidence_score': self._calculate_confidence(incident_data, root_cause),
            'estimated_resolution_time': self._estimate_resolution_time(incident_type, incident_data.get('severity')),
            'follow_up_actions': self._generate_follow_up_actions(incident_type),
        }

        # Store for learning
        self.incident_history.append(analysis)

        return analysis

    def _classify_incident(self, incident_data: Dict[str, Any]) -> str:
        """Classify the type of incident based on symptoms"""
        symptoms = incident_data.get('symptoms', [])
        metrics = incident_data.get('metrics', {})

        # CPU-related incidents
        if any(s in symptoms for s in ['high cpu', 'cpu spike', 'cpu usage']) or metrics.get('cpu_usage', 0) > 80:
            return 'high_cpu'

        # Memory-related incidents
        if any(s in symptoms for s in ['high memory', 'memory leak', 'out of memory']) or metrics.get('memory_usage', 0) > 85:
            return 'high_memory'

        # Response time incidents
        if any(s in symptoms for s in ['slow response', 'timeout', 'high latency']) or metrics.get('response_time_p95', 0) > 1000:
            return 'slow_responses'

        # Error rate incidents
        if any(s in symptoms for s in ['high errors', 'error rate']) or metrics.get('error_rate', 0) > 0.05:
            return 'high_errors'

        # Database incidents
        if any(s in symptoms for s in ['database', 'query slow', 'connection timeout']):
            return 'database_issues'

        # Cache incidents
        if any(s in symptoms for s in ['cache miss', 'cache failure']):
            return 'cache_failures'

        return 'unknown_incident'

    def _analyze_root_cause(self, incident_data: Dict[str, Any], incident_type: str) -> Dict[str, Any]:
        """Analyze root cause using AI and historical data"""
        metrics = incident_data.get('metrics', {})
        symptoms = incident_data.get('symptoms', [])

        analysis = {
            'primary_cause': 'unknown',
            'contributing_factors': [],
            'evidence': [],
            'confidence': 0.0
        }

        if incident_type == 'high_cpu':
            analysis.update(self._analyze_cpu_root_cause(metrics, symptoms))
        elif incident_type == 'high_memory':
            analysis.update(self._analyze_memory_root_cause(metrics, symptoms))
        elif incident_type == 'slow_responses':
            analysis.update(self._analyze_response_time_root_cause(metrics, symptoms))
        elif incident_type == 'high_errors':
            analysis.update(self._analyze_error_root_cause(metrics, symptoms))
        elif incident_type == 'database_issues':
            analysis.update(self._analyze_database_root_cause(metrics, symptoms))
        elif incident_type == 'cache_failures':
            analysis.update(self._analyze_cache_root_cause(metrics, symptoms))

        # Use AI for deeper analysis if available
        if self.openai_api_key:
            ai_analysis = self._get_ai_root_cause_analysis(incident_data, incident_type)
            if ai_analysis:
                analysis['ai_insights'] = ai_analysis

        return analysis

    def _analyze_cpu_root_cause(self, metrics: Dict[str, Any], symptoms: List[str]) -> Dict[str, Any]:
        """Analyze CPU-related root causes"""
        cpu_usage = metrics.get('cpu_usage', 0)
        request_rate = metrics.get('request_rate', 0)
        memory_usage = metrics.get('memory_usage', 0)

        causes = []
        evidence = []

        if request_rate > 200:
            causes.append('high_request_volume')
            evidence.append(f"Request rate: {request_rate} req/min")

        if memory_usage > 80:
            causes.append('memory_pressure')
            evidence.append(f"High memory usage: {memory_usage}%")

        if cpu_usage > 90:
            causes.append('compute_intensive_operations')
            evidence.append(f"CPU usage: {cpu_usage}%")

        return {
            'primary_cause': causes[0] if causes else 'unknown',
            'contributing_factors': causes[1:],
            'evidence': evidence,
            'confidence': 0.8 if causes else 0.3
        }

    def _analyze_memory_root_cause(self, metrics: Dict[str, Any], symptoms: List[str]) -> Dict[str, Any]:
        """Analyze memory-related root causes"""
        memory_usage = metrics.get('memory_usage', 0)
        active_connections = metrics.get('active_connections', 0)
        cache_hit_rate = metrics.get('cache_hit_rate', 1)

        causes = []
        evidence = []

        if active_connections > 100:
            causes.append('connection_pool_leak')
            evidence.append(f"Active connections: {active_connections}")

        if cache_hit_rate < 0.7:
            causes.append('cache_inefficiency')
            evidence.append(f"Cache hit rate: {cache_hit_rate:.2%}")

        if memory_usage > 95:
            causes.append('memory_leak')
            evidence.append(f"Memory usage: {memory_usage}%")

        return {
            'primary_cause': causes[0] if causes else 'unknown',
            'contributing_factors': causes[1:],
            'evidence': evidence,
            'confidence': 0.85 if causes else 0.4
        }

    def _analyze_response_time_root_cause(self, metrics: Dict[str, Any], symptoms: List[str]) -> Dict[str, Any]:
        """Analyze response time issues"""
        response_time = metrics.get('response_time_p95', 0)
        database_connections = metrics.get('database_connections', 0)
        cpu_usage = metrics.get('cpu_usage', 0)

        causes = []
        evidence = []

        if database_connections > 20:
            causes.append('database_connection_contention')
            evidence.append(f"Database connections: {database_connections}")

        if cpu_usage > 80:
            causes.append('cpu_saturation')
            evidence.append(f"CPU usage: {cpu_usage}%")

        if response_time > 2000:
            causes.append('external_service_timeout')
            evidence.append(f"P95 response time: {response_time}ms")

        return {
            'primary_cause': causes[0] if causes else 'unknown',
            'contributing_factors': causes[1:],
            'evidence': evidence,
            'confidence': 0.75 if causes else 0.35
        }

    def _analyze_error_root_cause(self, metrics: Dict[str, Any], symptoms: List[str]) -> Dict[str, Any]:
        """Analyze error rate issues"""
        error_rate = metrics.get('error_rate', 0)
        response_time = metrics.get('response_time_p95', 0)

        causes = []
        evidence = []

        if response_time > 5000:
            causes.append('timeout_errors')
            evidence.append(f"High response time: {response_time}ms")

        if error_rate > 0.1:
            causes.append('service_unavailability')
            evidence.append(f"Error rate: {error_rate:.2%}")

        return {
            'primary_cause': causes[0] if causes else 'unknown',
            'contributing_factors': causes[1:],
            'evidence': evidence,
            'confidence': 0.7 if causes else 0.3
        }

    def _analyze_database_root_cause(self, metrics: Dict[str, Any], symptoms: List[str]) -> Dict[str, Any]:
        """Analyze database issues"""
        db_connections = metrics.get('database_connections', 0)
        response_time = metrics.get('response_time_p95', 0)

        causes = []
        evidence = []

        if db_connections > 15:
            causes.append('connection_pool_exhaustion')
            evidence.append(f"Database connections: {db_connections}")

        if response_time > 1000:
            causes.append('slow_queries')
            evidence.append(f"Response time: {response_time}ms")

        return {
            'primary_cause': causes[0] if causes else 'unknown',
            'contributing_factors': causes[1:],
            'evidence': evidence,
            'confidence': 0.8 if causes else 0.4
        }

    def _analyze_cache_root_cause(self, metrics: Dict[str, Any], symptoms: List[str]) -> Dict[str, Any]:
        """Analyze cache issues"""
        cache_hit_rate = metrics.get('cache_hit_rate', 1)

        causes = []
        evidence = []

        if cache_hit_rate < 0.5:
            causes.append('cache_configuration_issue')
            evidence.append(f"Cache hit rate: {cache_hit_rate:.2%}")

        return {
            'primary_cause': causes[0] if causes else 'unknown',
            'contributing_factors': causes[1:],
            'evidence': evidence,
            'confidence': 0.6 if causes else 0.2
        }

    def _get_ai_root_cause_analysis(self, incident_data: Dict[str, Any], incident_type: str) -> Optional[str]:
        """Use OpenAI for deeper root cause analysis"""
        if not self.openai_api_key:
            return None

        try:
            prompt = f"""
Analyze this system incident and provide insights:

Incident Type: {incident_type}
Metrics: {json.dumps(incident_data.get('metrics', {}), indent=2)}
Symptoms: {incident_data.get('symptoms', [])}

Provide:
1. Most likely root cause
2. Why this cause makes sense
3. What evidence supports this conclusion
4. Any additional factors to investigate
"""

            response = requests.post(
                "https://api.openai.com/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.openai_api_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": "gpt-3.5-turbo",
                    "messages": [{"role": "user", "content": prompt}],
                    "max_tokens": 500
                }
            )

            if response.status_code == 200:
                result = response.json()
                return result['choices'][0]['message']['content']

        except Exception as e:
            logger.error(f"AI analysis failed: {e}")

        return None

    def _generate_recommendations(self, incident_data: Dict[str, Any], incident_type: str, root_cause: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Generate actionable recommendations"""
        recommendations = []

        # Get playbook for incident type
        if incident_type in self.playbooks:
            playbook = self.playbooks[incident_type]
            recommendations.extend(playbook(incident_data, root_cause))

        # Add general recommendations
        recommendations.extend([
            {
                'action': 'monitor_closely',
                'description': 'Continue monitoring the affected metrics for 30 minutes',
                'priority': 'high',
                'estimated_time': '30 minutes'
            },
            {
                'action': 'document_incident',
                'description': 'Document the incident, root cause, and resolution for future reference',
                'priority': 'medium',
                'estimated_time': '15 minutes'
            }
        ])

        return recommendations

    def _cpu_incident_playbook(self, incident_data: Dict[str, Any], root_cause: Dict[str, Any]) -> List[Dict[str, Any]]:
        """CPU incident response playbook"""
        return [
            {
                'action': 'check_database_queries',
                'description': 'Review slow database queries that may be consuming CPU',
                'priority': 'high',
                'estimated_time': '10 minutes',
                'commands': ['Check query execution plans', 'Look for N+1 queries']
            },
            {
                'action': 'scale_instance',
                'description': 'Temporarily scale up instance to handle load',
                'priority': 'high',
                'estimated_time': '5 minutes',
                'commands': ['railway scale up']
            },
            {
                'action': 'optimize_background_jobs',
                'description': 'Review and optimize background job scheduling',
                'priority': 'medium',
                'estimated_time': '30 minutes'
            }
        ]

    def _memory_incident_playbook(self, incident_data: Dict[str, Any], root_cause: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Memory incident response playbook"""
        return [
            {
                'action': 'check_memory_leaks',
                'description': 'Investigate application code for memory leaks',
                'priority': 'high',
                'estimated_time': '20 minutes',
                'commands': ['Profile memory usage', 'Check garbage collection']
            },
            {
                'action': 'optimize_connection_pool',
                'description': 'Review and optimize database connection pool settings',
                'priority': 'high',
                'estimated_time': '10 minutes'
            },
            {
                'action': 'increase_instance_memory',
                'description': 'Scale up instance memory if needed',
                'priority': 'medium',
                'estimated_time': '5 minutes'
            }
        ]

    def _response_time_playbook(self, incident_data: Dict[str, Any], root_cause: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Response time incident response playbook"""
        return [
            {
                'action': 'check_database_performance',
                'description': 'Review database query performance and indexes',
                'priority': 'high',
                'estimated_time': '15 minutes'
            },
            {
                'action': 'optimize_caching',
                'description': 'Review cache hit rates and caching strategies',
                'priority': 'high',
                'estimated_time': '10 minutes'
            },
            {
                'action': 'check_external_dependencies',
                'description': 'Verify external API and service performance',
                'priority': 'medium',
                'estimated_time': '10 minutes'
            }
        ]

    def _error_rate_playbook(self, incident_data: Dict[str, Any], root_cause: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Error rate incident response playbook"""
        return [
            {
                'action': 'check_application_logs',
                'description': 'Review application logs for error patterns',
                'priority': 'high',
                'estimated_time': '10 minutes'
            },
            {
                'action': 'verify_service_dependencies',
                'description': 'Check health of dependent services (database, cache, APIs)',
                'priority': 'high',
                'estimated_time': '5 minutes'
            },
            {
                'action': 'rollback_recent_changes',
                'description': 'Consider rolling back recent deployments if errors started after deployment',
                'priority': 'medium',
                'estimated_time': '10 minutes'
            }
        ]

    def _database_playbook(self, incident_data: Dict[str, Any], root_cause: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Database incident response playbook"""
        return [
            {
                'action': 'check_connection_pool',
                'description': 'Verify database connection pool health and configuration',
                'priority': 'high',
                'estimated_time': '5 minutes'
            },
            {
                'action': 'review_slow_queries',
                'description': 'Identify and optimize slow database queries',
                'priority': 'high',
                'estimated_time': '20 minutes'
            },
            {
                'action': 'check_database_resources',
                'description': 'Monitor database CPU, memory, and disk I/O',
                'priority': 'medium',
                'estimated_time': '10 minutes'
            }
        ]

    def _cache_playbook(self, incident_data: Dict[str, Any], root_cause: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Cache incident response playbook"""
        return [
            {
                'action': 'check_cache_health',
                'description': 'Verify Redis/cache service health and connectivity',
                'priority': 'high',
                'estimated_time': '5 minutes'
            },
            {
                'action': 'review_cache_configuration',
                'description': 'Check cache TTL settings and memory limits',
                'priority': 'medium',
                'estimated_time': '10 minutes'
            },
            {
                'action': 'implement_cache_fallback',
                'description': 'Ensure application can function without cache',
                'priority': 'low',
                'estimated_time': '30 minutes'
            }
        ]

    def _calculate_confidence(self, incident_data: Dict[str, Any], root_cause: Dict[str, Any]) -> float:
        """Calculate confidence score for the analysis"""
        base_confidence = root_cause.get('confidence', 0.5)
        evidence_count = len(root_cause.get('evidence', []))

        # Increase confidence with more evidence
        evidence_bonus = min(evidence_count * 0.1, 0.3)

        # Increase confidence for critical incidents (more likely to be real issues)
        severity = incident_data.get('severity', 'low')
        severity_bonus = {'critical': 0.2, 'high': 0.1, 'medium': 0.05, 'low': 0.0}.get(severity, 0.0)

        return min(base_confidence + evidence_bonus + severity_bonus, 1.0)

    def _estimate_resolution_time(self, incident_type: str, severity: str) -> str:
        """Estimate time to resolve the incident"""
        base_times = {
            'high_cpu': {'critical': '2-4 hours', 'high': '1-2 hours', 'medium': '30-60 min'},
            'high_memory': {'critical': '1-3 hours', 'high': '45-90 min', 'medium': '20-40 min'},
            'slow_responses': {'critical': '1-2 hours', 'high': '30-60 min', 'medium': '15-30 min'},
            'high_errors': {'critical': '30-60 min', 'high': '15-30 min', 'medium': '10-20 min'},
            'database_issues': {'critical': '2-6 hours', 'high': '1-3 hours', 'medium': '30-90 min'},
            'cache_failures': {'critical': '30-60 min', 'high': '15-30 min', 'medium': '5-15 min'},
        }

        return base_times.get(incident_type, {}).get(severity, '1-2 hours')

    def _generate_follow_up_actions(self, incident_type: str) -> List[str]:
        """Generate follow-up actions for incident prevention"""
        follow_ups = [
            "Review monitoring alerts and thresholds",
            "Update incident response playbooks",
            "Schedule post-mortem meeting",
            "Implement preventive measures"
        ]

        # Add incident-specific follow-ups
        if incident_type == 'high_cpu':
            follow_ups.extend([
                "Implement query optimization",
                "Review auto-scaling policies",
                "Optimize background job scheduling"
            ])
        elif incident_type == 'high_memory':
            follow_ups.extend([
                "Implement memory monitoring",
                "Review connection pool settings",
                "Add memory leak detection"
            ])

        return follow_ups

    def send_incident_report(self, analysis: Dict[str, Any]):
        """Send detailed incident report via Slack"""
        if not self.slack_webhook:
            logger.warning("No Slack webhook configured")
            return

        try:
            severity_emoji = {
                'critical': '🚨',
                'high': '⚠️',
                'medium': 'ℹ️',
                'low': '📊'
            }

            emoji = severity_emoji.get(analysis['severity'], '❓')

            message = {
                "text": f"{emoji} Incident Analysis: {analysis['incident_type'].replace('_', ' ').title()}",
                "blocks": [
                    {
                        "type": "header",
                        "text": {
                            "type": "plain_text",
                            "text": f"{emoji} Incident #{analysis['incident_id']}"
                        }
                    },
                    {
                        "type": "section",
                        "fields": [
                            {
                                "type": "mrkdwn",
                                "text": f"*Type:* {analysis['incident_type'].replace('_', ' ').title()}"
                            },
                            {
                                "type": "mrkdwn",
                                "text": f"*Severity:* {analysis['severity'].upper()}"
                            },
                            {
                                "type": "mrkdwn",
                                "text": f"*Confidence:* {analysis['confidence_score']:.1%}"
                            },
                            {
                                "type": "mrkdwn",
                                "text": f"*Est. Resolution:* {analysis['estimated_resolution_time']}"
                            }
                        ]
                    },
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"*Root Cause:* {analysis['root_cause_analysis']['primary_cause'].replace('_', ' ').title()}"
                        }
                    },
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"*Evidence:* {', '.join(analysis['root_cause_analysis']['evidence'])}"
                        }
                    },
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": "*Recommended Actions:*\n" + "\n".join(f"• {rec['action'].replace('_', ' ').title()}: {rec['description']}" for rec in analysis['recommendations'][:3])
                        }
                    }
                ]
            }

            response = requests.post(self.slack_webhook, json=message)
            response.raise_for_status()

            logger.info(f"Incident report sent for {analysis['incident_id']}")

        except Exception as e:
            logger.error(f"Failed to send incident report: {e}")

    def get_incident_summary(self) -> Dict[str, Any]:
        """Generate incident response summary"""
        recent_incidents = self.incident_history[-10:] if self.incident_history else []

        severity_counts = {}
        type_counts = {}

        for incident in recent_incidents:
            severity = incident.get('severity', 'unknown')
            incident_type = incident.get('incident_type', 'unknown')

            severity_counts[severity] = severity_counts.get(severity, 0) + 1
            type_counts[incident_type] = type_counts.get(incident_type, 0) + 1

        return {
            'total_incidents': len(self.incident_history),
            'recent_incidents': len(recent_incidents),
            'severity_distribution': severity_counts,
            'type_distribution': type_counts,
            'average_resolution_time': '1-2 hours',  # Placeholder
            'most_common_root_cause': max(type_counts, key=type_counts.get) if type_counts else 'none',
        }

def main():
    """Main incident response execution"""
    try:
        ai_assistant = IncidentResponseAI()

        # Example incident data (in production, this would come from monitoring alerts)
        sample_incident = {
            'severity': 'high',
            'symptoms': ['high cpu usage', 'slow response times'],
            'metrics': {
                'cpu_usage': 85.5,
                'memory_usage': 72.3,
                'request_rate': 150,
                'response_time_p95': 1200,
                'error_rate': 0.03,
                'active_connections': 95,
                'database_connections': 18,
                'cache_hit_rate': 0.78
            }
        }

        # Analyze incident
        analysis = ai_assistant.analyze_incident(sample_incident)

        print("=== AI Incident Response Analysis ===")
        print(f"Incident ID: {analysis['incident_id']}")
        print(f"Type: {analysis['incident_type']}")
        print(f"Severity: {analysis['severity']}")
        print(f"Root Cause: {analysis['root_cause_analysis']['primary_cause']}")
        print(f"Confidence: {analysis['confidence_score']:.1%}")
        print(f"Est. Resolution: {analysis['estimated_resolution_time']}")
        print("\nTop Recommendations:")
        for rec in analysis['recommendations'][:3]:
            print(f"  • {rec['action'].replace('_', ' ').title()}: {rec['description']}")

        # Send report
        ai_assistant.send_incident_report(analysis)

        # Generate summary
        summary = ai_assistant.get_incident_summary()
        print(f"\nIncident Summary: {summary['total_incidents']} total, {summary['recent_incidents']} recent")

        return 0

    except Exception as e:
        logger.error(f"Incident response failed: {e}")
        return 1

if __name__ == "__main__":
    exit(main())