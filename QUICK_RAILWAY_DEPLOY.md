# Quick Railway Deployment Guide

## Latest Fixes (2025-12-23):
1. ✅ Fixed Python version mismatch (now using Python 3.11 everywhere)
2. ✅ Simplified nixpacks configuration
3. ✅ Created railway.json with proper settings
4. ✅ Made PostgreSQL OPTIONAL - app will use SQLite if no DATABASE_URL is set
5. ✅ Removed pkg-config dependency
6. ✅ Added setuptools and wheel for better compatibility

## Step-by-Step Deployment:

### 1. Commit the Changes
```bash
git add railway.json nixpacks.toml
git commit -m "fix: Simplify Railway deployment configuration"
git push origin main
```

### 2. Remove Postgres Service (If It Exists)
**IMPORTANT:** If you already have a Postgres service in Railway:
1. Go to your Railway project
2. Click on the "postgres" service
3. Go to Settings → Danger Zone
4. Click "Remove Service"
5. Confirm removal

(We're using SQLite for now - you can add Postgres later if needed)

### 3. Railway Setup
1. Go to https://railway.app
2. If you don't have a project yet:
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Choose your `story-weaver-app` repository
3. If you already have the project, just push your changes and Railway will redeploy
4. Railway will auto-detect nixpacks and start building

### 4. Required Environment Variables in Railway
Go to your project → Variables tab and add:

**Essential:**
- `FLASK_ENV` = `prod`
- `FLASK_CONFIG` = `prod`
- `GEMINI_API_KEY` = `your-actual-gemini-api-key`
- `SECRET_KEY` = `generate-random-secret-at-least-32-chars`

**Optional but Recommended:**
- `JWT_SECRET_KEY` = `another-random-secret-key`
- `SENTRY_DSN` = `your-sentry-dsn` (for error tracking)

**DO NOT SET:**
- ❌ `DATABASE_URL` - Leave this empty to use SQLite (Postgres not needed for now)

### 5. Check Deployment
- Railway will show build logs
- Wait for "Deployment successful"
- Click on the deployment URL
- Test `/health` endpoint: `https://your-app.railway.app/health`

## Common Errors & Fixes:

### Error: "ModuleNotFoundError: No module named 'backend'"
**Fix:** Make sure `wsgi.py` is in the **root** directory (not in backend folder)

### Error: "Application failed to bind to $PORT"
**Fix:** Already fixed in `nixpacks.toml` - uses `$PORT` variable

### Error: "Health check timeout"
**Fix:**
- Check logs to see if app is starting
- Verify `GEMINI_API_KEY` is set correctly
- Make sure `/health` endpoint exists

### Error: "Import error: psycopg2"
**Fix:** Already removed PostgreSQL dependency. If you need it later:
1. Add `postgresql` to `nixPkgs` in nixpacks.toml
2. Add `DATABASE_URL` environment variable in Railway

## Testing After Deployment:

1. **Health Check:**
   ```
   curl https://your-app.railway.app/health
   ```
   Should return: `{"status": "healthy", ...}`

2. **Story Generation Test:**
   ```
   curl -X POST https://your-app.railway.app/generate-story \
     -H "Content-Type: application/json" \
     -d '{"character": "Hero", "theme": "Adventure", "age": 5}'
   ```

3. **Get Characters:**
   ```
   curl https://your-app.railway.app/get-characters
   ```

## What to Check If Deployment Fails:

1. **Railway Logs** - Click on your deployment → "View Logs"
2. **Build Phase** - Did pip install succeed?
3. **Deploy Phase** - Is gunicorn starting?
4. **Environment Variables** - Are all required vars set?

## Need More Workers?

If you get high traffic, edit the start command in Railway dashboard:
```
gunicorn wsgi:app --bind 0.0.0.0:$PORT --timeout 120 --workers 4
```
(Change `--workers 2` to `--workers 4` for more capacity)

## Frontend Deployment (Optional - Later)

For now, just deploy the backend. Frontend can be deployed separately:
- Use Netlify or Vercel for Flutter Web
- Set `BACKEND_URL` to your Railway backend URL

---

**Last Updated:** 2025-12-23
