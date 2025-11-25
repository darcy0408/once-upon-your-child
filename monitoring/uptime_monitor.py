import requests
import time
import json
import os
from datetime import datetime, timedelta
from collections import deque
import statistics

BACKEND_URL = "https://story-weaver-app-production.up.railway.app"
CHECK_INTERVAL = 300  # 5 minutes
ALERT_EMAIL = os.getenv('ALERT_EMAIL', 'alerts@storyweaver.com')
SLACK_WEBHOOK_URL = os.getenv('SLACK_WEBHOOK_URL')
DISCORD_WEBHOOK_URL = os.getenv('DISCORD_WEBHOOK_URL')

# Monitoring state
response_times = deque(maxlen=100)  # Keep last 100 response times
error_counts = deque(maxlen=100)    # Keep last 100 error status
uptime_history = []  # Track uptime over time
last_alert_time = {}  # Prevent alert spam

def check_health():
    """Check backend health with detailed metrics"""
    start_time = time.time()

    try:
        # Check main health endpoint
        response = requests.get(f"{BACKEND_URL}/health/detailed", timeout=10)
        response_time = time.time() - start_time

        if response.status_code == 200:
            health_data = response.json()
            return True, {
                'response_time': response_time,
                'status_code': response.status_code,
                'health_data': health_data,
                'timestamp': datetime.utcnow().isoformat()
            }
        else:
            return False, {
                'response_time': response_time,
                'status_code': response.status_code,
                'error': f'HTTP {response.status_code}',
                'timestamp': datetime.utcnow().isoformat()
            }

    except requests.exceptions.Timeout:
        return False, {
            'response_time': 10.0,  # timeout value
            'error': 'Request timeout',
            'timestamp': datetime.utcnow().isoformat()
        }
    except Exception as e:
        response_time = time.time() - start_time
        return False, {
            'response_time': response_time,
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }

def check_database_connection():
    """Check database connectivity"""
    try:
        response = requests.get(f"{BACKEND_URL}/health/database", timeout=5)
        return response.status_code == 200, response.json()
    except Exception as e:
        return False, {'error': str(e)}

def check_api_quota():
    """Check Gemini API quota status (simplified)"""
    # This would require actual API monitoring
    # For now, return mock data
    return True, {'quota_used': 0.3, 'quota_limit': 1000}

def send_alert(message, alert_type='error', details=None):
    """Send alerts via multiple channels"""
    timestamp = datetime.utcnow().isoformat()

    # Prevent alert spam (don't send same alert type within 30 minutes)
    if alert_type in last_alert_time:
        if (datetime.utcnow() - last_alert_time[alert_type]).seconds < 1800:
            return

    last_alert_time[alert_type] = datetime.utcnow()

    alert_data = {
        'message': message,
        'type': alert_type,
        'timestamp': timestamp,
        'details': details or {},
        'service': 'Story Weaver Backend'
    }

    # Print to console
    print(f"[{timestamp}] ALERT [{alert_type.upper()}]: {message}")
    if details:
        print(f"Details: {json.dumps(details, indent=2)}")

    # Send to Slack
    if SLACK_WEBHOOK_URL:
        try:
            slack_payload = {
                'text': f"🚨 *Story Weaver Alert*\n*{alert_type.upper()}*: {message}",
                'attachments': [{
                    'color': 'danger' if alert_type == 'error' else 'warning',
                    'fields': [
                        {'title': 'Timestamp', 'value': timestamp, 'short': True},
                        {'title': 'Service', 'value': 'Backend', 'short': True}
                    ]
                }]
            }
            if details:
                slack_payload['attachments'][0]['fields'].extend([
                    {'title': k, 'value': str(v), 'short': True}
                    for k, v in details.items()
                ])

            requests.post(SLACK_WEBHOOK_URL, json=slack_payload, timeout=5)
        except Exception as e:
            print(f"Failed to send Slack alert: {e}")

    # Send to Discord
    if DISCORD_WEBHOOK_URL:
        try:
            discord_payload = {
                'content': f"🚨 **Story Weaver Alert**\n**{alert_type.upper()}**: {message}\nTimestamp: {timestamp}"
            }
            if details:
                details_str = '\n'.join([f"**{k}**: {v}" for k, v in details.items()])
                discord_payload['content'] += f"\n\n{details_str}"

            requests.post(DISCORD_WEBHOOK_URL, json=discord_payload, timeout=5)
        except Exception as e:
            print(f"Failed to send Discord alert: {e}")

def analyze_metrics():
    """Analyze collected metrics and trigger alerts"""
    if len(response_times) < 10:  # Need minimum data
        return

    # Calculate metrics
    avg_response_time = statistics.mean(response_times)
    error_rate = sum(error_counts) / len(error_counts)

    # Alert conditions
    if avg_response_time > 10.0:  # Slow response time
        send_alert(
            f"Average response time is {avg_response_time:.2f}s (threshold: 10s)",
            'warning',
            {'avg_response_time': avg_response_time, 'sample_size': len(response_times)}
        )

    if error_rate > 0.05:  # High error rate (>5%)
        send_alert(
            f"Error rate is {error_rate:.1%} (threshold: 5%)",
            'error',
            {'error_rate': error_rate, 'sample_size': len(error_counts)}
        )

def monitor():
    """Main monitoring loop"""
    failures = 0
    consecutive_failures = 0

    print(f"Starting Story Weaver backend monitoring...")
    print(f"Backend URL: {BACKEND_URL}")
    print(f"Check interval: {CHECK_INTERVAL} seconds")
    print(f"Slack webhook: {'Configured' if SLACK_WEBHOOK_URL else 'Not configured'}")
    print(f"Discord webhook: {'Configured' if DISCORD_WEBHOOK_URL else 'Not configured'}")
    print("-" * 50)

    while True:
        # Check health
        is_healthy, details = check_health()

        # Record metrics
        response_times.append(details.get('response_time', 0))
        error_counts.append(0 if is_healthy else 1)

        if is_healthy:
            consecutive_failures = 0
            uptime_history.append(True)
            print(f"✅ [{datetime.utcnow().strftime('%H:%M:%S')}] Healthy - {details.get('response_time', 0):.2f}s")
        else:
            consecutive_failures += 1
            uptime_history.append(False)
            print(f"❌ [{datetime.utcnow().strftime('%H:%M:%S')}] Unhealthy - {details.get('error', 'Unknown error')}")

            # Alert on downtime (>3 consecutive failures = 15 minutes)
            if consecutive_failures >= 3:
                send_alert(
                    f"Backend has been down for {consecutive_failures * CHECK_INTERVAL // 60} minutes",
                    'error',
                    details
                )

        # Check database connectivity every 10 checks (50 minutes)
        if len(uptime_history) % 10 == 0:
            db_healthy, db_details = check_database_connection()
            if not db_healthy:
                send_alert(
                    "Database connection issues detected",
                    'error',
                    db_details
                )

        # Analyze metrics every 20 checks (100 minutes)
        if len(response_times) >= 20 and len(response_times) % 20 == 0:
            analyze_metrics()

        # Keep uptime history manageable
        if len(uptime_history) > 1000:
            uptime_history[:] = uptime_history[-500:]

        time.sleep(CHECK_INTERVAL)

if __name__ == '__main__':
    monitor()</content>
