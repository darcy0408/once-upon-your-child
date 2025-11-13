# Story Weaver Production Monitoring Setup

This directory contains the self-hosted monitoring stack for the Story Weaver application.

## Components

- **Prometheus**: Metrics collection and storage
- **Grafana**: Dashboards and visualization
- **Loki**: Log aggregation
- **Promtail**: Log shipping to Loki
- **Alertmanager**: Alert routing and notifications

## Backend Integration

The backend has been instrumented with:
- New Relic APM for application performance monitoring
- Prometheus client for custom metrics
- Structured logging

## Setup Instructions

1. **Deploy Monitoring Stack**:
   ```bash
   cd monitoring
   docker-compose up -d
   ```

2. **Configure New Relic**:
   - Set `NEW_RELIC_LICENSE_KEY` environment variable in Railway
   - The `newrelic.ini` is configured for production

3. **Access Dashboards**:
   - Grafana: http://localhost:3000 (admin/admin)
   - Prometheus: http://localhost:9090
   - Alertmanager: http://localhost:9093

4. **Configure Alerts**:
   - Update `alertmanager.yml` with actual Slack webhook and email credentials
   - Alerts are defined in `alert_rules.yml`

## Metrics Available

- API request counts and rates
- Story generation performance (duration, success/failure)
- Business metrics (stories by theme, age group)
- Error rates and response times

## GDPR Compliance

- No personal user data is tracked
- Only aggregated, anonymized metrics
- Logs are retained for 30 days

## Testing

1. Start the monitoring stack
2. Make requests to the backend /metrics endpoint
3. Verify metrics appear in Prometheus
4. Create Grafana dashboard with the metrics
5. Test alerts by triggering high error rates

## Railway Deployment

- Update prometheus.yml target to the Railway backend URL
- Ensure /metrics endpoint is accessible
- Set NEW_RELIC_LICENSE_KEY in Railway environment