import requests
import time
import smtplib
from email.mime.text import MIMEText

BACKEND_URL = "https://story-weaver-app-production.up.railway.app"
CHECK_INTERVAL = 300  # 5 minutes
ALERT_EMAIL = "alerts@storyweaver.com"

def check_health():
    try:
        response = requests.get(f"{BACKEND_URL}/health/detailed", timeout=10)
        return response.status_code == 200, response.json()
    except Exception as e:
        return False, {'error': str(e)}

def send_alert(message):
    # Implement email alert
    # For now, just print - in production, configure SMTP
    print(f"ALERT: {message}")

def monitor():
    failures = 0
    while True:
        is_healthy, details = check_health()

        if not is_healthy:
            failures += 1
            if failures >= 3:  # Alert after 3 consecutive failures
                send_alert(f"Backend unhealthy: {details}")
        else:
            failures = 0

        time.sleep(CHECK_INTERVAL)

if __name__ == '__main__':
    monitor()</content>
<parameter name="filePath">/mnt/c/dev/story-weaver-app/monitoring/uptime_monitor.py