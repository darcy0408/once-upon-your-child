#!/usr/bin/env python3
"""
GDPR Compliance Engine for Story Weaver
Automated data subject rights fulfillment and compliance management
"""

import os
import json
import logging
import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
from collections import defaultdict
import re
import csv
import io

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class GDPRComplianceEngine:
    def __init__(self):
        self.data_processing_activities = self._load_data_processing_activities()
        self.consent_records = defaultdict(dict)
        self.data_subject_requests = []
        self.audit_trail = []

        # GDPR retention periods (in days)
        self.retention_periods = {
            'user_account_data': 2555,  # 7 years
            'therapeutic_sessions': 2555,  # 7 years
            'analytics_data': 730,  # 2 years
            'log_data': 2555,  # 7 years
            'consent_records': 2555,  # 7 years
            'marketing_data': 1095,  # 3 years
        }

        # Data categories requiring special protection
        self.special_categories = [
            'health_data', 'religious_beliefs', 'racial_origin',
            'political_opinions', 'sexual_orientation', 'genetic_data'
        ]

    def _load_data_processing_activities(self) -> Dict[str, Any]:
        """Load data processing activities register"""
        return {
            'user_registration': {
                'purpose': 'User account management and authentication',
                'legal_basis': 'contract_performance',
                'data_categories': ['personal_data', 'contact_data'],
                'retention_period': 2555,
                'data_recipients': ['internal_systems'],
                'international_transfers': False
            },
            'therapeutic_services': {
                'purpose': 'Providing therapeutic story services',
                'legal_basis': 'legitimate_interest',
                'data_categories': ['personal_data', 'health_data', 'usage_data'],
                'retention_period': 2555,
                'data_recipients': ['internal_systems', 'ai_providers'],
                'international_transfers': True
            },
            'analytics_tracking': {
                'purpose': 'Service improvement and analytics',
                'legal_basis': 'consent',
                'data_categories': ['usage_data', 'technical_data'],
                'retention_period': 730,
                'data_recipients': ['analytics_providers'],
                'international_transfers': True
            },
            'marketing_communications': {
                'purpose': 'Marketing and promotional communications',
                'legal_basis': 'consent',
                'data_categories': ['contact_data', 'marketing_preferences'],
                'retention_period': 1095,
                'data_recipients': ['email_providers'],
                'international_transfers': False
            }
        }

    def record_consent(self, user_id: str, consent_type: str, consent_given: bool,
                      consent_details: Dict[str, Any] = None) -> str:
        """Record user consent for data processing"""
        consent_id = f"consent_{user_id}_{consent_type}_{int(datetime.utcnow().timestamp())}"

        consent_record = {
            'consent_id': consent_id,
            'user_id': user_id,
            'consent_type': consent_type,
            'consent_given': consent_given,
            'timestamp': datetime.utcnow().isoformat(),
            'ip_address': consent_details.get('ip_address') if consent_details else None,
            'user_agent': consent_details.get('user_agent') if consent_details else None,
            'consent_text_version': consent_details.get('consent_text_version', '1.0') if consent_details else '1.0',
            'withdrawal_date': None,
            'withdrawn': False
        }

        self.consent_records[user_id][consent_type] = consent_record

        # Log audit event
        self._log_audit_event('consent_recorded', {
            'user_id': user_id,
            'consent_type': consent_type,
            'consent_given': consent_given,
            'consent_id': consent_id
        })

        logger.info(f"Consent recorded for user {user_id}: {consent_type} = {consent_given}")
        return consent_id

    def withdraw_consent(self, user_id: str, consent_type: str) -> bool:
        """Withdraw user consent for data processing"""
        if user_id in self.consent_records and consent_type in self.consent_records[user_id]:
            consent_record = self.consent_records[user_id][consent_type]
            if not consent_record['withdrawn']:
                consent_record['withdrawn'] = True
                consent_record['withdrawal_date'] = datetime.utcnow().isoformat()

                # Log audit event
                self._log_audit_event('consent_withdrawn', {
                    'user_id': user_id,
                    'consent_type': consent_type,
                    'consent_id': consent_record['consent_id']
                })

                logger.info(f"Consent withdrawn for user {user_id}: {consent_type}")
                return True

        return False

    def check_consent(self, user_id: str, consent_type: str) -> bool:
        """Check if user has given consent for specific processing"""
        if user_id in self.consent_records and consent_type in self.consent_records[user_id]:
            consent_record = self.consent_records[user_id][consent_type]
            return consent_record['consent_given'] and not consent_record['withdrawn']

        return False

    def submit_data_subject_request(self, user_id: str, request_type: str,
                                  request_details: Dict[str, Any] = None) -> str:
        """Submit a data subject access request (DSAR)"""
        request_id = f"dsar_{user_id}_{request_type}_{int(datetime.utcnow().timestamp())}"

        dsar_request = {
            'request_id': request_id,
            'user_id': user_id,
            'request_type': request_type,  # 'access', 'rectification', 'erasure', 'restriction', 'portability', 'objection'
            'status': 'pending',
            'submitted_at': datetime.utcnow().isoformat(),
            'completed_at': None,
            'request_details': request_details or {},
            'response_data': None,
            'rejection_reason': None,
            'processing_deadline': (datetime.utcnow() + timedelta(days=30)).isoformat()  # GDPR 30-day deadline
        }

        self.data_subject_requests.append(dsar_request)

        # Log audit event
        self._log_audit_event('dsar_submitted', {
            'user_id': user_id,
            'request_type': request_type,
            'request_id': request_id
        })

        logger.info(f"DSAR submitted: {request_type} for user {user_id}")
        return request_id

    def process_data_subject_request(self, request_id: str, action_result: Dict[str, Any]) -> bool:
        """Process and complete a data subject request"""
        for request in self.data_subject_requests:
            if request['request_id'] == request_id and request['status'] == 'pending':
                request['status'] = 'completed'
                request['completed_at'] = datetime.utcnow().isoformat()
                request['response_data'] = action_result.get('data')
                request['rejection_reason'] = action_result.get('rejection_reason')

                # Log audit event
                self._log_audit_event('dsar_processed', {
                    'request_id': request_id,
                    'user_id': request['user_id'],
                    'request_type': request['request_type'],
                    'status': 'completed'
                })

                logger.info(f"DSAR processed: {request_id}")
                return True

        return False

    def get_data_subject_data(self, user_id: str) -> Dict[str, Any]:
        """Retrieve all data held about a data subject (Article 15)"""
        # In a real implementation, this would query all data stores
        # For now, simulate data collection

        user_data = {
            'personal_data': {
                'user_id': user_id,
                'registration_date': '2024-01-15T10:30:00Z',
                'last_login': '2024-12-01T14:20:00Z',
                'account_status': 'active'
            },
            'therapeutic_data': {
                'sessions_count': 45,
                'stories_generated': 23,
                'feelings_explored': ['anxious', 'happy', 'frustrated', 'calm'],
                'last_session': '2024-11-28T16:45:00Z'
            },
            'usage_data': {
                'total_requests': 1250,
                'avg_session_duration': 12.5,
                'preferred_themes': ['friendship', 'adventure', 'family'],
                'device_types': ['mobile', 'desktop']
            },
            'consent_records': self.consent_records.get(user_id, {}),
            'data_processing_activities': self._get_user_processing_activities(user_id)
        }

        return user_data

    def _get_user_processing_activities(self, user_id: str) -> List[Dict[str, Any]]:
        """Get data processing activities that apply to the user"""
        activities = []

        for activity_name, activity_details in self.data_processing_activities.items():
            # Check if user has consented to this activity
            consent_required = activity_details['legal_basis'] == 'consent'
            has_consent = not consent_required or self.check_consent(user_id, activity_name)

            activities.append({
                'activity': activity_name,
                'purpose': activity_details['purpose'],
                'legal_basis': activity_details['legal_basis'],
                'consent_given': has_consent,
                'data_categories': activity_details['data_categories'],
                'retention_period_days': activity_details['retention_period'],
                'data_recipients': activity_details['data_recipients']
            })

        return activities

    def delete_user_data(self, user_id: str) -> Dict[str, Any]:
        """Delete all user data (Right to Erasure - Article 17)"""
        deletion_result = {
            'user_id': user_id,
            'deletion_timestamp': datetime.utcnow().isoformat(),
            'data_deleted': [],
            'data_retained': [],
            'reasons_for_retention': []
        }

        # In a real implementation, this would delete from all data stores
        # For now, simulate deletion

        # Delete user account data
        deletion_result['data_deleted'].extend([
            'user_profile',
            'authentication_data',
            'session_data'
        ])

        # Check for data that must be retained
        if self._has_legal_retention_requirement(user_id):
            deletion_result['data_retained'].extend([
                'billing_records',
                'legal_compliance_logs'
            ])
            deletion_result['reasons_for_retention'].append(
                'Legal retention requirements for billing and compliance'
            )

        # Anonymize therapeutic data instead of deleting
        deletion_result['data_retained'].append('anonymized_therapeutic_data')
        deletion_result['reasons_for_retention'].append(
            'Therapeutic data anonymized for research and service improvement'
        )

        # Log audit event
        self._log_audit_event('data_erasure', {
            'user_id': user_id,
            'data_deleted': deletion_result['data_deleted'],
            'data_retained': deletion_result['data_retained']
        })

        logger.info(f"Data erasure completed for user {user_id}")
        return deletion_result

    def _has_legal_retention_requirement(self, user_id: str) -> bool:
        """Check if user has legal retention requirements"""
        # Check for billing records, legal disputes, etc.
        # For now, simulate based on user ID
        return int(user_id.split('_')[-1]) % 5 == 0  # 20% of users have retention requirements

    def export_user_data(self, user_id: str, format_type: str = 'json') -> str:
        """Export user data in portable format (Article 20)"""
        user_data = self.get_data_subject_data(user_id)

        if format_type == 'json':
            return json.dumps(user_data, indent=2, default=str)
        elif format_type == 'csv':
            return self._convert_to_csv(user_data)
        else:
            raise ValueError(f"Unsupported export format: {format_type}")

    def _convert_to_csv(self, data: Dict[str, Any]) -> str:
        """Convert user data to CSV format"""
        output = io.StringIO()
        writer = csv.writer(output)

        # Write personal data
        writer.writerow(['Section', 'Field', 'Value'])
        writer.writerow(['Personal Data', 'User ID', data['personal_data']['user_id']])
        writer.writerow(['Personal Data', 'Registration Date', data['personal_data']['registration_date']])

        # Write therapeutic data
        writer.writerow(['Therapeutic Data', 'Sessions Count', data['therapeutic_data']['sessions_count']])
        writer.writerow(['Therapeutic Data', 'Stories Generated', data['therapeutic_data']['stories_generated']])

        return output.getvalue()

    def restrict_data_processing(self, user_id: str, restriction_type: str) -> bool:
        """Restrict data processing (Article 18)"""
        # Implement processing restrictions
        # This would mark user data as restricted in all systems

        self._log_audit_event('processing_restricted', {
            'user_id': user_id,
            'restriction_type': restriction_type
        })

        logger.info(f"Data processing restricted for user {user_id}: {restriction_type}")
        return True

    def object_to_processing(self, user_id: str, processing_type: str) -> bool:
        """Handle objection to data processing (Article 21)"""
        # Withdraw consent for specific processing
        success = self.withdraw_consent(user_id, processing_type)

        if success:
            self._log_audit_event('processing_objection', {
                'user_id': user_id,
                'processing_type': processing_type
            })

            logger.info(f"Processing objection recorded for user {user_id}: {processing_type}")

        return success

    def get_compliance_report(self) -> Dict[str, Any]:
        """Generate GDPR compliance report"""
        report = {
            'generated_at': datetime.utcnow().isoformat(),
            'compliance_status': 'compliant',  # Assume compliant for demo
            'data_processing_register': self.data_processing_activities,
            'consent_statistics': self._calculate_consent_statistics(),
            'dsar_statistics': self._calculate_dsar_statistics(),
            'data_retention_compliance': self._check_retention_compliance(),
            'international_transfer_audit': self._audit_international_transfers(),
            'recommendations': self._generate_compliance_recommendations()
        }

        return report

    def _calculate_consent_statistics(self) -> Dict[str, Any]:
        """Calculate consent-related statistics"""
        total_users = len(self.consent_records)
        consent_by_type = defaultdict(int)

        for user_consents in self.consent_records.values():
            for consent_type, consent_record in user_consents.items():
                if consent_record['consent_given'] and not consent_record['withdrawn']:
                    consent_by_type[consent_type] += 1

        return {
            'total_users_with_consent_records': total_users,
            'consent_rates_by_type': dict(consent_by_type),
            'average_consents_per_user': sum(len(consents) for consents in self.consent_records.values()) / total_users if total_users > 0 else 0
        }

    def _calculate_dsar_statistics(self) -> Dict[str, Any]:
        """Calculate DSAR statistics"""
        total_requests = len(self.data_subject_requests)
        completed_requests = sum(1 for req in self.data_subject_requests if req['status'] == 'completed')
        pending_requests = sum(1 for req in self.data_subject_requests if req['status'] == 'pending')

        # Check for overdue requests
        overdue_requests = 0
        for request in self.data_subject_requests:
            if request['status'] == 'pending':
                deadline = datetime.fromisoformat(request['processing_deadline'])
                if datetime.utcnow() > deadline:
                    overdue_requests += 1

        return {
            'total_requests': total_requests,
            'completed_requests': completed_requests,
            'pending_requests': pending_requests,
            'completion_rate': completed_requests / total_requests if total_requests > 0 else 0,
            'overdue_requests': overdue_requests,
            'average_processing_time_days': self._calculate_avg_processing_time()
        }

    def _calculate_avg_processing_time(self) -> float:
        """Calculate average DSAR processing time"""
        processing_times = []

        for request in self.data_subject_requests:
            if request['status'] == 'completed' and request['completed_at']:
                submitted = datetime.fromisoformat(request['submitted_at'])
                completed = datetime.fromisoformat(request['completed_at'])
                processing_time = (completed - submitted).total_seconds() / (24 * 3600)  # days
                processing_times.append(processing_time)

        return sum(processing_times) / len(processing_times) if processing_times else 0

    def _check_retention_compliance(self) -> Dict[str, Any]:
        """Check data retention compliance"""
        # In a real implementation, this would scan all data stores
        # For now, simulate compliance check

        compliance_status = {
            'overall_compliant': True,
            'data_categories_checked': list(self.retention_periods.keys()),
            'retention_violations': 0,
            'oldest_data_age_days': 365,  # Simulate oldest data is 1 year old
            'recommendations': []
        }

        # Check if any data exceeds retention periods
        for category, retention_days in self.retention_periods.items():
            if compliance_status['oldest_data_age_days'] > retention_days:
                compliance_status['retention_violations'] += 1
                compliance_status['overall_compliant'] = False
                compliance_status['recommendations'].append(
                    f"Review {category} data retention - exceeds {retention_days} day limit"
                )

        return compliance_status

    def _audit_international_transfers(self) -> Dict[str, Any]:
        """Audit international data transfers"""
        transfers = []

        for activity_name, activity in self.data_processing_activities.items():
            if activity['international_transfers']:
                transfers.append({
                    'activity': activity_name,
                    'recipients': activity['data_recipients'],
                    'adequacy_decision': 'EU-US Privacy Shield',  # Example
                    'safeguards': ['Standard Contractual Clauses', 'Encryption']
                })

        return {
            'international_transfers_count': len(transfers),
            'transfers': transfers,
            'compliance_status': 'compliant' if all(t.get('adequacy_decision') for t in transfers) else 'review_required'
        }

    def _generate_compliance_recommendations(self) -> List[str]:
        """Generate GDPR compliance recommendations"""
        recommendations = []

        # Check DSAR processing times
        dsar_stats = self._calculate_dsar_statistics()
        if dsar_stats['average_processing_time_days'] > 15:
            recommendations.append("Improve DSAR processing efficiency - current average exceeds 15 days")

        # Check consent rates
        consent_stats = self._calculate_consent_statistics()
        for consent_type, count in consent_stats.get('consent_rates_by_type', {}).items():
            total_users = consent_stats['total_users_with_consent_records']
            if total_users > 0 and (count / total_users) < 0.8:
                recommendations.append(f"Increase consent rate for {consent_type} - currently below 80%")

        # General recommendations
        recommendations.extend([
            "Conduct regular data protection impact assessments",
            "Implement automated data discovery and classification",
            "Establish data breach notification procedures",
            "Train staff on GDPR compliance requirements"
        ])

        return recommendations

    def _log_audit_event(self, event_type: str, details: Dict[str, Any]):
        """Log GDPR audit events"""
        audit_event = {
            'timestamp': datetime.utcnow().isoformat(),
            'event_type': event_type,
            'details': details,
            'gdpr_article': self._get_gdpr_article(event_type)
        }

        self.audit_trail.append(audit_event)

        # Keep only last 5000 audit events
        if len(self.audit_trail) > 5000:
            self.audit_trail = self.audit_trail[-2500:]

    def _get_gdpr_article(self, event_type: str) -> Optional[str]:
        """Get GDPR article reference for event type"""
        article_map = {
            'consent_recorded': 'Article 7',
            'consent_withdrawn': 'Article 7',
            'dsar_submitted': 'Articles 15-21',
            'dsar_processed': 'Articles 15-21',
            'data_erasure': 'Article 17',
            'processing_restricted': 'Article 18',
            'processing_objection': 'Article 21'
        }

        return article_map.get(event_type)

def main():
    """Main GDPR compliance execution"""
    try:
        gdpr_engine = GDPRComplianceEngine()

        # Simulate GDPR operations
        user_id = "user_123"

        # Record consent
        consent_id = gdpr_engine.record_consent(
            user_id=user_id,
            consent_type='therapeutic_services',
            consent_given=True,
            consent_details={
                'ip_address': '192.168.1.100',
                'user_agent': 'Story Weaver App v1.0',
                'consent_text_version': '2.1'
            }
        )

        # Submit DSAR
        dsar_id = gdpr_engine.submit_data_subject_request(
            user_id=user_id,
            request_type='access',
            request_details={'request_reason': 'Annual review'}
        )

        # Process DSAR
        user_data = gdpr_engine.get_data_subject_data(user_id)
        gdpr_engine.process_data_subject_request(dsar_id, {'data': user_data})

        # Export data
        exported_data = gdpr_engine.export_user_data(user_id, 'json')

        # Generate compliance report
        compliance_report = gdpr_engine.get_compliance_report()

        print("=== GDPR Compliance Engine Demo ===")

        print(f"Consent recorded: {consent_id}")
        print(f"DSAR submitted: {dsar_id}")
        print(f"DSAR processed successfully")

        print(f"\nUser Data Export (first 200 chars):")
        print(exported_data[:200] + "...")

        print(f"\nCompliance Report:")
        print(f"  Status: {compliance_report['compliance_status']}")
        print(f"  DSAR Completion Rate: {compliance_report['dsar_statistics']['completion_rate']:.1%}")
        print(f"  Consent Records: {compliance_report['consent_statistics']['total_users_with_consent_records']}")

        print(f"\nTop Recommendations:")
        for rec in compliance_report['recommendations'][:3]:
            print(f"  • {rec}")

        return 0

    except Exception as e:
        logger.error(f"GDPR compliance failed: {e}")
        return 1

if __name__ == "__main__":
    exit(main())