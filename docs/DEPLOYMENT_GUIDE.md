# Story Weaver App - Production Deployment Guide

## Overview

This guide covers deploying the Story Weaver app with proper timeout handling and asynchronous task processing using Celery + Redis.

## Prerequisites

- Redis instance (hosted or cloud service like Redis Cloud, Upstash, etc.)
- Python 3.11+ environment
- Access to hosting platform (Railway, Render, Heroku, etc.)

## Environment Variables

### Required Production Variables

Set these in your hosting platform's environment configuration:

```bash
# Timeout Configuration
SYNC_STORY_TIMEOUT_SECONDS=75
GEMINI_REQUEST_TIMEOUT_SECONDS=45
GEMINI_IMAGE_REQUEST_TIMEOUT_SECONDS=120

# Celery Configuration
CELERY_TASK_ALWAYS_EAGER=false
CELERY_TASK_EAGER_PROPAGATES=false
CELERY_TASK_STORE_EAGER_RESULT=false
CELERY_BROKER_URL=redis://<your-redis-host>:6379/0
CELERY_RESULT_BACKEND=redis://<your-redis-host>:6379/0

# Your existing variables
GEMINI_API_KEY=<your-key>
STRIPE_SECRET_KEY=<your-key>
STRIPE_WEBHOOK_SECRET=<your-webhook-secret>
# ... etc
```

**Important**: Replace `<your-redis-host>` with your actual Redis connection string.

For Redis Cloud or Upstash, use their full connection URL:
```bash
CELERY_BROKER_URL=redis://default:password@redis-12345.cloud.redislabs.com:16379/0
CELERY_RESULT_BACKEND=redis://default:password@redis-12345.cloud.redislabs.com:16379/0
```

## Service Configuration

You need to run **two separate processes**:

### 1. Web Server (Flask App)

**Command:**
```bash
python -m backend.app
```

**Configuration:**
- Port: 8080 (or your platform's default)
- Health check: `GET /health`
- Handles HTTP requests
- Dispatches long-running tasks to Celery workers

### 2. Celery Worker

**Command:**
```bash
celery -A backend.celery_config.celery worker --loglevel=info --pool=threads --concurrency=4
```

**Configuration:**
- Connects to Redis broker
- Processes story generation tasks asynchronously
- Uses `solo` pool for Windows compatibility (use `prefork` on Linux/macOS for better performance)

## Platform-Specific Instructions

### Railway

1. **Create two services** in your Railway project:

   **Service 1: Web**
   - Build command: `pip install -r requirements.txt`
   - Start command: `python -m backend.app`
   - Add all environment variables above

   **Service 2: Worker**
   - Build command: `pip install -r requirements.txt`
   - Start command: `celery -A backend.celery_config.celery worker --loglevel=info --pool=threads --concurrency=4`
   - Share same environment variables (or reference from web service)

2. **Add Redis** plugin/service to your project

3. Set `CELERY_BROKER_URL` and `CELERY_RESULT_BACKEND` to Railway's Redis connection URL

### Render

1. **Create Web Service**:
   - Environment: Python 3
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `python -m backend.app`
   - Add environment variables

2. **Create Background Worker**:
   - Environment: Python 3
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `celery -A backend.celery_config.celery worker --loglevel=info --pool=threads --concurrency=4`
   - Share environment variables with web service

3. **Add Redis** from Render's add-ons or use external Redis provider

### Heroku

1. **Add Redis addon**:
   ```bash
   heroku addons:create heroku-redis:mini
   ```
   This automatically sets `REDIS_URL`

2. **Set Celery URLs** to use Heroku's Redis:
   ```bash
   heroku config:set CELERY_BROKER_URL=$(heroku config:get REDIS_URL)
   heroku config:set CELERY_RESULT_BACKEND=$(heroku config:get REDIS_URL)
   ```

3. **Configure Procfile**:
   ```
   web: python -m backend.app
   worker: celery -A backend.celery_config.celery worker --loglevel=info --pool=threads --concurrency=4
   ```

4. **Scale worker dyno**:
   ```bash
   heroku ps:scale worker=1
   ```

## Verification Steps

After deployment, verify the setup is working:

### 1. Health Check
```bash
curl https://your-app.com/health
```
Expected: `200 OK` with `{"status": "healthy"}`

### 2. Light Story Generation
```bash
curl -X POST https://your-app.com/api/stories/generate-story \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "theme": "dragons",
    "age_group": "5-7",
    "story_length": "short"
  }'
```
Expected: Story generated in ~10-20s

### 3. Heavy Story Generation (Timeout Test)
```bash
curl -X POST https://your-app.com/api/stories/generate-story \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "theme": "epic adventure",
    "age_group": "13+",
    "story_length": "long"
  }'
```
Expected: Either completes in <75s OR returns `504` with error code `STORY_TIMEOUT`

### 4. Check Worker Logs
Monitor your worker logs to see tasks being processed:
```
[2026-02-13 10:30:45] Task story_generation_task[abc123] received
[2026-02-13 10:31:20] Task story_generation_task[abc123] succeeded
```

## Troubleshooting

### Stories Not Generating
- Check worker is running and connected to Redis
- Verify `CELERY_BROKER_URL` is correct
- Check worker logs for errors

### Timeouts Still Occurring
- Ensure `SYNC_STORY_TIMEOUT_SECONDS=75` is set
- Verify timeout is greater than Gemini timeout (45s)
- Check network latency to Gemini API

### Worker Crashes
- On Linux/macOS, try `--pool=prefork` instead of `solo`
- Check memory limits on your hosting platform
- Review worker logs for specific errors

### Redis Connection Errors
- Verify Redis is accessible from your hosting environment
- Check Redis URL format (should include password if required)
- Test Redis connection with `redis-cli` or similar

## Monitoring

### Key Metrics to Watch
- Story generation success rate
- Average generation time
- Task queue length in Redis
- Worker CPU/memory usage
- Timeout occurrence rate

### Logs to Monitor
- Web server: Request/response logs, timeout errors
- Worker: Task execution logs, Celery errors
- Redis: Connection errors, memory usage

## Rollback Plan

If issues occur after deployment:

1. **Quick fix**: Set `CELERY_TASK_ALWAYS_EAGER=true` to disable async (degrades performance but ensures functionality)
2. **Scale worker**: Increase worker instances if queue is backing up
3. **Revert code**: Git revert to previous commit if needed

## Performance Tuning

### For High Load
- Increase worker count (horizontal scaling)
- Use connection pooling for Redis
- Consider worker autoscaling based on queue length

### For Better Response Times
- Reduce timeouts for faster failure (trade-off with success rate)
- Add caching layer for repeated requests
- Use Celery result backend for async polling

---

**Last Updated**: 2026-02-13
**Commit**: 0438b76 - Backend timeout enforcement
