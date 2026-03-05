#!/usr/bin/env python3
"""
Data Protection Layer for Story Weaver
Enhanced encryption, data classification, and secure data handling
"""

import os
import json
import base64
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import hashlib
import secrets

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class DataProtectionLayer:
    def __init__(self):
        self.encryption_keys = self._load_encryption_keys()
        self.data_classification = self._load_data_classification_rules()
        self.backup_encryption_enabled = True
        self.field_level_encryption = True

        # Data residency rules (GDPR compliance)
        self.data_residency_rules = {
            'EU': ['germany', 'france', 'uk', 'ireland'],
            'US': ['us-east-1', 'us-west-2'],
            'global': ['*']  # Allow global for non-sensitive data
        }

    def _load_encryption_keys(self) -> Dict[str, bytes]:
        """Load or generate encryption keys"""
        keys = {}

        # Master encryption key
        master_key_file = "/etc/story-weaver/keys/master.key"
        if os.path.exists(master_key_file):
            with open(master_key_file, 'rb') as f:
                keys['master'] = f.read()
        else:
            # Generate new master key
            keys['master'] = Fernet.generate_key()
            os.makedirs(os.path.dirname(master_key_file), exist_ok=True)
            with open(master_key_file, 'wb') as f:
                f.write(keys['master'])

        # Field-specific keys for different data types
        key_types = ['personal', 'health', 'financial', 'session']
        for key_type in key_types:
            key_file = f"/etc/story-weaver/keys/{key_type}.key"
            if os.path.exists(key_file):
                with open(key_file, 'rb') as f:
                    keys[key_type] = f.read()
            else:
                keys[key_type] = Fernet.generate_key()
                os.makedirs(os.path.dirname(key_file), exist_ok=True)
                with open(key_file, 'wb') as f:
                    f.write(keys[key_type])

        return keys

    def _load_data_classification_rules(self) -> Dict[str, Any]:
        """Load data classification and handling rules"""
        return {
            'personal_data': {
                'sensitivity': 'high',
                'encryption_required': True,
                'retention_days': 2555,  # 7 years
                'access_logging': True,
                'backup_required': True,
                'data_residency': 'EU'
            },
            'health_data': {
                'sensitivity': 'critical',
                'encryption_required': True,
                'retention_days': 2555,
                'access_logging': True,
                'backup_required': True,
                'special_category': True,
                'data_residency': 'EU'
            },
            'usage_data': {
                'sensitivity': 'medium',
                'encryption_required': False,
                'retention_days': 730,  # 2 years
                'access_logging': False,
                'backup_required': True,
                'data_residency': 'global'
            },
            'session_data': {
                'sensitivity': 'medium',
                'encryption_required': True,
                'retention_days': 90,  # 90 days
                'access_logging': False,
                'backup_required': False,
                'data_residency': 'global'
            },
            'financial_data': {
                'sensitivity': 'critical',
                'encryption_required': True,
                'retention_days': 2555,
                'access_logging': True,
                'backup_required': True,
                'data_residency': 'EU'
            }
        }

    def encrypt_data(self, data: str, data_type: str = 'personal') -> str:
        """Encrypt data using appropriate key for data type"""
        if not isinstance(data, str):
            data = json.dumps(data)

        key = self.encryption_keys.get(data_type, self.encryption_keys['master'])
        fernet = Fernet(key)

        encrypted = fernet.encrypt(data.encode('utf-8'))
        return base64.b64encode(encrypted).decode('utf-8')

    def decrypt_data(self, encrypted_data: str, data_type: str = 'personal') -> str:
        """Decrypt data using appropriate key"""
        try:
            key = self.encryption_keys.get(data_type, self.encryption_keys['master'])
            fernet = Fernet(key)

            encrypted = base64.b64decode(encrypted_data.encode('utf-8'))
            decrypted = fernet.decrypt(encrypted)

            return decrypted.decode('utf-8')
        except Exception as e:
            logger.error(f"Decryption failed: {e}")
            raise

    def classify_data(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Automatically classify data based on content and context"""
        classification = {
            'data_types': [],
            'sensitivity_level': 'low',
            'encryption_required': False,
            'retention_policy': 'standard',
            'access_restrictions': [],
            'compliance_requirements': []
        }

        # Analyze data content
        data_str = json.dumps(data).lower()

        # Check for sensitive data patterns
        sensitive_patterns = {
            'personal_data': ['email', 'phone', 'address', 'name', 'birthdate'],
            'health_data': ['diagnosis', 'treatment', 'medication', 'therapy', 'mental'],
            'financial_data': ['credit', 'payment', 'billing', 'subscription', 'cost']
        }

        for data_type, patterns in sensitive_patterns.items():
            if any(pattern in data_str for pattern in patterns):
                classification['data_types'].append(data_type)

                # Apply classification rules
                rules = self.data_classification.get(data_type, {})
                if rules.get('sensitivity') == 'critical':
                    classification['sensitivity_level'] = 'critical'
                elif rules.get('sensitivity') == 'high' and classification['sensitivity_level'] != 'critical':
                    classification['sensitivity_level'] = 'high'
                elif rules.get('sensitivity') == 'medium' and classification['sensitivity_level'] not in ['high', 'critical']:
                    classification['sensitivity_level'] = 'medium'

                if rules.get('encryption_required'):
                    classification['encryption_required'] = True

                if rules.get('access_logging'):
                    classification['access_restrictions'].append('access_logging_required')

                if rules.get('special_category'):
                    classification['compliance_requirements'].append('gdpr_special_category')

        return classification

    def secure_field_encryption(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Apply field-level encryption to sensitive data"""
        if not self.field_level_encryption:
            return data

        encrypted_data = data.copy()

        # Fields that require encryption
        sensitive_fields = {
            'email': 'personal',
            'phone': 'personal',
            'address': 'personal',
            'diagnosis': 'health',
            'treatment_notes': 'health',
            'credit_card': 'financial',
            'billing_address': 'financial'
        }

        for field, data_type in sensitive_fields.items():
            if field in encrypted_data and encrypted_data[field]:
                encrypted_data[field] = self.encrypt_data(str(encrypted_data[field]), data_type)

        return encrypted_data

    def secure_field_decryption(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Decrypt field-level encrypted data"""
        decrypted_data = data.copy()

        # Fields that may be encrypted
        encrypted_fields = ['email', 'phone', 'address', 'diagnosis', 'treatment_notes', 'credit_card', 'billing_address']

        for field in encrypted_fields:
            if field in decrypted_data and decrypted_data[field]:
                try:
                    # Try to decrypt - if it fails, assume it's not encrypted
                    decrypted_data[field] = self.decrypt_data(decrypted_data[field])
                except:
                    # Field is not encrypted, keep as-is
                    pass

        return decrypted_data

    def create_secure_backup(self, data: Dict[str, Any], backup_type: str = 'full') -> Dict[str, Any]:
        """Create encrypted backup of data"""
        if not self.backup_encryption_enabled:
            return data

        backup = {
            'backup_metadata': {
                'timestamp': datetime.utcnow().isoformat(),
                'type': backup_type,
                'version': '1.0',
                'encryption': 'fernet',
                'data_classification': self.classify_data(data)
            },
            'data': {}
        }

        # Encrypt sensitive data in backup
        for key, value in data.items():
            if isinstance(value, (str, int, float, bool)):
                # Encrypt all string data in backups
                backup['data'][key] = self.encrypt_data(str(value), 'personal')
            else:
                # For complex data, encrypt as JSON
                backup['data'][key] = self.encrypt_data(json.dumps(value), 'personal')

        return backup

    def restore_from_backup(self, backup: Dict[str, Any]) -> Dict[str, Any]:
        """Restore data from encrypted backup"""
        restored_data = {}

        for key, encrypted_value in backup.get('data', {}).items():
            try:
                decrypted_value = self.decrypt_data(encrypted_value, 'personal')

                # Try to parse as JSON, otherwise keep as string
                try:
                    restored_data[key] = json.loads(decrypted_value)
                except json.JSONDecodeError:
                    restored_data[key] = decrypted_value

            except Exception as e:
                logger.error(f"Failed to decrypt backup field {key}: {e}")
                restored_data[key] = None

        return restored_data

    def check_data_residency_compliance(self, data_location: str, data_type: str) -> bool:
        """Check if data storage location complies with residency requirements"""
        rules = self.data_classification.get(data_type, {})
        required_residency = rules.get('data_residency', 'global')

        if required_residency == 'global':
            return True

        allowed_locations = self.data_residency_rules.get(required_residency, [])
        if '*' in allowed_locations:
            return True

        return data_location.lower() in [loc.lower() for loc in allowed_locations]

    def generate_data_inventory(self) -> Dict[str, Any]:
        """Generate comprehensive data inventory for compliance"""
        # In a real implementation, this would scan all data stores
        # For now, simulate based on known data types

        inventory = {
            'generated_at': datetime.utcnow().isoformat(),
            'data_categories': {},
            'total_records': 0,
            'encryption_status': {},
            'retention_compliance': {},
            'access_patterns': {}
        }

        for data_type, rules in self.data_classification.items():
            inventory['data_categories'][data_type] = {
                'estimated_records': self._estimate_records_for_type(data_type),
                'sensitivity_level': rules['sensitivity'],
                'encryption_required': rules['encryption_required'],
                'retention_days': rules['retention_days'],
                'data_residency': rules.get('data_residency', 'global'),
                'special_category': rules.get('special_category', False)
            }

            inventory['total_records'] += inventory['data_categories'][data_type]['estimated_records']

        # Check encryption status
        inventory['encryption_status'] = {
            'field_level_encryption': self.field_level_encryption,
            'backup_encryption': self.backup_encryption_enabled,
            'encryption_keys_status': 'loaded' if self.encryption_keys else 'missing'
        }

        return inventory

    def _estimate_records_for_type(self, data_type: str) -> int:
        """Estimate number of records for a data type"""
        # In production, this would query actual databases
        estimates = {
            'personal_data': 50000,
            'health_data': 25000,
            'usage_data': 1000000,
            'session_data': 500000,
            'financial_data': 10000
        }
        return estimates.get(data_type, 0)

    def rotate_encryption_keys(self) -> Dict[str, Any]:
        """Rotate encryption keys for enhanced security"""
        rotation_report = {
            'timestamp': datetime.utcnow().isoformat(),
            'keys_rotated': [],
            'old_keys_backed_up': True,
            'affected_data_types': []
        }

        # Rotate each key type
        for key_type in self.encryption_keys.keys():
            old_key = self.encryption_keys[key_type]
            new_key = Fernet.generate_key()

            # Backup old key (in production, this would be securely stored)
            backup_file = f"/etc/story-weaver/keys/{key_type}_old_{int(datetime.utcnow().timestamp())}.key"
            os.makedirs(os.path.dirname(backup_file), exist_ok=True)
            with open(backup_file, 'wb') as f:
                f.write(old_key)

            # Update to new key
            self.encryption_keys[key_type] = new_key

            # Save new key
            key_file = f"/etc/story-weaver/keys/{key_type}.key"
            with open(key_file, 'wb') as f:
                f.write(new_key)

            rotation_report['keys_rotated'].append(key_type)
            rotation_report['affected_data_types'].append(key_type)

        logger.info(f"Rotated {len(rotation_report['keys_rotated'])} encryption keys")
        return rotation_report

    def audit_data_access(self, user_id: str, data_type: str, action: str,
                         ip_address: str = None, user_agent: str = None) -> None:
        """Audit data access for compliance"""
        audit_entry = {
            'timestamp': datetime.utcnow().isoformat(),
            'user_id': user_id,
            'data_type': data_type,
            'action': action,
            'ip_address': ip_address,
            'user_agent': user_agent,
            'compliance_relevant': self._is_compliance_relevant(data_type, action)
        }

        # In production, this would be written to a secure audit log
        logger.info(f"AUDIT: {user_id} {action} {data_type} from {ip_address}")

    def _is_compliance_relevant(self, data_type: str, action: str) -> bool:
        """Check if data access is compliance-relevant"""
        compliance_actions = ['access', 'modify', 'delete', 'export']
        sensitive_types = ['personal_data', 'health_data', 'financial_data']

        return action in compliance_actions and data_type in sensitive_types

    def get_security_health_check(self) -> Dict[str, Any]:
        """Perform security health check"""
        health_check = {
            'timestamp': datetime.utcnow().isoformat(),
            'encryption_status': 'healthy' if self.encryption_keys else 'critical',
            'key_rotation_status': self._check_key_rotation_status(),
            'data_classification': 'configured' if self.data_classification else 'missing',
            'backup_encryption': 'enabled' if self.backup_encryption_enabled else 'disabled',
            'field_encryption': 'enabled' if self.field_level_encryption else 'disabled',
            'overall_security_score': 0
        }

        # Calculate security score
        score = 0
        if self.encryption_keys:
            score += 30
        if self.data_classification:
            score += 20
        if self.backup_encryption_enabled:
            score += 20
        if self.field_level_encryption:
            score += 20
        if self._check_key_rotation_status() == 'current':
            score += 10

        health_check['overall_security_score'] = score

        return health_check

    def _check_key_rotation_status(self) -> str:
        """Check if encryption keys need rotation"""
        # Check key age (rotate every 90 days)
        key_files = [f"/etc/story-weaver/keys/{key_type}.key" for key_type in self.encryption_keys.keys()]

        for key_file in key_files:
            if os.path.exists(key_file):
                key_age_days = (datetime.utcnow() - datetime.fromtimestamp(os.path.getmtime(key_file))).days
                if key_age_days > 90:
                    return 'needs_rotation'

        return 'current'

def main():
    """Main data protection execution"""
    try:
        protector = DataProtectionLayer()

        # Test data classification
        test_data = {
            'email': 'user@example.com',
            'diagnosis': 'anxiety',
            'session_count': 25,
            'last_login': '2024-12-01'
        }

        classification = protector.classify_data(test_data)
        print("=== Data Classification ===")
        print(f"Data Types: {classification['data_types']}")
        print(f"Sensitivity: {classification['sensitivity_level']}")
        print(f"Encryption Required: {classification['encryption_required']}")

        # Test encryption/decryption
        sensitive_data = "This is sensitive health information"
        encrypted = protector.encrypt_data(sensitive_data, 'health')
        decrypted = protector.decrypt_data(encrypted, 'health')

        print(f"\nEncryption Test:")
        print(f"Original: {sensitive_data}")
        print(f"Decrypted: {decrypted}")
        print(f"Encryption successful: {sensitive_data == decrypted}")

        # Test field-level encryption
        user_data = {
            'name': 'John Doe',
            'email': 'john@example.com',
            'diagnosis': 'Generalized Anxiety',
            'session_count': 15
        }

        encrypted_user_data = protector.secure_field_encryption(user_data)
        decrypted_user_data = protector.secure_field_decryption(encrypted_user_data)

        print(f"\nField Encryption Test:")
        print(f"Original email: {user_data['email']}")
        print(f"Encrypted: {encrypted_user_data['email']}")
        print(f"Decrypted: {decrypted_user_data['email']}")

        # Generate data inventory
        inventory = protector.generate_data_inventory()
        print(f"\nData Inventory:")
        print(f"Total Records: {inventory['total_records']}")
        print(f"Data Categories: {len(inventory['data_categories'])}")

        # Security health check
        health_check = protector.get_security_health_check()
        print(f"\nSecurity Health Score: {health_check['overall_security_score']}/100")

        return 0

    except Exception as e:
        logger.error(f"Data protection failed: {e}")
        return 1

if __name__ == "__main__":
    exit(main())