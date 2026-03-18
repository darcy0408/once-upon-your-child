# Story Weaver API Endpoints Documentation

## Base URLs

**Production:**
- Frontend: https://grand-light-production-68d9.up.railway.app
- Backend: https://story-weaver-app-production.up.railway.app

---

## Health & Monitoring Endpoints

### GET /health
**Description:** System health check endpoint for monitoring.

**Response (200 OK):**
```json
{
  "status": "ok",
  "timestamp": "2025-11-24T23:34:13.734152",
  "version": "1.0.2",
  "database": "ok",
  "has_api_key": true,
  "model": "gemini-2.0-flash",
  "stripe_configured": true,
  "environment": "production"
}
```

---

## Authentication Endpoints

### POST /auth/anonymous
**Description:** Obtain a temporary JWT for guest users.

**Response (200 OK):**
```json
{
  "access_token": "eyJhbG...",
  "user_id": "anon_123"
}
```

---

## Story Generation Endpoints

### POST /generate-story
**Description:** Generate a personalized therapeutic story.

**Request Body:**
```json
{
  "character": "Luna",
  "age": 7,
  "theme": "Adventure",
  "rhyme_time_mode": false,
  "learning_to_read_mode": false,
  "therapeutic_prompt": "dealing with first day of school anxiety"
}
```

**Response (200 OK):**
```json
{
  "title": "Luna and the Starlight Path",
  "story_text": "Once upon a time...",
  "wisdom_gem": "Courage means being scared but doing it anyway"
}
```

---

## Character Management Endpoints

### GET /get-characters
**Description:** List all characters for the authenticated user.

**Headers:**
- `Authorization`: Bearer JWT_TOKEN

---

### POST /create-character
**Description:** Create a new character profile.

**Request Body:**
```json
{
  "name": "Max",
  "age": 8,
  "traits": ["creative", "funny"]
}
```

---

### PATCH /characters/:id
**Description:** Update character details.

---

### DELETE /characters/:id
**Description:** Delete a character profile.

---

## Avatar & Gallery Endpoints

### GET /avatar/gallery/list-avatars
**Description:** List curated avatars available in the public gallery.

---

### POST /avatar/generate-avatar
**Description:** Generate a new custom avatar.

---

## Achievement & Progression Endpoints

### GET /achievement/stats
**Description:** Get user achievement statistics and totals.

---

### POST /achievement/sync
**Description:** Sync achievements from client to server.

---

## Stripe & Subscription Endpoints

### GET /api/user/:user_id/subscription
**Description:** Get internal subscription record.

---

### GET /api/stripe/subscription-status/:user_id
**Description:** Get user's current subscription status from Stripe.

---

**Last Updated:** 2026-03-06
**API Version:** 1.0.2
**Status:** Production Ready ✅
