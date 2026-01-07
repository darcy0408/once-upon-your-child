# Avatar Gallery System - Design Document

**Date:** 2026-01-03
**Goal:** Build an AI-generated avatar gallery system that users love
**Timeline:** 2-3 days

---

## 🎯 Overview

### What We're Building
A **pre-generated avatar gallery** where users can:
1. **Browse** ~100 AI-generated avatar images
2. **Pick** one that resonates with them
3. **Customize** it (hair color, outfit color, accessories)
4. **Save** it to their character

### Why This Approach?
✅ **You'll love it** - Full artistic control over quality
✅ **Fast UX** - No waiting for generation
✅ **Consistent quality** - Curated, not random
✅ **Scalable** - Can add themed collections later

---

## 📊 Current State Analysis

### What You Already Have ✅
```
✅ Avatar Generation Service (lib/services/avatar_generation_service.dart)
✅ GeneratedAvatar Model (lib/models/generated_avatar.dart)
✅ Backend Mock Endpoint (/avatar/generate-avatar-mock)
✅ Wizard Character Creation (lib/screens/wizard_steps/hero_creator_step.dart)
✅ Attributes System (hair, skin, outfit, expression)
```

### What You're Missing ❌
```
❌ Pre-generated avatar images
❌ Storage/organization system
❌ Gallery picker UI
❌ Color swap customization
❌ Integration with wizard
```

---

## 🏗️ Architecture

### 1. Avatar Storage Strategy

**Option A: Asset Files (RECOMMENDED)**
```
assets/
  avatars/
    collection_1/
      pixar_01.png         # Base avatar
      pixar_01_meta.json   # Metadata (attributes, colors, etc.)
      pixar_02.png
      pixar_02_meta.json
      ...
    collection_2/
      watercolor_01.png
      watercolor_01_meta.json
      ...
```

**Pros:**
- ✅ No server required
- ✅ Offline-first
- ✅ Fast loading
- ✅ Easy to update

**Cons:**
- ❌ Increases app size (~5-10MB for 100 images)
- ❌ Need to rebuild app to add new avatars

**Option B: Backend Storage**
```
backend/static/avatars/
  Same structure as above
```

**Pros:**
- ✅ Can add avatars without app rebuild
- ✅ Smaller app size
- ✅ Can track popular avatars

**Cons:**
- ❌ Requires internet
- ❌ Need to manage backend storage

**DECISION:** Start with Option A (Assets), migrate to B later if needed

---

### 2. Data Structure

**Avatar Metadata (JSON)**
```json
{
  "id": "pixar_001",
  "filename": "pixar_001.png",
  "style": "pixar",
  "tags": ["happy", "adventurous", "young"],
  "age_range": [6, 10],
  "base_colors": {
    "hair": "#8B4513",
    "skin": "#FDBCB4",
    "clothing": "#4A90E2"
  },
  "customizable": {
    "hair_colors": ["#000000", "#8B4513", "#FFD700", "#FF4500"],
    "clothing_colors": ["#4A90E2", "#50C878", "#FF6B6B", "#FFD700"],
    "accessories": ["glasses", "hat", "headband"]
  },
  "thumbnail": "pixar_001_thumb.png",
  "generated_at": "2026-01-03T12:00:00Z"
}
```

**Gallery Index (JSON)**
```json
{
  "version": 1,
  "collections": [
    {
      "id": "pixar_kids",
      "name": "Pixar Style Kids",
      "description": "3D animated style avatars",
      "count": 25,
      "avatars": [
        "pixar_001",
        "pixar_002",
        ...
      ]
    },
    {
      "id": "watercolor_kids",
      "name": "Watercolor Kids",
      "description": "Soft, painterly style",
      "count": 25,
      "avatars": [...]
    }
  ]
}
```

---

### 3. User Flow

```
┌─────────────────────────────────────┐
│  Wizard: Character Creation         │
│                                     │
│  Step 1: Name & Age                │
│  Step 2: Choose Avatar ◄─── NEW    │
│  Step 3: Personality & Details      │
│  Step 4: Review                     │
└─────────────────────────────────────┘

Step 2 Flow:
┌──────────────────────┐
│ Avatar Gallery       │
│ ┌──┬──┬──┬──┬──┐   │
│ │  │  │  │  │  │   │  ← Grid of thumbnails
│ ├──┼──┼──┼──┼──┤   │
│ │  │  │  │  │  │   │
│ └──┴──┴──┴──┴──┘   │
│                     │
│ [Filter: Age/Style] │
└──────────────────────┘
         ↓ (Tap avatar)
┌──────────────────────┐
│ Avatar Customization │
│                     │
│ ┌─────────────┐    │
│ │   Preview   │    │  ← Large preview
│ └─────────────┘    │
│                     │
│ Hair Color:         │
│ ⚫ 🟤 🟡 🔴       │
│                     │
│ Clothing Color:     │
│ 🔵 🟢 🔴 🟡       │
│                     │
│ Accessories:        │
│ ☑️ Glasses          │
│ ☐ Hat              │
│ ☐ Headband         │
│                     │
│ [Save] [Back]       │
└──────────────────────┘
```

---

## 🎨 Avatar Generation Strategy

### Phase 1: Seed Generation (20-30 avatars)
**Goal:** Create diverse base templates

**Categories:**
1. **Age Groups** (3-5, 6-8, 9-11, 12-14, 15-17)
2. **Styles** (Pixar, Watercolor, Cartoon, Clay)
3. **Personalities** (Adventurous, Shy, Confident, Curious, etc.)

**Distribution:**
```
Pixar Style:
- Ages 3-5: 2 avatars (boy/girl)
- Ages 6-8: 3 avatars (various personalities)
- Ages 9-11: 3 avatars
- Ages 12-14: 2 avatars
- Ages 15-17: 2 avatars
Total: 12 Pixar avatars

Watercolor Style: 12 avatars (same distribution)
Cartoon Style: 12 avatars
Clay Style: 12 avatars

TOTAL PHASE 1: 48 avatars
```

### Phase 2: Variation Generation (50+ more)
**Goal:** Add diversity and choice

**Method:**
- Take best performing seed avatars
- Generate variations (different expressions, poses, outfits)
- Add themed collections (superheroes, fantasy, everyday, etc.)

---

## 🛠️ Implementation Plan

### Day 1: Foundation & Initial Batch

#### 1.1 Set Up Storage System (2 hours)
**Files to create:**
```
assets/avatars/
  gallery_index.json
  collections/
    pixar_kids/
      (empty, will populate)
lib/models/
  avatar_gallery_item.dart
lib/services/
  avatar_gallery_service.dart
```

**avatar_gallery_service.dart:**
- Load gallery index
- Load individual avatar metadata
- Filter avatars by age/style/tags
- Handle customization state

#### 1.2 Generate First Batch (3-4 hours)
**Use your existing backend:**
- Switch from mock to REAL generation
- Generate 12 Pixar avatars (various ages/personalities)
- Save to assets folder
- Create metadata JSON for each

**Script:** `tools/generate_avatar_batch.py`

#### 1.3 Build Basic Gallery UI (2 hours)
**File:** `lib/screens/avatar_gallery_screen.dart`
- Grid view of avatar thumbnails
- Tap to select
- Show selected avatar large
- Simple "Use This Avatar" button

**Total Day 1:** 7-8 hours

---

### Day 2: Customization & Integration

#### 2.1 Add Color Swap System (3 hours)
**File:** `lib/widgets/avatar_customizer.dart`
- Color picker for hair
- Color picker for clothing
- Apply filters to image programmatically
- Preview changes in real-time

**Technique:** Use `ColorFiltered` widget with color matrix

#### 2.2 Add Accessories System (2 hours)
- Overlay PNG accessories (glasses, hats, etc.)
- Toggle on/off
- Position correctly

#### 2.3 Integrate with Wizard (2 hours)
**Modify:** `lib/screens/wizard_steps/hero_creator_step.dart`
- Replace current avatar generation with gallery button
- Navigate to AvatarGalleryScreen
- Save selected avatar + customizations
- Display in wizard preview

**Total Day 2:** 7 hours

---

### Day 3: Expansion & Polish

#### 3.1 Generate More Avatars (4 hours)
- Generate watercolor batch (12)
- Generate cartoon batch (12)
- Generate clay batch (12)
- Total: 48 avatars

#### 3.2 Add Filters & Search (2 hours)
- Age filter
- Style filter
- Personality tags
- Search by keyword

#### 3.3 Polish & Test (2 hours)
- Loading states
- Error handling
- Smooth animations
- End-to-end testing

**Total Day 3:** 8 hours

---

## 💡 Quick Start (Next 2 Hours)

Let's build a proof-of-concept with just 3-5 avatars to show you the vision:

### Step 1: Enable Real Avatar Generation (30 min)
- Configure Gemini API in backend
- Test generation endpoint
- Generate 3 test avatars

### Step 2: Create Gallery Index (15 min)
- Create `assets/avatars/gallery_index.json`
- Add metadata for 3 test avatars

### Step 3: Build Minimal Gallery UI (45 min)
- Simple grid screen
- Load and display 3 avatars
- Select and return to wizard

### Step 4: Quick Integration Test (30 min)
- Add to wizard flow
- Test end-to-end
- Verify it works

**After these 2 hours, you'll see:**
- ✅ Working gallery with real avatars
- ✅ Integrated into your wizard
- ✅ Proof of concept complete

Then we can scale up to 100+ avatars over the next 2 days.

---

## ❓ Questions to Answer

Before we start coding:

1. **Do you have Gemini API configured?**
   - If not, we can use a different service (Replicate, DALL-E, etc.)

2. **What style do you prefer?**
   - Pixar? Watercolor? Cartoon? Clay? Mix?

3. **Asset size concern?**
   - Are you OK with ~10MB of avatar images in the app?
   - Or prefer backend hosting?

4. **Generation budget?**
   - How many API calls can you afford for initial generation?

5. **Want to start with proof-of-concept?**
   - 3-5 avatars in 2 hours to see it working?
   - Then scale to 100+ over next 2 days?

---

Let me know your answers and we'll start building! 🚀
