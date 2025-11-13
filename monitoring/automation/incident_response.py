#!/usr/bin/env python3
"""
Story Weaver Incident Response Automation
Handles webhooks from Alertmanager for auto-scaling and rollback
"""

import os
import subprocess
import json
from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

# Configuration
RAILWAY_TOKEN = os.getenv('RAILWAY_TOKEN')
RAILWAY_PROJECT_ID = os.getenv('RAILWAY_PROJECT_ID')
SLACK_WEBHOOK = os.getenv('SLACK_WEBHOOK_URL')

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok"})

@app.route('/scale-up', methods=['POST'])
def scale_up():
    """Handle auto-scaling trigger"""
    data = request.get_json()

    # Log the alert
    app.logger.info(f"Scale-up triggered: {json.dumps(data)}")

    try:
        # Railway CLI commands to scale up
        commands = [
            f"railway login --token {RAILWAY_TOKEN}",
            f"railway link --project {RAILWAY_PROJECT_ID}",
            "railway up --scale web=2"  # Scale to 2 instances
        ]

        for cmd in commands:
            result = subprocess.run(cmd.split(), capture_output=True, text=True)
            if result.returncode != 0:
                raise Exception(f"Command failed: {cmd}, error: {result.stderr}")

        # Notify Slack
        notify_slack("🚀 Auto-scaled up to 2 instances due to high load")

        return jsonify({"status": "scaled_up", "timestamp": datetime.utcnow().isoformat()})

    except Exception as e:
        app.logger.error(f"Scale-up failed: {str(e)}")
        notify_slack(f"❌ Auto-scale up failed: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/rollback', methods=['POST'])
def rollback():
    """Handle automated rollback trigger"""
    data = request.get_json()

    # Log the alert
    app.logger.info(f"Rollback triggered: {json.dumps(data)}")

    try:
        # Get previous deployment
        commands = [
            f"railway login --token {RAILWAY_TOKEN}",
            f"railway link --project {RAILWAY_PROJECT_ID}",
            "railway deploy list --json | jq -r '.[1].id' | xargs railway deploy redeploy"
        ]

        for cmd in commands:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            if result.returncode != 0:
                raise Exception(f"Command failed: {cmd}, error: {result.stderr}")

        # Notify Slack
        notify_slack("🔄 Automated rollback completed due to critical error")

        return jsonify({"status": "rolled_back", "timestamp": datetime.utcnow().isoformat()})

    except Exception as e:
        app.logger.error(f"Rollback failed: {str(e)}")
        notify_slack(f"❌ Automated rollback failed: {str(e)}")
        return jsonify({"error": str(e)}), 500

def notify_slack(message):
    """Send notification to Slack"""
    if not SLACK_WEBHOOK:
        return

    try:
        import requests
        payload = {"text": message}
        requests.post(SLACK_WEBHOOK, json=payload)
    except Exception as e:
        app.logger.error(f"Slack notification failed: {str(e)}")

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', 5000)))