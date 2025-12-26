# Mock Testing Guide - Free Testing Without API Costs

## Latest Gemini API Pricing (December 2025)

### Important Changes
Google **drastically reduced** free tier limits in December 2025:

**Before December 2025:**
- Gemini 2.5 Flash: ~250 requests/day (free)

**After December 2025:**
- Gemini 2.5 Flash: **20 requests/day** (92% reduction!)
- Gemini 2.5 Flash-Lite: 1,000 requests/day
- Gemini 2.5 Pro: 50 requests/day (many accounts lost free access entirely)

**Your Current Model:** `gemini-2.0-flash-exp`
- Free tier: **15 requests/minute**, **1,500 requests/day**
- BUT experimental models can be discontinued at any time

### Paid Pricing (If You Enable Billing)

**Gemini 2.5 Flash** (recommended for production):
- Input: $0.30 per 1M tokens ($0.0003 per 1K tokens)
- Output: $2.50 per 1M tokens ($0.0025 per 1K tokens)

**Cost Per Story Generation:**
- Average prompt: 7,000 tokens = $0.0021 input
- Average story: 500 tokens = $0.00125 output
- **Total: ~$0.0034 (1/3 of a penny)**

**Cost Per Avatar/Image:**
- Average prompt: 500 tokens = $0.00015
- Image generation uses same text pricing
- **Total: ~$0.0002 (1/50 of a penny)**

---

## How Mock Testing Works

Your app **already has** mock endpoints built in! Here's how to use them:

### 1. Mock Story Generation (Already Working!)

**Endpoint:** `POST /generate-story-mock`

**Already used in your tests:**
```python
# From run_phase3_tests.py line 80
response = requests.post(
    f"{BACKEND_URL}/generate-story-mock",  # Mock endpoint
    json=payload,
    timeout=10
)
```

**Returns instant mock story** - $0 cost, 0 API calls!

---

## Setting Up Mock Testing for Your Agents

### Option 1: Environment Variable Control (Recommended)

Create a smart service that checks for mock mode:

**1. Add to backend/.env:**
```bash
# Testing mode - uses mock data, no API calls
MOCK_TESTING_MODE=true

# When false, uses real Gemini API
# MOCK_TESTING_MODE=false
```

**2. Update backend/config/__init__.py:**
```python
class Config:
    # Add mock testing flag
    MOCK_TESTING_MODE = os.environ.get('MOCK_TESTING_MODE', 'false').lower() == 'true'

    # Existing config...
    GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')
    GEMINI_MODEL = os.environ.get('GEMINI_MODEL') or 'gemini-2.0-flash-exp'
```

**3. Update story service to check mock mode:**
```python
# In backend/services/story_service.py
def generate_story(self, ...):
    from flask import current_app

    # Check if mock testing is enabled
    if current_app.config.get('MOCK_TESTING_MODE', False):
        logger.info("MOCK MODE: Returning mock story without API call")
        return self._generate_mock_story(...)

    # Otherwise use real API
    return self._generate_real_story(...)
```

---

### Option 2: Use Mock Endpoint Directly (Easiest)

**In your tests:**
```python
# FREE - Use mock endpoint
response = requests.post(
    f"{BACKEND_URL}/generate-story-mock",
    json=payload
)

# COSTS MONEY - Real API endpoint
response = requests.post(
    f"{BACKEND_URL}/generate-story",
    json=payload
)
```

**In your Flutter app:**
```dart
// Development mode
final endpoint = kDebugMode
    ? '/generate-story-mock'  // FREE
    : '/generate-story';       // Real API

final response = await http.post(
    Uri.parse('$baseUrl$endpoint'),
    body: jsonEncode(payload),
);
```

---

## Mock Image/Avatar Generation

**Current situation:** No mock endpoint exists yet for images/avatars.

**Solution:** Add mock image endpoints similar to mock story.

**I can create this for you!** Would you like me to:
1. Add a `/generate-avatar-mock` endpoint
2. Add a `/generate-illustration-mock` endpoint
3. Return base64-encoded placeholder images

This would give you **100% free testing** for the entire app!

---

## Recommended Testing Strategy

### Phase 1: Development (100% Free)
```bash
# Set mock mode
set MOCK_TESTING_MODE=true

# Run unlimited tests
python run_phase3_tests.py       # FREE
flutter test                      # FREE
flutter run -d chrome             # FREE (mock endpoints)
```

**Cost: $0.00**

### Phase 2: Pre-Production (Minimal Cost)
```bash
# Use real API sparingly
set MOCK_TESTING_MODE=false

# Test 5-10 real stories to verify quality
python test_pick_a_path_improvements.py  # ~$0.034

# Test 2-3 real avatar generations
# (Need to create test script)           # ~$0.0006
```

**Cost: $0.035 (3.5 cents)**

### Phase 3: Production (Pay-As-You-Go)
Enable billing on Gemini API:
- Get $300 free credits for 90 days
- After credits: Pay only for what you use
- ~$0.0034 per story + $0.0002 per image

**Expected monthly cost** (based on usage):
- 100 stories: $0.34
- 500 stories: $1.70
- 1,000 stories: $3.40
- 5,000 stories: $17.00

---

## How to Enable Billing (When Ready)

1. Go to: https://console.cloud.google.com/
2. Select your project
3. Go to "Billing" → "Link a Billing Account"
4. Add credit card
5. You get **$300 free credits** for 90 days!

After free credits expire:
- Only pay for actual usage
- Can set budget alerts (e.g., "$10/month")
- Can set hard spending caps

---

## Monitoring Your Usage

**Free Dashboard:**
https://ai.google.dev/gemini-api/docs/api-key

**Shows:**
- Requests per minute/day
- Token usage
- When quotas reset
- Current tier (free/paid)

**Quota Reset Times:**
- Per minute: Resets every 60 seconds
- Per day: Resets at midnight UTC

**Your error said:** "Please retry in 26.56s"
- This means wait ~27 seconds and try again
- You hit the 15 requests/minute limit

---

## Quick Commands for You Right Now

### To Test with Mock (FREE):
```bash
# Update run_phase3_tests.py to use mock endpoints
# (Already partially using /generate-story-mock!)

# Run tests
python run_phase3_tests.py  # FREE!
```

### To Test with Real API (After Quota Reset):
```bash
# Wait 60 seconds for quota reset
timeout /t 60 /nobreak

# Test ONE story generation
python test_pick_a_path_improvements.py
# Cost: ~$0.0007 (less than 1 cent)
```

### To Set Up Mock Mode Permanently:
```bash
# Add to backend/.env
echo MOCK_TESTING_MODE=true >> backend\.env

# Then I can update the code to check this flag
```

---

## Sources

Gemini API pricing and quota information:
- [Gemini API Pricing (Official)](https://ai.google.dev/gemini-api/docs/pricing)
- [Free Tier Changes December 2025](https://www.cometapi.com/is-free-gemini-2-5-pro-api-fried-changes-to-the-free-quota-in-2025/)
- [Gemini 2.0 Pricing Guide](https://neuroflash.com/blog/gemini-2-0-pricing/)
- [Free Tier Limit Changes](https://www.howtogeek.com/gemini-slashed-free-api-limits-what-to-use-instead/)
- [Gemini API Free Tier 2025 Guide](https://blog.laozhang.ai/api-guides/gemini-api-free-tier/)

---

## Next Steps

Would you like me to:

1. **Add mock image/avatar endpoints** - Get 100% free testing for entire app
2. **Update your test scripts** - Automatically use mock mode in development
3. **Add usage tracking** - Log how many API calls you're making
4. **Set up budget alerts** - Get notified before spending too much

Let me know and I'll implement it!
