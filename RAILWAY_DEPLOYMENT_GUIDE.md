# Railway Deployment Guide - Story Weaver App

## Overview
This guide explains how to deploy the Story Weaver App to Railway with both frontend (Flutter Web) and backend (Flask API) services.

## Prerequisites
- Railway account (https://railway.app)
- GitHub repository connected to Railway
- Environment variables ready (see Required Environment Variables below)

## Architecture
The application deploys as **two separate Railway services**:
1. **Backend Service** - Python Flask API (port dynamically assigned)
2. **Frontend Service** - Flutter Web app served by nginx (port dynamically assigned)

## Deployment Steps

### Step 1: Create a New Railway Project
1. Log into Railway dashboard
2. Click "New Project"
3. Select "Deploy from GitHub repo"
4. Choose your `story-weaver-app` repository
5. Railway will detect the repository and prepare for deployment

### Step 2: Configure Backend Service
Railway should automatically detect the `Dockerfile` and create a backend service.

#### Backend Environment Variables
Add these environment variables in the Railway dashboard for the **backend service**:

**REQUIRED:**
- `FLASK_ENV=prod`
- `FLASK_CONFIG=prod`
- `GEMINI_API_KEY=<your-gemini-api-key>`
- `SECRET_KEY=<generate-random-secret-key>`
- `DATABASE_URL=<railway-postgres-url>` (if using Postgres, Railway can auto-provision)
- `JWT_SECRET_KEY=<generate-random-jwt-secret>`

**OPTIONAL (for enhanced features):**
- `OPENROUTER_API_KEY=<your-openrouter-key>` (for cost-optimized image generation)
- `STRIPE_SECRET_KEY=<your-stripe-secret-key>` (for payments)
- `STRIPE_PRICE_ID_PREMIUM=<stripe-premium-price-id>`
- `STRIPE_PRICE_ID_FAMILY=<stripe-family-price-id>`
- `SENTRY_DSN=<your-sentry-dsn>` (for error monitoring)

#### Backend Service Settings
- **Build Command:** Automatically handled by Dockerfile
- **Start Command:** `gunicorn -w 4 -b 0.0.0.0:$PORT wsgi:app --timeout 120` (set in railway.toml)
- **Healthcheck Path:** `/health`
- **Port:** Railway will assign dynamically via `$PORT` environment variable

### Step 3: Configure Frontend Service
You need to manually add the frontend service:

1. In your Railway project, click "New Service"
2. Select "Deploy from GitHub repo"
3. Choose the same repository
4. Railway will create a second service

#### Frontend Service Configuration
In the service settings:
- **Name:** frontend
- **Dockerfile Path:** `Dockerfile.frontend`
- **Root Directory:** `/` (repository root)

#### Frontend Environment Variables
Add these environment variables for the **frontend service**:
- `BACKEND_URL=<backend-service-url>` (get this from backend service's Railway URL)
  - Example: `https://backend-production-xxxx.up.railway.app`

#### Frontend Service Settings
- **Build Command:** Handled by Dockerfile.frontend (Flutter build web)
- **Port:** Railway will assign dynamically via `$PORT` environment variable
- **Healthcheck Path:** `/` (root path)

### Step 4: Set Up Custom Domains (Optional)
1. Go to each service's Settings → Domains
2. Add custom domains or use Railway-provided URLs
3. Update CORS configuration if using custom domains

### Step 5: Link Backend to Frontend
The frontend needs to know the backend URL:
1. Copy the backend service's Railway URL (e.g., `https://backend-production-xxxx.up.railway.app`)
2. Set it as `BACKEND_URL` environment variable in the frontend service
3. Redeploy frontend service

### Step 6: Configure CORS
The backend automatically configures CORS based on environment variables:
- Set `RAILWAY_FRONTEND_URL` to your frontend Railway URL
- This allows the frontend to communicate with the backend

Example:
```
RAILWAY_FRONTEND_URL=https://frontend-production-xxxx.up.railway.app
```

## Troubleshooting

### Issue: Backend Health Check Failing
**Solution:**
- Check Railway logs for the backend service
- Verify `GEMINI_API_KEY` is set correctly
- Ensure `/health` endpoint is accessible
- Check that database connection is working

### Issue: Frontend Shows Blank Page
**Solution:**
- Check nginx logs in Railway
- Verify Flutter build completed successfully
- Check browser console for errors
- Ensure `BACKEND_URL` is set correctly in frontend environment

### Issue: CORS Errors in Browser Console
**Solution:**
- Add frontend Railway URL to `RAILWAY_FRONTEND_URL` backend env var
- Check that backend CORS configuration includes frontend domain
- Verify both services are deployed and accessible

### Issue: Port Binding Errors
**Solution:**
- Ensure backend uses `$PORT` variable (handled by railway.toml)
- Do NOT hardcode ports in your application
- Railway assigns ports dynamically

### Issue: Database Connection Errors
**Solution:**
- Add Railway Postgres plugin to your project
- Copy the `DATABASE_URL` from Postgres service
- Add it as environment variable to backend service
- Redeploy backend

## Monitoring and Logs

### Viewing Logs
1. Go to Railway dashboard
2. Select your project
3. Click on the service (backend or frontend)
4. Click "Logs" tab to view real-time logs

### Health Checks
- **Backend:** `https://<backend-url>/health`
  - Should return JSON with status and service info
- **Frontend:** `https://<frontend-url>/`
  - Should load the Flutter web app

## Cost Optimization Tips

1. **Use OpenRouter for Image Generation:** Set `OPENROUTER_API_KEY` instead of relying only on Gemini
2. **Optimize Worker Count:** Backend uses 4 workers by default, adjust based on traffic
3. **Enable Caching:** Backend uses Flask-Caching for frequently accessed data
4. **Monitor Usage:** Railway provides resource usage metrics in dashboard

## Updating Deployment

### To Deploy New Changes:
1. Push code to your GitHub repository
2. Railway automatically detects changes
3. Services rebuild and redeploy automatically
4. Monitor deployment logs for any errors

### Manual Redeploy:
1. Go to Railway dashboard
2. Select the service
3. Click "Deploy" → "Redeploy"

## Important Files Reference

- `railway.toml` - Railway configuration for both services
- `Dockerfile` - Backend container definition
- `Dockerfile.frontend` - Frontend container definition
- `nginx.conf` - Frontend nginx server configuration
- `wsgi.py` - Backend WSGI entry point
- `backend/config.py` - Backend configuration with CORS settings

## Support

If deployment issues persist:
1. Check Railway status page: https://status.railway.app
2. Review Railway logs thoroughly
3. Verify all environment variables are set correctly
4. Check that both services are running
5. Test health endpoints directly

## Environment Variables Checklist

Before deploying, ensure you have:

**Backend:**
- [ ] FLASK_ENV
- [ ] FLASK_CONFIG
- [ ] GEMINI_API_KEY
- [ ] SECRET_KEY
- [ ] DATABASE_URL (if using database)
- [ ] JWT_SECRET_KEY
- [ ] RAILWAY_FRONTEND_URL (for CORS)

**Frontend:**
- [ ] BACKEND_URL

**Optional:**
- [ ] OPENROUTER_API_KEY
- [ ] STRIPE_SECRET_KEY
- [ ] SENTRY_DSN

---

**Last Updated:** 2025-12-05
**Version:** 1.0
