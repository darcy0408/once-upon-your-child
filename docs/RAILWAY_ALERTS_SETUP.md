# Railway Alerts Configuration Guide

## 🚨 Setting Up Production Alerts

Railway alerts must be configured through the Railway dashboard. Here's how to set them up:

### 1. Access Railway Dashboard
1. Go to your Railway project dashboard
2. Navigate to your backend service
3. Click on "Settings" → "Alerts"

### 2. Configure Alert Rules

#### Backend Downtime Alert
- **Trigger**: Service is down
- **Threshold**: >5 minutes
- **Channels**: Email + Slack/Discord webhooks
- **Message**: "🚨 Story Weaver Backend is DOWN"

#### High Error Rate Alert
- **Trigger**: Error rate exceeds threshold
- **Threshold**: >5% of requests
- **Channels**: Email + Slack
- **Message**: "⚠️ High error rate detected: {error_rate}%"

#### Slow Response Time Alert
- **Trigger**: Average response time
- **Threshold**: >10 seconds
- **Channels**: Email
- **Message**: "🐌 Slow response times: {avg_time}s average"

#### Memory Usage Alert
- **Trigger**: Memory usage
- **Threshold**: >80%
- **Channels**: Email + Slack
- **Message**: "💾 High memory usage: {usage}%"

### 3. Webhook Configuration

#### Slack Webhook Setup
1. Go to Slack → Apps → Incoming Webhooks
2. Create new webhook for your channel
3. Copy webhook URL to Railway environment variables:
   ```
   SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
   ```

#### Discord Webhook Setup
1. Go to Discord channel settings → Integrations → Webhooks
2. Create new webhook
3. Copy webhook URL to Railway environment variables:
   ```
   DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/YOUR/WEBHOOK/ID
   ```

### 4. Environment Variables

Add these to your Railway service environment variables:

```bash
# Alert Configuration
ALERT_EMAIL=alerts@storyweaver.com
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...

# Report Configuration
REPORT_EMAIL=reports@storyweaver.com
```

### 5. Testing Alerts

To test your alert configuration:

1. **Downtime Test**: Temporarily stop your Railway service
2. **Error Test**: Make requests that trigger 500 errors
3. **Performance Test**: Simulate slow responses

### 6. Alert Response Procedures

#### Backend Down
1. Check Railway dashboard for service status
2. Review recent deployments for issues
3. Check Railway logs for error details
4. Restart service if needed
5. Investigate root cause

#### High Error Rate
1. Check backend logs for error patterns
2. Review recent code changes
3. Monitor API quota usage
4. Scale resources if needed

#### Slow Responses
1. Check database query performance
2. Review API response times
3. Monitor memory usage
4. Consider caching optimizations

### 7. Monitoring Scripts

The following monitoring scripts are available in the `monitoring/` directory:

- `uptime_monitor.py`: Continuous health monitoring with alerts
- `weekly_report.py`: Automated weekly performance reports

To run these on Railway:

1. Add as cron jobs in your deployment
2. Or run as background processes
3. Configure appropriate environment variables

### 8. Alert Maintenance

- **Review weekly**: Check alert effectiveness
- **Update thresholds**: Adjust based on normal operating ranges
- **Test regularly**: Ensure alert channels are working
- **Document incidents**: Track false positives and improvements

---

**Note**: Railway alerts are configured per service in their web dashboard. The toml file controls deployment settings but not alerting rules.</content>
<parameter name="filePath">/mnt/c/dev/story-weaver-app/docs/RAILWAY_ALERTS_SETUP.md