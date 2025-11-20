# Grok Safe Tasks - Round 2

## 🔒 SAFETY RULES (READ FIRST!)

**NEVER:**
- ❌ Rewrite entire files (especially backend/app.py)
- ❌ Change database schemas or models
- ❌ Modify core business logic in services
- ❌ Create new dependencies or install packages
- ❌ Ask for API keys in chat (SECURITY VIOLATION)

**ALWAYS:**
- ✅ Make small, surgical changes to ONE file at a time
- ✅ Test your change immediately after making it
- ✅ If something breaks, revert it with `git checkout <filename>`
- ✅ Read existing code carefully before modifying
- ✅ Keep the same code style and patterns

---

## 📋 Task List for Grok Agent #3

**Goal:** Add helpful error messages and logging (read-only improvements)

### Task 1: Add Better Error Messages to Story Generation
**File:** `backend/app.py`
**Lines:** 198-208 (the try/except block)

**Current code:**
```python
except Exception as e:
    print(f"!!! API ERROR: {type(e).__name__}: {str(e)}")
    # ...
```

**Change:** Add more helpful error messages for common failures:
```python
except Exception as e:
    error_type = type(e).__name__
    error_msg = str(e)
    print(f"!!! API ERROR: {error_type}: {error_msg}")
    print(f"!!! Prompt length: {len(prompt)} characters")

    # Add helpful hints for common errors
    if "404" in error_msg and "model" in error_msg.lower():
        print("!!! HINT: The Gemini model name may be incorrect. Check GEMINI_MODEL in config.")
    elif "quota" in error_msg.lower():
        print("!!! HINT: API quota exceeded. Check your Gemini API usage limits.")
    elif "api key" in error_msg.lower():
        print("!!! HINT: API key may be invalid. Check GEMINI_API_KEY in .env file.")

    print(f"!!! Learning to read mode: {learning_to_read_mode}, Rhyme time mode: {rhyme_time_mode}")
    print(f"!!! Character age: {character_age}, Theme: {theme}")
    logger.error("Model error, using fallback story. Error: %s", e, exc_info=True)
```

**How to test:**
1. Make the change
2. Trigger a story generation from the Flutter app
3. Check the backend terminal output - should see helpful hints

---

### Task 2: Add Request Logging to Character Endpoints
**File:** `backend/app.py`
**Lines:** 296-321 (character endpoints)

**Change:** Add simple logging to each character endpoint:

```python
@limiter.limit("20 per hour")
@app.route("/create-character", methods=["POST"])
def create_character_endpoint():
    logger.info(f"POST /create-character called")  # ADD THIS LINE
    data = request.get_json(silent=True) or {}
    response, status_code = character_service.create_character(data)
    logger.info(f"Character creation result: {status_code}")  # ADD THIS LINE
    return jsonify(response), status_code
```

Do the same for:
- `/characters/<string:char_id>` PATCH/PUT (update)
- `/characters/<string:char_id>` DELETE
- `/get-characters` GET
- `/characters/<string:char_id>` GET

**How to test:**
1. Make the changes
2. Create/fetch/update/delete a character from the Flutter app
3. Check backend logs for the new log messages

---

### Task 3: Add Health Check Details
**File:** `backend/app.py`
**Lines:** 92-95 (health endpoint)

**Current code:**
```python
@app.route("/health", methods=["GET"])
def health():
    print(f"=== Health endpoint called ===")
    return {"status": "ok", "model": GEMINI_MODEL, "has_api_key": bool(api_key)}, 200
```

**Change:** Add more diagnostic info:
```python
@app.route("/health", methods=["GET"])
def health():
    print(f"=== Health endpoint called ===")

    # Add database check
    db_status = "ok"
    try:
        # Simple query to verify database connection
        from .models.user import User
        User.query.limit(1).all()
    except Exception as e:
        db_status = f"error: {str(e)}"

    return {
        "status": "ok",
        "model": GEMINI_MODEL,
        "has_api_key": bool(api_key),
        "database": db_status,
        "environment": app.config.get("ENV", "unknown")
    }, 200
```

**How to test:**
1. Make the change
2. Visit http://127.0.0.1:5000/health in browser
3. Should see JSON with database status and environment

---

## 📋 Task List for Grok Agent #4

**Goal:** Add simple UI improvements (no major refactors)

### Task 1: Add Loading State Text Variety
**File:** `lib/main_story.dart`
**Find:** The `_isGeneratingStory` loading state (around line 800-900)

**Current behavior:** Shows "Weaving your story..." constantly

**Change:** Add rotating messages every 3 seconds:
```dart
// Add this as a class field
final List<String> _loadingMessages = [
  'Weaving your magical story...',
  'Sprinkling in some wonder...',
  'Adding a dash of adventure...',
  'Almost there...',
];
int _loadingMessageIndex = 0;
Timer? _loadingTimer;

// When starting story generation, start the timer
void _startLoadingMessageRotation() {
  _loadingMessageIndex = 0;
  _loadingTimer?.cancel();
  _loadingTimer = Timer.periodic(Duration(seconds: 3), (timer) {
    setState(() {
      _loadingMessageIndex = (_loadingMessageIndex + 1) % _loadingMessages.length;
    });
  });
}

// When story completes, stop the timer
void _stopLoadingMessageRotation() {
  _loadingTimer?.cancel();
}

// In your loading UI, use:
Text(_loadingMessages[_loadingMessageIndex])
```

**How to test:**
1. Make the changes
2. Generate a story
3. Watch the loading message change every 3 seconds

---

### Task 2: Add Character Count to Character List
**File:** `lib/screens/character_list_screen.dart` (if exists) OR wherever characters are displayed

**Change:** Show "You have X/5 characters" at the top of the character list

```dart
// Add at the top of the character grid
Padding(
  padding: const EdgeInsets.all(16.0),
  child: Text(
    'You have ${characters.length}/5 characters',
    style: TextStyle(
      fontSize: 16,
      color: characters.length >= 5 ? Colors.red : Colors.grey[700],
    ),
  ),
)
```

**How to test:**
1. Make the change
2. Open character list
3. Should see character count at top

---

### Task 3: Add Story Generation Error Dialog
**File:** `lib/main_story.dart`
**Find:** Where story generation errors are handled

**Change:** Show a friendly dialog instead of just logging:

```dart
void _showStoryErrorDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Story Generation Failed'),
      content: Text(
        'We had trouble creating your story. Please check your internet connection and try again.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
      ],
    ),
  );
}

// Call this when story generation fails
```

**How to test:**
1. Make the change
2. Turn off backend or internet
3. Try to generate story
4. Should see friendly error dialog

---

## ✅ Completion Checklist

When you finish each task:
- [ ] Task completed
- [ ] Tested manually
- [ ] No errors in console
- [ ] No compilation errors
- [ ] Git status shows only the file you modified

**Report format:**
```
Task X completed:
- File modified: <filename>
- Lines changed: <line numbers>
- Testing result: <what you tested and outcome>
- Any issues: <none or describe>
```

---

## 🆘 If Something Breaks

1. **Don't panic**
2. **Check what file you modified:** `git status`
3. **Revert it:** `git checkout <filename>`
4. **Restart backend/frontend if needed**
5. **Report what happened**

Remember: Small, safe changes are better than ambitious refactors!
