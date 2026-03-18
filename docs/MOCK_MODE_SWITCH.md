# How to Switch Between Mock and Real Avatar Generation

## Quick Reference

**File to Edit**: `backend/.env` (line 5)

---

## Mock Mode (Testing - FREE)

**Use for**: Testing UI, development, zero cost

**Set in `backend/.env`**:
```bash
MOCK_TESTING_MODE=true
```

**What happens**:
- Instant placeholder avatars (1ms)
- No API calls
- Cost: $0.00
- Perfect for testing

---

## Real Mode (AI Generation)

**Use for**: Production, real avatars

**Set in `backend/.env`**:
```bash
MOCK_TESTING_MODE=false
```

**What happens**:
1. Tries Gemini first (FREE tier)
2. Falls back to OpenRouter if Gemini fails ($0.003/avatar)
3. Real AI-generated avatars (10-60s)

---

## Step-by-Step Instructions

### To Enable Real Avatar Generation:

1. Open `backend/.env`
2. Find line 5: `MOCK_TESTING_MODE=true`
3. Change to: `MOCK_TESTING_MODE=false`
4. Save file
5. Restart backend:
   ```bash
   # Press Ctrl+C in backend terminal
   python app.py
   ```

### To Switch Back to Mock Mode:

1. Open `backend/.env`
2. Find line 5: `MOCK_TESTING_MODE=false`
3. Change to: `MOCK_TESTING_MODE=true`
4. Save file
5. Restart backend:
   ```bash
   # Press Ctrl+C in backend terminal
   python app.py
   ```

---

## Verify Current Mode

Check which mode you're in:

```bash
curl http://localhost:5000/usage/mock-mode
```

**Response if Mock Mode ON**:
```json
{
  "mock_testing_mode": true,
  "message": "Mock mode is ENABLED - using free mock endpoints"
}
```

**Response if Mock Mode OFF**:
```json
{
  "mock_testing_mode": false,
  "message": "Mock mode is DISABLED - using real API endpoints"
}
```

---

## API Keys Required

### Mock Mode:
- ✅ No API keys needed
- ✅ Works out of the box

### Real Mode:
- ✅ Gemini API key (already in `.env`)
- ✅ OpenRouter API key (already in `.env`)

---

## Cost Comparison

| Mode | Cost per Avatar | Speed | Quality |
|------|----------------|-------|---------|
| Mock | $0.00 | 1ms | Placeholder |
| Real (Gemini) | $0.00 (FREE tier) | 20-60s | Excellent |
| Real (OpenRouter) | $0.003 | 10-30s | Very Good |

---

## Testing Workflow

**Recommended**:
1. Start with Mock Mode (FREE testing)
2. Test UI flow, verify everything works
3. Switch to Real Mode
4. Generate 1-2 test avatars
5. If quality good, continue with real mode
6. Switch back to Mock for more UI testing

---

## Troubleshooting

### "Mock mode not changing"
- Make sure you saved the `.env` file
- Restart backend (Ctrl+C, then `python app.py`)
- Verify with: `curl http://localhost:5000/usage/mock-mode`

### "Avatar generation still slow in mock mode"
- Frontend might be calling real endpoint instead of mock
- Check `lib/services/avatar_generation_service.dart:27`
- Should use: `/avatar/generate-avatar-mock`

### "Backend not responding"
```bash
# Restart backend
cd backend
python app.py
```

---

## Current Configuration

**Your `.env` file**:
```bash
GEMINI_API_KEY="AIzaSyA..."  ✅ Set
OPENROUTER_API_KEY="sk-or-v1-..."  ✅ Set
MOCK_TESTING_MODE=true  ← Change this line
```

**Status**: ✅ Ready for both Mock and Real modes
**Fallback**: ✅ OpenRouter configured as backup

---

## Quick Commands

```bash
# Check current mode
curl http://localhost:5000/usage/mock-mode

# Test mock avatar (instant)
curl -X POST http://localhost:5000/avatar/generate-avatar-mock \
  -H "Content-Type: application/json" \
  -d '{"character_name": "Test", "age": 8, "style": "pixar"}'

# Restart backend
# Press Ctrl+C, then:
python app.py
```

---

**Remember**: Always restart backend after changing `.env` file!
