# Codex Task: Auto-Generate Illustrations for Learning-to-Read Mode

## Priority: HIGH
**Assigned to:** Codex
**Estimated time:** 30-40 minutes
**Status:** Backend ready, need to integrate auto-illustration generation

---

## 🎯 Objective

Enhance the `/generate-story` endpoint to automatically generate illustrations based on subscription tier and story mode. This will make learning-to-read stories more engaging and provide premium value for paid subscribers.

## 💎 Illustration Tiering Strategy

**FREE Tier:**
- ✅ Learning-to-read mode: 1 auto-illustration (educational value)
- ❌ Regular stories: No auto-illustrations (upgrade to Premium)
- ✅ Can use BYOK (Bring Your Own Gemini API Key) for illustrations

**PREMIUM Tier ($9.99/month):**
- ✅ All story modes: 1 auto-illustration
- ✅ Higher quality/more detailed images
- ✅ Interactive stories with illustrations at key choice points

**FAMILY Tier ($14.99/month):**
- ✅ All story modes: 2-3 auto-illustrations
- ✅ Coloring pages auto-generated
- ✅ Option to regenerate/customize illustrations

---

## 📊 Current Status

✅ **Working:**
- `GeminiImageGenerator` class fully implemented (backend/gemini_image_generator.py)
- `/generate-illustrations` endpoint exists and works
- `/generate-coloring-pages` endpoint exists and works
- Story generation returns text successfully

❌ **Missing:**
- Automatic illustration generation for learning-to-read mode
- Illustrations not included in `/generate-story` response
- Users must make separate API call to get images

---

## Task 1: Modify Story Generation to Auto-Generate Illustrations

### 1.1: Update `/generate-story` Endpoint

**File:** `backend/app.py`

**Current behavior (lines 322-329):**
```python
title, wisdom_gem, story_text = story_service._safe_extract_title_and_gem(raw_text, theme)
return jsonify({
    "title": title,
    "story": story_text,
    "story_text": story_text,
    "wisdom_gem": wisdom_gem,
    "used_user_key": using_user_key
}), 200
```

**Add tier-based illustration generation:**

After line 321 (before extracting title/gem), add:

```python
# Auto-generate illustrations based on tier and mode
illustrations = []

# Determine if illustrations should be generated
should_generate_illustrations = False
num_illustrations = 0

# Get user's subscription tier (you'll need to implement tier checking)
# For now, assume tier is passed in payload or retrieved from database
user_tier = payload.get("subscription_tier", "free")  # "free", "premium", "family"

# Tier-based illustration logic
if learning_to_read_mode:
    # Learning-to-read mode: Always include illustration (FREE + all tiers)
    should_generate_illustrations = True
    num_illustrations = 1
    logger.info(f"Learning-to-read mode: Enabling auto-illustration (tier: {user_tier})")

elif user_tier == "premium":
    # Premium: 1 illustration for all stories
    should_generate_illustrations = True
    num_illustrations = 1
    logger.info(f"Premium tier: Enabling auto-illustration")

elif user_tier == "family":
    # Family: 2 illustrations for richer experience
    should_generate_illustrations = True
    num_illustrations = 2
    logger.info(f"Family tier: Enabling {num_illustrations} auto-illustrations")

else:
    # Free tier (non-learning mode): No auto-illustrations
    # But allow BYOK (Bring Your Own Key)
    if user_api_key:
        should_generate_illustrations = True
        num_illustrations = 1
        logger.info(f"Free tier with BYOK: Enabling auto-illustration")
    else:
        logger.info(f"Free tier: No auto-illustration (upgrade to Premium for illustrations)")

# Generate illustrations if enabled
if should_generate_illustrations:
    try:
        # Determine which API key to use for images
        img_generator = None
        if user_api_key:
            img_generator = GeminiImageGenerator(api_key=user_api_key)
        elif image_generator is not None:
            img_generator = image_generator

        if img_generator:
            # Extract a brief scene description from the story for illustration
            scene_preview = raw_text[:200] if raw_text else "A therapeutic story"

            # Adjust style based on tier
            if user_tier == "family":
                style = "vibrant, detailed children's book illustration with rich colors"
            elif user_tier == "premium":
                style = "colorful children's book illustration"
            else:
                style = "simple, colorful children's book illustration for early readers"

            # Generate illustrations
            illustrations = img_generator.generate_story_illustration(
                scene_description=f"{character} in a {theme} story. {scene_preview}",
                character_name=character,
                style=style,
                num_images=num_illustrations,
                age=character_age,
                therapeutic_focus="emotional growth and confidence"
            )

            logger.info(f"Generated {len(illustrations)} illustration(s) for {user_tier} tier")
        else:
            logger.warning("Image generator not available")

    except Exception as e:
        # Don't fail the whole request if illustrations fail
        logger.exception(f"Failed to generate illustrations: {str(e)}")
        illustrations = []
```

**Then update the response (lines 323-329) to:**

```python
title, wisdom_gem, story_text = story_service._safe_extract_title_and_gem(raw_text, theme)

response_data = {
    "title": title,
    "story": story_text,
    "story_text": story_text,
    "wisdom_gem": wisdom_gem,
    "used_user_key": using_user_key
}

# Include illustrations if they were generated
if illustrations:
    response_data["illustrations"] = illustrations
    response_data["illustration_count"] = len(illustrations)

return jsonify(response_data), 200
```

### 1.2: Test the Changes Locally

**Before committing, test that:**
- [ ] Regular stories still work (without `learning_to_read_mode`)
- [ ] Learning-to-read stories return illustrations
- [ ] If image generation fails, story still returns (graceful degradation)

**Test command:**
```bash
# Regular story (no illustrations)
curl -X POST http://localhost:5000/generate-story \
  -H "Content-Type: application/json" \
  -d '{"character":"Luna","theme":"Adventure","character_age":7}'

# Learning-to-read story (WITH illustrations)
curl -X POST http://localhost:5000/generate-story \
  -H "Content-Type: application/json" \
  -d '{"character":"Max","theme":"Adventure","character_age":5,"learning_to_read_mode":true}'
```

**Expected response for learning-to-read:**
```json
{
  "title": "Max's Big Adventure",
  "story": "...",
  "story_text": "...",
  "wisdom_gem": "...",
  "used_user_key": false,
  "illustrations": [
    {
      "id": "uuid_0",
      "prompt": "...",
      "image_data": "base64_encoded_png...",
      "format": "png",
      "generated_at": "2025-11-24T..."
    }
  ],
  "illustration_count": 1
}
```

---

## Task 2: Add Optional Illustration Control

### 2.1: Support `include_illustrations` Parameter

Allow users to explicitly request illustrations for ANY story (not just learning-to-read).

**Add parameter handling (around line 202):**

```python
learning_to_read_mode = payload.get("learning_to_read_mode", False)
include_illustrations = payload.get("include_illustrations", False)

# Auto-enable illustrations for learning-to-read mode
if learning_to_read_mode:
    include_illustrations = True
```

**Update illustration generation check (in the code from 1.1):**

```python
# Auto-generate illustrations if requested or learning-to-read mode
illustrations = []
if include_illustrations:
    # ... (same code as 1.1)
```

This allows:
- `/generate-story` with `learning_to_read_mode=true` → auto illustrations ✅
- `/generate-story` with `include_illustrations=true` → illustrations for any story ✅
- `/generate-story` with neither → no illustrations (faster response) ✅

---

## Task 3: Update Frontend to Display Illustrations

### 3.1: Check Frontend Story Display

**File:** `lib/screens/story_display_screen.dart` (or similar)

**Look for where story text is displayed and add image display:**

```dart
// Add this widget to display illustrations
Widget _buildIllustrations(List<dynamic>? illustrations) {
  if (illustrations == null || illustrations.isEmpty) {
    return SizedBox.shrink();
  }

  return Column(
    children: [
      SizedBox(height: 16),
      Text(
        'Story Illustrations',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 8),
      ...illustrations.map((illustration) {
        final imageData = illustration['image_data'];
        if (imageData == null) return SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Image.memory(
            base64Decode(imageData),
            fit: BoxFit.contain,
          ),
        );
      }).toList(),
    ],
  );
}
```

**In your story display widget:**

```dart
Column(
  children: [
    Text(story.title, style: Theme.of(context).textTheme.headline4),
    SizedBox(height: 16),

    // Display illustrations if available
    _buildIllustrations(story.illustrations),

    SizedBox(height: 16),
    Text(story.storyText),
    SizedBox(height: 16),
    Text(story.wisdomGem, style: TextStyle(fontStyle: FontStyle.italic)),
  ],
)
```

### 3.2: Update Story Model

**File:** `lib/models/story.dart` (or wherever Story model is)

**Add illustrations field:**

```dart
class Story {
  final String title;
  final String storyText;
  final String wisdomGem;
  final List<Map<String, dynamic>>? illustrations;  // Add this

  Story({
    required this.title,
    required this.storyText,
    required this.wisdomGem,
    this.illustrations,  // Add this
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      title: json['title'] ?? '',
      storyText: json['story_text'] ?? json['story'] ?? '',
      wisdomGem: json['wisdom_gem'] ?? '',
      illustrations: json['illustrations'] != null
          ? List<Map<String, dynamic>>.from(json['illustrations'])
          : null,  // Add this
    );
  }
}
```

---

## Task 4: Test End-to-End

### 4.1: Backend Testing on Railway

**After deploying changes:**

```bash
# Test learning-to-read mode on Railway
curl -X POST https://story-weaver-app-production.up.railway.app/generate-story \
  -H "Content-Type: application/json" \
  -d '{
    "character": "Mia",
    "theme": "Friendship",
    "character_age": 5,
    "learning_to_read_mode": true
  }'
```

**Verify response includes:**
- [ ] `illustrations` array with at least 1 image
- [ ] `illustration_count` field
- [ ] Images are base64-encoded PNG data
- [ ] Story text is simple and age-appropriate

### 4.2: Frontend Testing

**On Railway frontend: https://grand-light-production-68d9.up.railway.app**

1. Navigate to story creation
2. Create a character (age 5-7)
3. Enable "Learning to Read" mode
4. Generate story
5. Verify:
   - [ ] Story displays
   - [ ] Illustration(s) display below title
   - [ ] Images are clear and colorful
   - [ ] Page layout looks good with images

### 4.3: Performance Testing

**Check response times:**
```bash
time curl -X POST https://story-weaver-app-production.up.railway.app/generate-story \
  -H "Content-Type: application/json" \
  -d '{"character":"Tim","theme":"Adventure","character_age":6,"learning_to_read_mode":true}'
```

**Expected:**
- [ ] Story + 1 illustration: 8-15 seconds
- [ ] Regular story (no illustrations): 3-8 seconds

**If too slow (>20 seconds):**
- Consider generating illustrations in background task
- Or offer "Generate Illustration" button after story loads

---

## Task 5: Add User Control (Optional Enhancement)

### 5.1: Add Illustration Toggle in UI

**In story creation form:**

```dart
SwitchListTile(
  title: Text('Include Illustrations'),
  subtitle: Text('Generate colorful images with your story'),
  value: _includeIllustrations,
  onChanged: (value) {
    setState(() {
      _includeIllustrations = value;
    });
  },
)
```

**In API call:**

```dart
final response = await http.post(
  Uri.parse('$backendUrl/generate-story'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'character': characterName,
    'theme': theme,
    'character_age': age,
    'learning_to_read_mode': learningToReadMode,
    'include_illustrations': _includeIllustrations,  // Add this
  }),
);
```

---

## Task 6: Update TEAM_COORDINATION.md

After completing all tasks:

```markdown
- 2025-11-24 · Codex → Team: LEARNING-TO-READ ILLUSTRATIONS COMPLETE ✅
  - Modified /generate-story endpoint to auto-generate illustrations when learning_to_read_mode=true
  - Added optional include_illustrations parameter for any story
  - Illustrations generated using GeminiImageGenerator with age-appropriate styling
  - Frontend updated to display illustrations in story view
  - Response includes illustrations array with base64-encoded PNG images
  - Performance tested: Story + illustration generates in 8-15 seconds
  - Graceful degradation: If illustration fails, story still returns
  - User experience: Learning-to-read stories now include vibrant, engaging visuals automatically
  - Status: Ready for production use
```

---

## Verification Checklist

Before marking complete:

- [ ] Backend code modified to generate illustrations for learning-to-read mode
- [ ] Optional `include_illustrations` parameter added
- [ ] Response includes `illustrations` and `illustration_count` fields
- [ ] Frontend model updated to include illustrations
- [ ] Frontend UI displays illustrations in story view
- [ ] Tested locally with both modes (with/without illustrations)
- [ ] Tested on Railway backend
- [ ] Tested end-to-end on Railway frontend
- [ ] Performance acceptable (under 20 seconds with illustrations)
- [ ] Graceful error handling if illustration generation fails
- [ ] TEAM_COORDINATION.md updated with completion status

---

## 🚨 Stop and Alert If:

- ❌ Gemini API quota exceeded (illustrations use significant quota)
- ❌ Response time > 30 seconds consistently
- ❌ Illustration generation fails every time
- ❌ Memory issues on Railway (images are large)
- ❌ Frontend can't decode/display base64 images

---

## Git Commit Template

```bash
git commit -m "[AGENT SYNC | YYYY-MM-DD HH:MM:SS] Feat: Auto-generate illustrations for learning-to-read mode

Enhanced story generation to automatically create illustrations:
- Added auto-illustration for learning_to_read_mode=true
- Added optional include_illustrations parameter
- Updated response to include illustrations array
- Frontend displays illustrations in story view
- Graceful error handling if generation fails

Learning-to-read stories now include vibrant visuals automatically!

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Expected Outcome

✅ **Enhanced Learning Experience:**
- Users select "Learning to Read" mode
- Story generates with text + colorful illustration
- Illustration shows the main character and scene
- Young readers get visual context to support comprehension
- All automatic - no extra API calls needed

**Example response:**
```json
{
  "title": "Mia and the Helpful Butterfly",
  "story": "Mia was a kind girl who loved to help...",
  "wisdom_gem": "Helping others makes your heart happy",
  "used_user_key": false,
  "illustrations": [
    {
      "id": "uuid_123",
      "image_data": "iVBORw0KGgoAAAANSUh...",
      "format": "png",
      "prompt": "Simple, colorful children's book illustration...",
      "generated_at": "2025-11-24T15:30:00"
    }
  ],
  "illustration_count": 1
}
```

**This makes learning-to-read mode significantly more engaging and educational!** 📚✨
