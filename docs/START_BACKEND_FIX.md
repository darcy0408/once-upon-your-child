# 🔧 Fix: Backend Using Gemini 2.0 Flash Exp (Free Model)

**Problem:** Backend shows `gemini-1.5-flash` (deprecated) instead of `gemini-2.0-flash-exp` (free)

**Cause:** You have a `GEMINI_MODEL` environment variable set that overrides the code default

---

## ✅ Quick Fix (Recommended)

### Option 1: Set Environment Variable for This Session

**PowerShell:**
```powershell
$env:GEMINI_MODEL = "gemini-2.0-flash-exp"
cd C:\dev\story-weaver-app\backend
python app.py
```

**Command Prompt:**
```cmd
set GEMINI_MODEL=gemini-2.0-flash-exp
cd C:\dev\story-weaver-app\backend
python app.py
```

---

### Option 2: Use start_backend.bat (Edit It)

Edit `backend/start_backend.bat` (if it exists) or create it:

```batch
@echo off
echo Starting Story Weaver Backend with Gemini 2.0 Flash Exp...
set GEMINI_MODEL=gemini-2.0-flash-exp
cd /d %~dp0
python app.py
pause
```

Then just double-click `start_backend.bat` to run!

---

### Option 3: Remove System Environment Variable (Permanent Fix)

If you want to permanently change it:

1. **Open System Environment Variables:**
   - Press `Win + R`
   - Type `sysdm.cpl` and press Enter
   - Go to "Advanced" tab
   - Click "Environment Variables"

2. **Find and Edit GEMINI_MODEL:**
   - Look in "User variables" or "System variables"
   - Find `GEMINI_MODEL`
   - Change value to: `gemini-2.0-flash-exp`
   - OR delete the variable to use code default

3. **Restart your terminal** for changes to take effect

---

## 🔍 Verify It's Working

After starting the backend, you should see:

```
DEBUG: GEMINI_MODEL set to gemini-2.0-flash-exp
Gemini model 'gemini-2.0-flash-exp' initialized successfully.
```

**NOT:**
```
DEBUG: GEMINI_MODEL set to gemini-1.5-flash  ❌ WRONG
```

---

## 💰 Why Gemini 2.0 Flash Exp?

| Feature | gemini-1.5-flash | gemini-2.0-flash-exp |
|---------|------------------|----------------------|
| **Status** | Being deprecated ⚠️ | Active, experimental ✅ |
| **Cost** | $0.075 per 1M input tokens | **FREE** 🎉 |
| **Performance** | Good | **Better** ⚡ |
| **Features** | Standard | **Latest** 🆕 |

---

## 📊 Current Code Defaults (Already Updated)

✅ `backend/config.py` → `gemini-2.0-flash-exp`
✅ `backend/config/__init__.py` → `gemini-2.0-flash-exp`
✅ `backend/cost_tracking.py` → `gemini-2.0-flash-exp`

**The code is ready - just need to override your environment variable!**

---

## 🚀 Quick Start Command

**Copy and paste this:**

```powershell
# PowerShell
$env:GEMINI_MODEL = "gemini-2.0-flash-exp"
cd C:\dev\story-weaver-app\backend
python app.py
```

**You're done!** Backend will now use the free Gemini 2.0 model. 🎉
