# Railway Deployment - Step-by-Step Guide

## Overview

You need to set up 3 services in Railway:
1. **Redis** - Message broker
2. **Web** - Flask app (your existing service)
3. **Worker** - Celery background worker

---

## Step 1: Add Redis to Your Project

1. Open your Railway project dashboard
2. Click **"+ New"** button
3. Select **"Database"** → **"Add Redis"**
4. Railway will provision a Redis instance automatically
5. Note: Railway automatically creates a `REDIS_URL` variable you can reference

---

## Step 2: Configure Your Web Service (Existing Flask App)

### A. Add Environment Variables

1. Click on your **web service** (backend/Flask app)
2. Go to **"Variables"** tab
3. Click **"+ New Variable"** and add these one by one:

```
SYNC_STORY_TIMEOUT_SECONDS=75
GEMINI_REQUEST_TIMEOUT_SECONDS=45
GEMINI_IMAGE_REQUEST_TIMEOUT_SECONDS=120

CELERY_TASK_ALWAYS_EAGER=false
CELERY_TASK_EAGER_PROPAGATES=false
CELERY_TASK_STORE_EAGER_RESULT=false
```

4. For Celery Redis URLs, click **"+ New Variable"** → **"Add Reference"**:
   - Variable name: `CELERY_BROKER_URL`
   - Reference: Select your Redis service → `REDIS_URL`
   - Click "Add"

5. Repeat for `CELERY_RESULT_BACKEND`:
   - Variable name: `CELERY_RESULT_BACKEND`
   - Reference: Select your Redis service → `REDIS_URL`
   - Click "Add"

### B. Verify Start Command

1. Go to **"Settings"** tab
2. Scroll to **"Deploy"** section
3. Ensure **"Start Command"** is:
   ```
   python -m backend.app
   ```
4. If not set, add it and click "Save"

---

## Step 3: Create Celery Worker Service

### A. Add New Service

1. Go back to your project dashboard (top-left breadcrumb)
2. Click **"+ New"** button
3. Select **"Empty Service"** (or "GitHub Repo" if you want to link same repo)

### Option A: Link Same Repository (Recommended)

1. Select **"GitHub Repo"**
2. Choose the **same repository** as your web service
3. Name it something like **"story-weaver-worker"**

### Option B: Empty Service (Manual Setup)

1. Select **"Empty Service"**
2. Name it **"story-weaver-worker"**
3. You'll need to manually connect it to your repo later

### B. Configure Worker Service

1. Go to **"Settings"** tab on the new worker service
2. Scroll to **"Deploy"** section
3. Set these values:

   **Root Directory**: `.` (same as web service)

   **Build Command** (if needed):
   ```
   pip install -r requirements.txt
   ```

   **Start Command**:
   ```
   celery -A backend.celery_config.celery worker --loglevel=info --pool=solo
   ```

4. Click **"Save"**

### C. Add Environment Variables to Worker

**Important**: The worker needs the same environment variables as the web service.

**Easy Method - Reference Web Service Variables**:

1. In worker service, go to **"Variables"** tab
2. Click **"+ New Variable"** → **"Add Reference"**
3. For each variable, reference from your web service:
   - Reference: `story-weaver-web` (your web service name) → variable name
   - Repeat for all variables

**Manual Method - Copy Variables**:

Copy all environment variables from your web service:
- All Celery config
- All timeout config
- All API keys (Gemini, Stripe, etc.)
- Database URLs
- Everything the app needs

**Critical Variables for Worker**:
```
CELERY_BROKER_URL → Reference Redis REDIS_URL
CELERY_RESULT_BACKEND → Reference Redis REDIS_URL
GEMINI_API_KEY → Your API key
SYNC_STORY_TIMEOUT_SECONDS=75
GEMINI_REQUEST_TIMEOUT_SECONDS=45
GEMINI_IMAGE_REQUEST_TIMEOUT_SECONDS=120
```

---

## Step 4: Deploy Everything

Railway auto-deploys on config changes, but to be sure:

1. **Check Redis**: Should show "Active" status
2. **Redeploy Web**: Click web service → "Deployments" tab → Click "Redeploy" on latest
3. **Deploy Worker**: Worker should auto-deploy after configuration

---

## Step 5: Verify It's Working

### A. Check Service Status

1. All three services should show **green "Active"** status in Railway dashboard
2. Click on each service and check logs for errors

### B. Check Worker Logs

1. Click on **worker service**
2. Go to **"Deployments"** → Click latest deployment
3. Check logs for:
   ```
   celery@<hostname> ready.
   ```
   This means worker is connected and waiting for tasks

### C. Test Story Generation

1. Get your Railway web service URL (e.g., `https://story-weaver-app.up.railway.app`)
2. Test health check:
   ```bash
   curl https://your-app.up.railway.app/health
   ```
   Should return `{"status": "healthy"}`

3. Generate a test story (use your app's frontend or API)
4. Check **worker logs** - you should see:
   ```
   Task story_generation_task[abc123] received
   Task story_generation_task[abc123] succeeded
   ```

---

## Troubleshooting

### Worker Not Starting

**Check Logs**: Look for errors like:
- `ModuleNotFoundError: No module named 'celery'` → Build command not running
- `Error connecting to Redis` → Check CELERY_BROKER_URL variable

**Solution**:
1. Verify start command is exact: `celery -A backend.celery_config.celery worker --loglevel=info --pool=solo`
2. Ensure all environment variables are set
3. Check Redis is active and accessible

### Worker Crashes Immediately

**Possible Causes**:
- Missing environment variables
- Redis connection issue
- Python version mismatch

**Solution**:
1. Go to worker Settings → General → Set Python version to match web service (3.11+)
2. Verify CELERY_BROKER_URL points to Redis
3. Check all required env vars are present

### Stories Not Generating

**Check**:
1. Worker logs show it's receiving tasks
2. Web logs show it's dispatching tasks
3. Redis is active

**Debug**:
```bash
# In Railway web service terminal (click "Shell" icon):
python
>>> from backend.celery_config import celery
>>> celery.control.inspect().active()
# Should show worker is connected
```

### Environment Variables Not Taking Effect

Railway auto-redeploys on variable changes, but sometimes you need to force it:
1. Change variable → Wait 5 seconds
2. Go to Deployments tab → Click "Redeploy"

---

## Quick Checklist

- [ ] Redis service added and active
- [ ] Web service has all timeout and Celery env vars
- [ ] Web service `CELERY_BROKER_URL` references Redis
- [ ] Web service `CELERY_RESULT_BACKEND` references Redis
- [ ] Worker service created and linked to repo
- [ ] Worker start command: `celery -A backend.celery_config.celery worker --loglevel=info --pool=solo`
- [ ] Worker has same env vars as web (or references them)
- [ ] All three services show "Active" status
- [ ] Worker logs show "celery@... ready"
- [ ] Test story generation works
- [ ] Check worker logs show tasks being processed

---

## Railway-Specific Tips

### Cost Optimization
- Railway charges per service, so you'll have 3 services total (Web, Worker, Redis)
- Worker can use a smaller instance size if you configure it in Settings → Resources
- Redis mini instance is usually sufficient for moderate load

### Scaling
To handle more concurrent story generations:
1. Go to Worker service → Settings → Resources
2. Increase CPU/Memory
3. Or add additional worker replicas (Settings → Replicas)

### Monitoring
- Use Railway's built-in **Metrics** tab to monitor CPU/Memory
- Check **Logs** tab for errors
- Set up **Deploy Webhooks** for notifications (Settings → Webhooks)

### Private Networking
Railway services automatically communicate over private network, so Redis connection is secure and fast.

---

**Need Help?**

If you get stuck on any step, copy the error message from Railway logs and I can help debug!
