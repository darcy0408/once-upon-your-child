# Railway Quick Fix - Immediate Action Items

## What Was Broken
1. Railway.toml only configured ONE service (backend), missing frontend completely
2. Backend Dockerfile hardcoded port 8080 instead of using Railway's $PORT
3. Backend config.py required .env file which doesn't exist in Railway
4. CORS configuration didn't dynamically include Railway URLs

## What Was Fixed
All configuration files have been updated. You need to:

### 1. Commit These Changes
```bash
git add railway.toml Dockerfile backend/config.py
git commit -m "Fix Railway multi-service deployment configuration"
git push origin feature/error-handling-improvements
```

### 2. In Railway Dashboard - Backend Service
**Environment Variables to Add:**
```
FLASK_ENV=prod
FLASK_CONFIG=prod
GEMINI_API_KEY=<your-actual-gemini-key>
SECRET_KEY=<generate-a-random-secret-32-chars>
JWT_SECRET_KEY=<generate-a-random-jwt-secret-32-chars>
```

**Optional but recommended:**
```
OPENROUTER_API_KEY=<your-openrouter-key>
DATABASE_URL=<railway-postgres-url-if-using-db>
STRIPE_SECRET_KEY=<your-stripe-key-if-using-payments>
```

### 3. In Railway Dashboard - Create Frontend Service
Currently you only have ONE service. You need to add a SECOND service:

**Steps:**
1. Click "New Service" in your Railway project
2. Choose "Deploy from GitHub repo"
3. Select the same repository
4. Name it "frontend"
5. In Settings → Build, set:
   - Dockerfile Path: `Dockerfile.frontend`
   - Root Directory: `/`

**Frontend Environment Variables:**
```
BACKEND_URL=<your-backend-railway-url>
```
(Get the backend URL from your backend service in Railway)

### 4. Link Services Together
Once both services are created:

**In Backend Service:**
Add environment variable:
```
RAILWAY_FRONTEND_URL=<your-frontend-railway-url>
```

**In Frontend Service:**
Ensure BACKEND_URL points to backend:
```
BACKEND_URL=<your-backend-railway-url>
```

### 5. Deploy
Both services should now deploy successfully:
- Backend will bind to Railway's $PORT dynamically
- Frontend will bind to Railway's $PORT dynamically
- Health checks will work
- CORS will allow frontend to talk to backend

## Quick Test
After deployment:
1. Visit `https://<backend-url>/health` - should return JSON status
2. Visit `https://<frontend-url>/` - should load Flutter app
3. Test creating a story - should work without CORS errors

## If Still Having Issues
1. Check Railway logs for each service
2. Verify all environment variables are set
3. Ensure both services show as "Active" (green)
4. Test health endpoints directly

## Files Modified
- `C:\dev\story-weaver-app\railway.toml` - Multi-service configuration
- `C:\dev\story-weaver-app\Dockerfile` - Dynamic port binding
- `C:\dev\story-weaver-app\backend\config.py` - Environment-aware config
- `C:\dev\story-weaver-app\RAILWAY_DEPLOYMENT_GUIDE.md` - Full documentation

---
**Next Step:** Commit and push these changes, then configure Railway dashboard as described above.
