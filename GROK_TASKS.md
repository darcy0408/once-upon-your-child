# Grok - Backend & Infrastructure Tasks

**Status**: Ready to start
**Priority**: HIGH - Backend reliability and deployment critical

---

## Current Status Summary

### ✅ Completed
- Backend deployed to Railway
- Database health check fixed (SQLAlchemy 2.0 compatibility)
- Interactive story endpoints functional
- Gemini API integration working

### 🔧 Current Issues
- Frontend deployment needs verification
- Build process needs monitoring
- Error handling needs improvement

---

## Task GR1: Monitor and Verify Railway Deployment (Priority: CRITICAL)

**Objective**: Ensure the latest build with fixes deploys successfully to Railway.

### Steps:

1. **Check Railway Build Status**:
   - Go to Railway dashboard: https://railway.app
   - Navigate to grand-light service
   - Check latest deployment (should be triggered by recent push)
   - Look for build logs showing:
     ```
     ✓ Built build/web
     ```

2. **Verify Backend Health**:
   ```bash
   # Test health endpoint
   curl https://story-weaver-backend-production.up.railway.app/health

   # Expected response:
   # {"status": "healthy", "database": "connected"}
   ```

3. **Verify Frontend Accessibility**:
   ```bash
   # Check frontend URL
   curl -I https://grand-light-production-68d9.up.railway.app

   # Should return 200 OK
   ```

4. **Test Key Endpoints**:
   ```bash
   # Test story generation
   curl -X POST https://story-weaver-backend-production.up.railway.app/generate-story \
     -H "Content-Type: application/json" \
     -d '{
       "character_name": "Test",
       "theme": "Adventure",
       "age": 8
     }'

   # Should return story JSON (not error)
   ```

5. **Monitor Error Logs**:
   - Check Railway logs for any errors
   - Look for:
     - 500 errors
     - Database connection issues
     - Timeout errors
     - Memory issues

6. **Document Status**:
   - Update DEPLOYMENT_STATUS.md with:
     - Deployment time
     - Build success/failure
     - Any errors encountered
     - Frontend/backend URLs
     - Health check results

### If Build Fails:

1. Check Railway build logs for specific errors
2. Compare with local build that succeeded
3. Check for environment-specific issues:
   - Missing environment variables
   - Different Flutter/Dart versions
   - Memory limits
4. Document issue in TEAM_COORDINATION.md
5. Alert team if critical

### Deliverables:
- Deployment verified
- Health checks passing
- All endpoints functional
- Status documented in DEPLOYMENT_STATUS.md
- Any issues documented in TEAM_COORDINATION.md

---

## Task GR2: Implement Backend Error Logging & Monitoring (Priority: HIGH)

**Objective**: Add comprehensive error logging to catch issues before they affect users.

### Implementation:

1. **Add Structured Logging** (backend/app.py):
   ```python
   import logging
   import json
   from datetime import datetime

   # Configure structured logging
   logging.basicConfig(
       level=logging.INFO,
       format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
   )

   logger = logging.getLogger(__name__)

   # Add log helper
   def log_error(error_type, message, details=None):
       log_entry = {
           'timestamp': datetime.utcnow().isoformat(),
           'type': error_type,
           'message': message,
           'details': details or {}
       }
       logger.error(json.dumps(log_entry))
   ```

2. **Add Error Tracking to Key Routes**:

   **Story Generation** (backend/app.py around line 200):
   ```python
   @app.route('/generate-story', methods=['POST'])
   def generate_story():
       try:
           # ... existing code ...
       except Exception as e:
           log_error(
               error_type='story_generation_failed',
               message=str(e),
               details={
                   'character_name': request.json.get('character_name'),
                   'theme': request.json.get('theme'),
                   'error_class': e.__class__.__name__
               }
           )
           return jsonify({'error': 'Story generation failed'}), 500
   ```

   **Illustration Generation** (backend/gemini_image_generator.py):
   ```python
   def generate_illustration(prompt, api_key):
       try:
           # ... existing code ...
       except Exception as e:
           log_error(
               error_type='illustration_generation_failed',
               message=str(e),
               details={
                   'prompt_length': len(prompt),
                   'has_api_key': bool(api_key),
                   'error_class': e.__class__.__name__
               }
           )
           raise
   ```

3. **Add Request Logging Middleware**:
   ```python
   from flask import request
   import time

   @app.before_request
   def log_request():
       request.start_time = time.time()

   @app.after_request
   def log_response(response):
       duration = time.time() - request.start_time
       log_entry = {
           'method': request.method,
           'path': request.path,
           'status': response.status_code,
           'duration_ms': round(duration * 1000, 2),
           'ip': request.remote_addr
       }
       logger.info(json.dumps(log_entry))
       return response
   ```

4. **Add Performance Monitoring**:
   ```python
   # Track slow requests
   SLOW_REQUEST_THRESHOLD = 5.0  # seconds

   @app.after_request
   def check_slow_requests(response):
       duration = time.time() - request.start_time
       if duration > SLOW_REQUEST_THRESHOLD:
           log_error(
               error_type='slow_request',
               message=f'Request took {duration:.2f}s',
               details={
                   'method': request.method,
                   'path': request.path,
                   'duration': duration
               }
           )
       return response
   ```

5. **Add Database Query Monitoring**:
   ```python
   from sqlalchemy import event
   from sqlalchemy.engine import Engine

   @event.listens_for(Engine, "before_cursor_execute")
   def receive_before_cursor_execute(conn, cursor, statement, params, context, executemany):
       context._query_start_time = time.time()

   @event.listens_for(Engine, "after_cursor_execute")
   def receive_after_cursor_execute(conn, cursor, statement, params, context, executemany):
       total = time.time() - context._query_start_time
       if total > 1.0:  # Log slow queries
           logger.warning(f"Slow query ({total:.2f}s): {statement[:100]}")
   ```

### Testing:
1. Run backend locally with logging enabled
2. Generate test errors
3. Verify logs appear in Railway dashboard
4. Check log format is structured and parseable

### Deliverables:
- Structured logging implemented
- Error tracking on all routes
- Performance monitoring active
- Slow query detection working
- Logs visible in Railway dashboard

---

## Task GR3: Implement Backend Rate Limiting (Priority: HIGH)

**Objective**: Protect API from abuse and control costs.

### Implementation:

1. **Install Flask-Limiter**:
   ```bash
   cd backend
   pip install Flask-Limiter
   echo "Flask-Limiter==3.5.0" >> requirements.txt
   ```

2. **Configure Rate Limiting** (backend/app.py):
   ```python
   from flask_limiter import Limiter
   from flask_limiter.util import get_remote_address

   # Initialize limiter
   limiter = Limiter(
       app=app,
       key_func=get_remote_address,
       default_limits=["200 per day", "50 per hour"],
       storage_uri="memory://"  # Use Redis in production
   )

   # Stricter limits for expensive endpoints
   @app.route('/generate-story', methods=['POST'])
   @limiter.limit("10 per hour")
   def generate_story():
       # ... existing code ...

   @app.route('/generate-illustration', methods=['POST'])
   @limiter.limit("20 per hour")
   def generate_illustration():
       # ... existing code ...

   @app.route('/generate-interactive-story', methods=['POST'])
   @limiter.limit("5 per hour")
   def generate_interactive_story():
       # ... existing code ...

   # More permissive for read operations
   @app.route('/health', methods=['GET'])
   @limiter.limit("100 per minute")
   def health():
       # ... existing code ...
   ```

3. **Add User-Based Rate Limiting** (for authenticated users):
   ```python
   def get_user_id():
       # Get from request header or session
       return request.headers.get('X-User-ID', get_remote_address())

   limiter = Limiter(
       app=app,
       key_func=get_user_id,
       default_limits=["200 per day", "50 per hour"]
   )
   ```

4. **Add Custom Error Messages**:
   ```python
   @app.errorhandler(429)
   def rate_limit_exceeded(e):
       return jsonify({
           'error': 'Rate limit exceeded',
           'message': 'You have made too many requests. Please try again later.',
           'retry_after': e.description
       }), 429
   ```

5. **Add Rate Limit Headers**:
   ```python
   @app.after_request
   def add_rate_limit_headers(response):
       # Add X-RateLimit headers
       return response
   ```

### Testing:
1. Make multiple rapid requests to test rate limiting
2. Verify 429 responses after limit exceeded
3. Check error messages are user-friendly
4. Test with different IP addresses

### Deliverables:
- Rate limiting implemented
- Different limits for different endpoints
- User-friendly error messages
- Testing completed
- Documented in API_ENDPOINTS.md

---

## Task GR4: Implement Backend Health Checks & Alerts (Priority: MEDIUM)

**Objective**: Proactive monitoring to catch issues before users report them.

### Implementation:

1. **Enhanced Health Endpoint** (backend/app.py):
   ```python
   @app.route('/health/detailed', methods=['GET'])
   def detailed_health():
       health_status = {
           'status': 'healthy',
           'timestamp': datetime.utcnow().isoformat(),
           'checks': {}
       }

       # Database check
       try:
           db.session.execute(text('SELECT 1'))
           health_status['checks']['database'] = {
               'status': 'healthy',
               'response_time_ms': 0  # Measure actual time
           }
       except Exception as e:
           health_status['status'] = 'unhealthy'
           health_status['checks']['database'] = {
               'status': 'unhealthy',
               'error': str(e)
           }

       # Gemini API check
       try:
           # Test with minimal request
           test_response = genai.generate_content("test")
           health_status['checks']['gemini_api'] = {
               'status': 'healthy'
           }
       except Exception as e:
           health_status['status'] = 'degraded'
           health_status['checks']['gemini_api'] = {
               'status': 'unhealthy',
               'error': str(e)
           }

       # Memory check
       import psutil
       memory = psutil.virtual_memory()
       health_status['checks']['memory'] = {
           'status': 'healthy' if memory.percent < 90 else 'warning',
           'percent_used': memory.percent
       }

       status_code = 200 if health_status['status'] == 'healthy' else 503
       return jsonify(health_status), status_code
   ```

2. **Add Uptime Monitoring Script** (monitoring/uptime_monitor.py):
   ```python
   import requests
   import time
   import smtplib
   from email.mime.text import MIMEText

   BACKEND_URL = "https://story-weaver-backend-production.up.railway.app"
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
       pass

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
       monitor()
   ```

3. **Add Railway Health Check**:
   - In railway.toml, configure health check:
   ```toml
   [[services]]
   name = "backend"

   [services.healthcheck]
   path = "/health"
   interval = 30
   timeout = 10
   ```

### Testing:
1. Call /health/detailed endpoint
2. Verify all checks run
3. Test with database down (stop database temporarily)
4. Test with high memory usage
5. Verify alerts work

### Deliverables:
- Enhanced health endpoint
- Uptime monitoring script
- Railway health check configured
- Alert system tested
- Documentation updated

---

## Task GR5: Database Backup & Recovery (Priority: MEDIUM)

**Objective**: Ensure data can be recovered in case of failure.

### Implementation:

1. **Create Backup Script** (backend/backup_database.py):
   ```python
   import os
   from datetime import datetime
   import subprocess

   DATABASE_URL = os.getenv('DATABASE_URL')
   BACKUP_DIR = '/app/backups'

   def create_backup():
       timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
       backup_file = f"{BACKUP_DIR}/backup_{timestamp}.sql"

       # Create backup using pg_dump
       subprocess.run([
           'pg_dump',
           DATABASE_URL,
           '-f', backup_file
       ])

       print(f"Backup created: {backup_file}")
       return backup_file

   def cleanup_old_backups(keep_days=7):
       # Remove backups older than keep_days
       pass

   if __name__ == '__main__':
       create_backup()
       cleanup_old_backups()
   ```

2. **Schedule Backups**:
   - Use Railway cron or external scheduler
   - Run daily at 2 AM UTC
   ```bash
   0 2 * * * python /app/backend/backup_database.py
   ```

3. **Test Recovery**:
   ```bash
   # Test restore process
   psql DATABASE_URL < backup_file.sql
   ```

4. **Add Backup Verification**:
   ```python
   def verify_backup(backup_file):
       # Check file size
       # Verify SQL syntax
       # Test restore to temporary database
       pass
   ```

### Deliverables:
- Backup script created
- Scheduled backups running
- Recovery tested
- Documentation updated

---

## Task GR6: Optimize Backend Performance (Priority: LOW)

**Objective**: Reduce response times and improve user experience.

### Areas to Optimize:

1. **Database Query Optimization**:
   - Add indexes for frequently queried fields
   - Use query explain to find slow queries
   - Implement query caching

2. **API Response Caching**:
   ```python
   from flask_caching import Cache

   cache = Cache(app, config={'CACHE_TYPE': 'simple'})

   @app.route('/themes', methods=['GET'])
   @cache.cached(timeout=3600)  # Cache for 1 hour
   def get_themes():
       # ... existing code ...
   ```

3. **Gemini API Optimization**:
   - Reduce prompt size where possible
   - Implement response streaming
   - Add timeout handling

4. **Connection Pooling**:
   - Configure SQLAlchemy pool size
   ```python
   app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
       'pool_size': 10,
       'pool_recycle': 3600,
       'pool_pre_ping': True
   }
   ```

### Testing:
1. Measure baseline response times
2. Apply optimizations one by one
3. Measure improvements
4. Document results

### Deliverables:
- Performance baseline documented
- Optimizations implemented
- Improvements measured
- Documentation updated

---

## Priority Order

1. **GR1**: Monitor Railway Deployment (CRITICAL - verify fixes work)
2. **GR2**: Error Logging (HIGH - catch issues early)
3. **GR3**: Rate Limiting (HIGH - protect API)
4. **GR4**: Health Checks (MEDIUM - proactive monitoring)
5. **GR5**: Database Backup (MEDIUM - data safety)
6. **GR6**: Performance Optimization (LOW - nice to have)

---

## Notes for Grok

- Backend is currently functional
- Recent build fixed compilation errors
- Focus on reliability and monitoring
- Test changes in development first
- Document all infrastructure changes
- Update DEPLOYMENT_STATUS.md regularly

---

## Success Criteria

- [ ] Deployment verified and documented
- [ ] Error logging implemented
- [ ] Rate limiting active
- [ ] Health checks monitoring
- [ ] Backups running
- [ ] Performance baseline established
- [ ] All changes documented
- [ ] Testing completed
