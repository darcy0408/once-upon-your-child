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
