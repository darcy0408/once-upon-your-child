# Story Weaver - Testing & Deployment Guide

## 🧪 Quick Test (5 minutes)

### Test 1: Backend API
```bash
cd C:\dev\story-weaver-app\backend
python app.py
```
**Expected:** Server starts on `http://localhost:5000`
**Test URL:** Visit `http://localhost:5000` in browser - should see "Story Creator API is running"

### Test 2: Flutter App (Chrome Web)
```bash
cd C:\dev\story-weaver-app
flutter run -d chrome
```
**Expected:** App opens in Chrome browser
**What to test:**
- [ ] App loads without crashes
- [ ] Can create a new character
- [ ] Can customize character avatar
- [ ] "Create Story" button appears
- [ ] Can navigate to saved stories

### Test 3: Generate a Story
1. Create a character (name, age, role)
2. Choose a therapeutic theme (e.g., "Anxiety", "Friendship")
3. Click "Create My Story!"
4. **Expected:** Story generates and displays

---

## 📋 Pre-Deployment Checklist

### Phase 1: Core Functionality (1-2 days)
- [ ] **Fix compilation errors**
  - Remove `character_gallery_screen.dart` references to `currentFeeling`
  - Test on Chrome, Android emulator, iOS simulator
- [ ] **Test backend connection**
  - Verify `/generate-story` endpoint works
  - Test with multiple characters
  - Test therapeutic customization
- [ ] **Test key features**
  - Character creation & avatar customization
  - Story generation (multiple themes)
  - Save/load stories
  - Feelings wheel
  - Coloring book

### Phase 2: Polish & Bug Fixes (2-3 days)
- [ ] **UI/UX improvements**
  - Fix any layout issues on mobile
  - Test on different screen sizes
  - Ensure buttons/text are readable
- [ ] **Error handling**
  - Handle API failures gracefully
  - Show loading indicators
  - Add retry mechanisms
- [ ] **Performance**
  - Story generation < 10 seconds
  - App launch < 3 seconds
  - Smooth scrolling

### Phase 3: Deployment Prep (2-3 days)
- [ ] **Backend deployment**
  - Deploy Flask API to cloud (Heroku, Railway, or Google Cloud)
  - Set up environment variables for API keys
  - Test production API
- [ ] **App store assets**
  - Create app icon (512x512, 1024x1024)
  - Take 5-7 screenshots for store listing
  - Write app description
  - Privacy policy page
- [ ] **Build for stores**
  - Android: `flutter build appbundle`
  - iOS: `flutter build ipa`
  - Test release builds

---

## 🚀 Deployment Options

### Option 1: Flutter Web (Fastest - Deploy Today!)
**Time:** 1-2 hours
**Cost:** Free

```bash
flutter build web --release
# Upload to Netlify, Vercel, or GitHub Pages
```

**Pros:**
- No app store approval needed
- Instant updates
- Works on all devices

**Cons:**
- No native features (notifications, etc.)
- Requires internet

### Option 2: Android (Google Play Store)
**Time:** 3-5 days (including review)
**Cost:** $25 one-time fee

```bash
flutter build appbundle --release
# Upload to Google Play Console
```

**Steps:**
1. Create Google Play Developer account
2. Create app listing
3. Upload AAB file
4. Submit for review (1-3 days)

### Option 3: iOS (Apple App Store)
**Time:** 5-7 days (including review)
**Cost:** $99/year

```bash
flutter build ipa --release
# Upload via Xcode or Transporter app
```

**Steps:**
1. Apple Developer account
2. Create app listing in App Store Connect
3. Upload IPA
4. Submit for review (2-5 days)

---

## ⚡ Recommended: Start with Web

1. **Today:** Deploy web version to Netlify
2. **This week:** Fix bugs based on user feedback
3. **Next week:** Submit to Google Play
4. **Following week:** Submit to Apple App Store

---

## 🐛 Known Issues to Fix

1. **character_gallery_screen.dart** - References `currentFeeling` field that doesn't exist
   - **Fix:** Remove feelings wheel integration from gallery (save for v2)

2. **Missing read-aloud feature** - Removed to avoid analytics bloat
   - **Fix:** Add simple TTS feature (no analytics) in v2

3. **Some deprecation warnings** - Flutter uses old color APIs
   - **Fix:** Can ignore for now, won't affect functionality

---

## 📞 Backend Deployment (Required for Production)

Your Flask backend must be deployed to a cloud service. Options:

### Railway (Recommended - Free tier)
```bash
# Install Railway CLI
npm install -g @railway/cli

# Deploy backend
cd backend
railway login
railway init
railway up
```

### Heroku
```bash
# Create Procfile in backend/
echo "web: python app.py" > Procfile

# Deploy
heroku create story-weaver-api
git push heroku main
```

### Update Flutter App
Once backend is deployed, update the API URL in `lib/main_story.dart`:
```dart
// Change from:
final response = await http.post(
  Uri.parse('http://localhost:5000/generate-story'),

// To:
final response = await http.post(
  Uri.parse('https://your-backend-url.railway.app/generate-story'),
```

---

## 📈 Success Metrics

Before deploying, ensure:
- ✅ App loads in < 3 seconds
- ✅ Story generates in < 15 seconds
- ✅ No crashes during 10-minute session
- ✅ Can create 5 characters without issues
- ✅ Saved stories persist after app restart

---

## 🎯 MVP Timeline (Quick Deploy)

**Week 1:**
- Day 1-2: Fix compilation errors, test locally
- Day 3-4: Deploy backend to Railway
- Day 5: Build and test web version
- Day 6-7: Deploy to Netlify, share with beta testers

**Week 2:**
- Day 1-3: Collect feedback, fix critical bugs
- Day 4-5: Prepare Android build + assets
- Day 6-7: Submit to Google Play

**Week 3:**
- Day 1-3: Prepare iOS build + assets
- Day 4-5: Submit to App Store
- Day 6-7: Monitor reviews, plan v2 features

---

## 🔑 API Keys Needed

Before deploying, set up:
- [ ] Google Gemini API key (for AI story generation)
- [ ] (Optional) OpenRouter API key (backup AI service)

Add to `backend/.env`:
```
GOOGLE_API_KEY=your_gemini_key_here
OPENROUTER_API_KEY=your_openrouter_key_here
```

---

Need help with any of these steps? Ask Claude Code!
