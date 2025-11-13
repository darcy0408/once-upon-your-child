# Story Weaver Production Monitoring Setup

This directory contains the self-hosted monitoring stack for the Story Weaver application.

## Components

- **Prometheus**: Metrics collection and storage
- **Grafana**: Dashboards and visualization
- **Loki**: Log aggregation
- **Promtail**: Log shipping to Loki
- **Alertmanager**: Alert routing and notifications
- **Elasticsearch**: Search and analytics engine
- **Logstash**: Log processing and enrichment
- **Kibana**: Log visualization and exploration

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

3. **Access Services**:
    - **Grafana**: http://localhost:3000 (admin/admin)
    - **Prometheus**: http://localhost:9090
    - **Alertmanager**: http://localhost:9093
    - **Kibana**: http://localhost:5601
    - **Elasticsearch**: http://localhost:9200

4. **Configure Alerts**:
   - Update `alertmanager.yml` with actual Slack webhook and email credentials
   - Alerts are defined in `alert_rules.yml`

## Metrics Available

- API request counts and rates
- Story generation performance (duration, success/failure)
- Business metrics (stories by theme, age group)
- Error rates and response times

## Production Health Dashboard

### Real-time Health Monitoring
- **File**: `monitoring/dashboards/production-health-dashboard.json`
- **Import**: In Grafana, go to Dashboards → Import, upload the JSON file
- **Key Metrics**:
  - System health score and uptime percentage
  - Active users and stories generated (last 24h)
  - Average response time and error rates
  - Database connection pool usage
  - Cache hit rate and performance
  - System resource utilization (CPU, memory, disk)
  - User engagement trends over time
  - Business KPIs (registrations, subscriptions, completion rates)
  - Real-time cost analysis
  - Security alerts and violations

### Automated Maintenance Scripts
- **File**: `monitoring/automated_maintenance.py`
- **Features**:
  - Database cleanup (expired sessions, old stories)
  - Log rotation and compression
  - Cache invalidation and optimization
  - Database performance optimization
  - Automated backup coordination

### Cost Monitoring & Optimization
- **File**: `monitoring/cost_monitor.py`
- **Capabilities**:
  - Real-time cost analysis across all services
  - Budget alerts and threshold monitoring
  - Cost optimization recommendations
  - Infrastructure cost tracking
  - API and storage cost analysis

## GDPR Compliance

- **Automated Compliance Monitoring**: `compliance_monitor.py` provides GDPR compliance checks
- **Data Export**: API endpoints for user data export (Article 15)
- **Right to Erasure**: Data deletion endpoints (Article 17)
- **Data Retention**: 7-year retention policy with automated cleanup
- **Anonymization**: Personal data is anonymized in logs and metrics
- **Consent Management**: Framework for consent tracking (to be implemented)
- **Compliance Reports**: Monthly automated compliance reporting

### GDPR API Endpoints
- `GET /compliance-check` - Run compliance checks
- `GET /data-export/<user_id>` - Export user data
- `DELETE /data-deletion/<user_id>` - Delete user data
- `GET /compliance-report` - Generate compliance report

## Dashboards

### Executive Business Intelligence Dashboard
- **File**: `monitoring/dashboards/executive-dashboard.json`
- **Import**: In Grafana, go to Dashboards → Import, upload the JSON file
- **Metrics**:
  - Total stories generated (30-day sum)
  - Daily active users
  - Stories by age group (pie chart)
  - Therapeutic outcomes - feelings explored
  - User engagement trends (API requests vs stories)
  - Story themes popularity
  - Subscription conversion rate

## Testing

1. Start the monitoring stack
2. Make requests to the backend /metrics endpoint
3. Verify metrics appear in Prometheus
4. Import the executive dashboard in Grafana
5. Test alerts by triggering high error rates

## Railway Deployment

- Update prometheus.yml target to the Railway backend URL
- Ensure /metrics endpoint is accessible
- Set NEW_RELIC_LICENSE_KEY in Railway environment