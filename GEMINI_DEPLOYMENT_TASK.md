# Gemini Task: Prepare Story Weaver for Production Deployment

## 🎯 Goal
Get Story Weaver ready for production deployment. Deploy the backend to Railway (cloud hosting), build the web version, and prepare everything for users to access the app online. Currently it only works on localhost - we need to make it accessible to the world!

---

## 📍 Working Location
```bash
Directory: /mnt/c/dev/story-weaver-app (or C:\dev\story-weaver-app on Windows)
Branch: gemini-deploy
Setup:
  git checkout -b gemini-deploy
  git merge main -m "Merge main: Story generation fixes"
```

**IMPORTANT:** Work on `gemini-deploy` branch. Do NOT work directly on main.

---

## 📋 What You'll Do

This is a multi-part task following our deployment plan (ref: TESTING_AND_DEPLOYMENT.md):

### Part 1: Backend Deployment to Railway ☁️
Deploy the Flask backend to Railway's free tier so it's accessible online.

### Part 2: Environment Configuration 🔧
Update the Flutter app to use the production backend URL instead of localhost.

### Part 3: Build Web Version 🌐
Create a production-optimized web build of the Flutter app.

### Part 4: Prepare Netlify Deployment 🚀
Set up configuration files for deploying to Netlify.

### Part 5: Testing & Documentation ✅
Test the production setup and document the deployment process.

---

## 🚂 Part 1: Deploy Backend to Railway

### Step 1.1: Prepare Backend for Railway

Create `backend/railway.json`:
```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "python app.py",
    "healthcheckPath": "/",
    "healthcheckTimeout": 100
  }
}
```

Create `backend/Procfile`:
```
web: python app.py
```

Create `backend/runtime.txt`:
```
python-3.11
```

### Step 1.2: Update `backend/app.py` for Production

Add these changes to make it production-ready:

```python
import os
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)

# IMPORTANT: Update CORS for production
# Allow both localhost (for development) and your production domains
ALLOWED_ORIGINS = [
    "http://localhost:8080",
    "http://127.0.0.1:8080",
    "https://story-weaver-app.netlify.app",  # Add your Netlify domain
    "https://*.netlify.app",  # Allow Netlify preview deploys
]

CORS(app, resources={
    r"/*": {
        "origins": ALLOWED_ORIGINS,
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"],
    }
})

# ... rest of your existing code ...

if __name__ == "__main__":
    # Use PORT from environment (Railway sets this)
    port = int(os.environ.get("PORT", 5000))
    # Bind to 0.0.0.0 for Railway
    app.run(host="0.0.0.0", port=port, debug=False)
```

### Step 1.3: Create `backend/requirements.txt`

Generate the requirements file:
```bash
cd backend
pip freeze > requirements.txt
```

Or manually create it with these core dependencies:
```
Flask==3.0.0
flask-cors==4.0.0
flask-sqlalchemy==3.1.1
google-generativeai==0.3.2
python-dotenv==1.0.0
requests==2.31.0
```

### Step 1.4: Update `.env` File

Make sure `backend/.env` has:
```bash
GOOGLE_API_KEY=your_actual_gemini_api_key_here
PORT=5000
FLASK_ENV=production
```

**IMPORTANT:** The `.env` file should NOT be committed to git. Add it to `.gitignore` if not already there.

### Step 1.5: Deploy to Railway

**Option A: Using Railway CLI**
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Navigate to backend directory
cd C:\dev\story-weaver-app\backend

# Initialize Railway project
railway init

# Set environment variables
railway variables set GOOGLE_API_KEY=your_api_key_here

# Deploy!
railway up

# Get your deployment URL
railway domain
```

**Option B: Using Railway Web Dashboard**
1. Go to https://railway.app
2. Sign up/login with GitHub
3. Click "New Project" → "Deploy from GitHub repo"
4. Connect your repository
5. Select `story-weaver-app` repo
6. Set root directory to `/backend`
7. Add environment variables:
   - `GOOGLE_API_KEY`: Your Gemini API key
   - `PORT`: 5000 (Railway auto-sets this)
8. Deploy!

**Expected Result:** You'll get a URL like `https://your-app-name.up.railway.app`

### Step 1.6: Test Backend Deployment

```bash
# Test the deployed backend
curl https://your-app-name.up.railway.app/

# Should return: "Story Creator API is running"

# Test story generation
curl -X POST https://your-app-name.up.railway.app/generate-story \
  -H "Content-Type: application/json" \
  -d '{"character":"Test","theme":"Adventure","character_age":7}'

# Should return a JSON response with a story
```

---

## 🔧 Part 2: Update Flutter App for Production Backend

### Step 2.1: Create Environment Configuration

Create `lib/config/environment.dart`:
```dart
class Environment {
  // Toggle this for development vs production
  static const bool isDevelopment = false;

  // Backend URLs
  static const String developmentBackendUrl = 'http://127.0.0.1:5000';
  static const String productionBackendUrl = 'https://your-app-name.up.railway.app';

  // Get current backend URL
  static String get backendUrl => isDevelopment ? developmentBackendUrl : productionBackendUrl;

  // API endpoints
  static String get generateStoryUrl => '$backendUrl/generate-story';
  static String get generateInteractiveStoryUrl => '$backendUrl/generate-interactive-story';
  static String get continueInteractiveStoryUrl => '$backendUrl/continue-interactive-story';
  static String get createCharacterUrl => '$backendUrl/create-character';
  static String get getCharactersUrl => '$backendUrl/get-characters';
}
```

### Step 2.2: Update ApiServiceManager

Modify `lib/services/api_service_manager.dart`:

```dart
import '../config/environment.dart';

class ApiServiceManager {
  // Replace hardcoded URL with environment config
  static String get _localBackendUrl => Environment.backendUrl;

  // Rest of your code stays the same...
}
```

### Step 2.3: Add Production Build Config

Update `web/index.html` to handle production URLs:

Find the `<base href="/">` tag and ensure it's set correctly:
```html
<!DOCTYPE html>
<html>
<head>
  <base href="/">
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Story Weaver - Therapeutic AI Stories</title>
  <meta name="description" content="Create personalized therapeutic stories for emotional growth">
</head>
<body>
  <script src="main.dart.js" type="application/javascript"></script>
</body>
</html>
```

---

## 🌐 Part 3: Build Production Web Version

### Step 3.1: Clean Previous Builds

```bash
cd C:\dev\story-weaver-app
flutter clean
flutter pub get
```

### Step 3.2: Build for Web

```bash
flutter build web --release --web-renderer canvaskit
```

**Flags explained:**
- `--release`: Optimized production build
- `--web-renderer canvaskit`: Better rendering quality (larger download but looks nicer)

**Alternative (smaller, faster):**
```bash
flutter build web --release --web-renderer html
```

**Expected output:** Build files in `build/web/` directory

### Step 3.3: Test Build Locally

```bash
# Serve the build locally
cd build/web
python -m http.server 8000

# Open browser to http://localhost:8000
# Test that story generation works with production backend
```

---

## 🚀 Part 4: Prepare Netlify Deployment

### Step 4.1: Create `netlify.toml`

Create this file at project root:
```toml
[build]
  publish = "build/web"
  command = "flutter build web --release"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200

[build.environment]
  FLUTTER_VERSION = "3.24.0"
```

### Step 4.2: Create `_redirects` File

Create `web/_redirects`:
```
/*    /index.html   200
```

This ensures Flutter's client-side routing works on Netlify.

### Step 4.3: Create Deployment Instructions Document

Create `DEPLOYMENT_INSTRUCTIONS.md`:
```markdown
# How to Deploy Story Weaver to Netlify

## Prerequisites
- Backend deployed to Railway: https://your-app-name.up.railway.app
- Flutter web build completed

## Step 1: Sign Up for Netlify
1. Go to https://www.netlify.com
2. Sign up with GitHub account
3. No credit card required for free tier

## Step 2: Deploy from GitHub
1. Click "Add new site" → "Import an existing project"
2. Choose GitHub
3. Select `story-weaver-app` repository
4. Build settings:
   - Build command: `flutter build web --release`
   - Publish directory: `build/web`
5. Click "Deploy site"

## Step 3: Configure Domain (Optional)
1. Go to Site settings → Domain management
2. Add custom domain or use Netlify's subdomain
3. Update CORS in backend to include your domain

## Step 4: Test Production Site
1. Visit your Netlify URL
2. Create a character
3. Generate a story
4. Verify it uses the Railway backend (check Network tab)

## Success Criteria
✅ App loads without errors
✅ Can create characters
✅ Can generate stories (using Railway backend)
✅ Stories save and load correctly
✅ All features work as in development

## Troubleshooting

### CORS Error
- Add your Netlify domain to backend/app.py CORS config
- Redeploy backend to Railway

### 404 Errors on Refresh
- Check `_redirects` file exists in `build/web`
- Check `netlify.toml` has redirect rules

### Stories Not Generating
- Check backend URL in `lib/config/environment.dart`
- Verify Railway backend is running
- Check browser console for errors
```

---

## ✅ Part 5: Testing & Validation

### Test Checklist

#### Backend Tests
- [ ] Railway backend URL responds to GET /
- [ ] Can generate story via POST /generate-story
- [ ] Can create character via POST /create-character
- [ ] Can fetch characters via GET /get-characters
- [ ] CORS headers allow your frontend domain
- [ ] Environment variables (API keys) are set correctly

#### Frontend Tests
- [ ] `flutter build web` completes without errors
- [ ] Build size is reasonable (<10MB for main bundle)
- [ ] Local test of build/web works
- [ ] Environment.backendUrl points to Railway URL
- [ ] No hardcoded localhost URLs remain

#### Integration Tests
- [ ] Create a character in production build
- [ ] Generate a regular story
- [ ] Generate a rhyme time story
- [ ] Generate an interactive story
- [ ] Save and reload stories
- [ ] All network requests go to Railway (not localhost)

### Quality Checks
- [ ] No console errors in browser
- [ ] No network errors (check DevTools Network tab)
- [ ] Story generation completes in <15 seconds
- [ ] App loads in <5 seconds

---

## 📝 Deliverables

When you're done, you should have:

1. **Backend deployed to Railway**
   - URL: `https://your-app-name.up.railway.app`
   - Working endpoints: /, /generate-story, /create-character, /get-characters

2. **Flutter app updated for production**
   - `lib/config/environment.dart` created
   - `lib/services/api_service_manager.dart` updated
   - CORS properly configured

3. **Web build created**
   - `build/web/` directory with production build
   - Successfully tested locally

4. **Netlify config files**
   - `netlify.toml` at project root
   - `web/_redirects` file
   - `DEPLOYMENT_INSTRUCTIONS.md` guide

5. **Documentation updated**
   - Environment variables documented
   - Deployment URLs documented
   - Testing checklist completed

---

## 🚨 Common Issues & Solutions

### Issue: "CORS error" in browser console
**Solution:** Add your Netlify domain to `backend/app.py` CORS configuration and redeploy to Railway

### Issue: "Failed to connect to server"
**Solution:** Check `Environment.backendUrl` in `lib/config/environment.dart` - make sure it's the Railway URL, not localhost

### Issue: "404 Not Found" when refreshing page
**Solution:** Ensure `_redirects` file exists in `build/web/` and `netlify.toml` has redirect rules

### Issue: Backend crashes on Railway
**Solution:** Check Railway logs. Usually missing environment variable (GOOGLE_API_KEY)

### Issue: Build takes forever
**Solution:** Run `flutter clean` first, then rebuild

---

## 📋 Acceptance Criteria

### Must Have:
- [ ] Backend successfully deployed to Railway
- [ ] Railway URL documented in `DEPLOYMENT_INSTRUCTIONS.md`
- [ ] Flutter app points to Railway backend (not localhost)
- [ ] Production web build created and tested
- [ ] `netlify.toml` configuration file created
- [ ] Can generate a story in production build using Railway backend
- [ ] No CORS errors
- [ ] No hardcoded localhost URLs

### Nice to Have:
- [ ] Deployment script for automation
- [ ] Environment variable validation
- [ ] Health check endpoint on backend
- [ ] Monitoring/logging setup

### Do NOT:
- ❌ Deploy to Netlify yet (just prepare the config - Darcy will deploy)
- ❌ Change API keys in code (use environment variables only)
- ❌ Modify core app features (focus on deployment setup)
- ❌ Remove localhost support (keep both dev and prod configs)

---

## 🚀 When You're Done

```bash
git add .
git commit -m "Prepare for production deployment

- Deploy Flask backend to Railway
- Add production environment configuration
- Update API URLs to use Railway backend
- Create production web build
- Add Netlify deployment config (netlify.toml, _redirects)
- Add CORS support for production domains
- Create deployment instructions document
- Test production build with Railway backend

Ready for Netlify deployment!

Ref: GEMINI_DEPLOYMENT_TASK.md
Ref: TESTING_AND_DEPLOYMENT.md Week 1 goals"
```

---

## 📚 Reference Documents

- `TESTING_AND_DEPLOYMENT.md` - Overall deployment plan
- Railway docs: https://docs.railway.app/
- Netlify docs: https://docs.netlify.com/
- Flutter web deployment: https://docs.flutter.dev/deployment/web

---

## ❓ Questions?

- **"Which Railway region should I use?"** → US West is usually fastest
- **"Do I need to buy Railway credits?"** → No, free tier is enough for testing
- **"Should I commit .env file?"** → NO! Never commit API keys. Use Railway environment variables
- **"What if Railway deployment fails?"** → Check logs in Railway dashboard, usually missing dependency

---

**Estimated Time:** 2-3 hours
**Priority:** P0 (Critical - blocking public launch)
**Owner:** Gemini
**Reviewer:** Claude / Darcy
**Target:** End of week

**Success = App accessible online, not just localhost! 🌍**
