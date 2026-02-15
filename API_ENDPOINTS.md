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
  "stripe_premium_price": true,
  "stripe_family_price": true,
  "environment": "production"
}
```

**Status Values:**
- `ok`: All systems operational
- `degraded`: Database or API issues (still functional)
- `error`: Critical failure

**Railway Healthcheck:** This endpoint is used by Railway to determine deployment health.

---

### GET /health/database
**Description:** Detailed database connection health check.

**Response (200 OK):**
```json
{
  "status": "ok",
  "pool_size": 5,
  "checked_in": 5,
  "checked_out": 0,
  "overflow": 0
}
```

---

## Story Generation Endpoints

### POST /generate-story
**Description:** Generate a personalized therapeutic story.

**Rate Limit:** Tier-based (varies). See `X-RateLimit-*` headers in responses.

**Request Body:**
```json
{
  "character": "Luna",
  "age": 7,
  "theme": "Adventure",
  "companion": "magical fox",
  "rhyme_time_mode": false,
  "learning_to_read_mode": false,
  "therapeutic_prompt": "dealing with first day of school anxiety",
  "character_details": {
    "fears": ["darkness", "loud noises"],
    "strengths": ["brave", "kind"],
    "likes": ["stars", "animals"],
    "dislikes": ["bugs"],
    "comfort_item": "teddy bear",
    "personality_traits": ["curious", "empathetic"],
    "personality_sliders": {
      "energy": 70,
      "social": 50,
      "structure": 60
    }
  },
  "characters": ["friend1", "friend2"],
  "current_feeling": {
    "emotion": "nervous",
    "intensity": 7
  },
  "user_api_key": "your-gemini-api-key",
  "include_illustrations": false,
  "async_illustrations": false
}
```

**Required Fields:**
- `character` (string): Character name
- `age` (integer): Age for age-appropriate content

**Optional Fields:**
- `theme` (string): Story theme (default: "Adventure")
- `companion` (string): Companion character
- `rhyme_time_mode` (boolean): Generate rhyming story
- `learning_to_read_mode` (boolean): Simple text for early readers
- `therapeutic_prompt` (string): Specific emotional/behavioral focus
- `character_details` (object): Deep personalization
- `characters` (array): Supporting characters
- `current_feeling` (object): Emotional state for therapeutic focus
- `user_api_key` (string): BYOK (Bring Your Own Key)
- `include_illustrations` (boolean): Attempt inline illustration generation
- `async_illustrations` (boolean): Generate illustrations asynchronously (story returns immediately)

**Response (200 OK):**
```json
{
  "title": "Luna and the Magical Adventure",
  "story": "Full story text...",
  "story_text": "Full story text...",
  "wisdom_gem": "Courage means being scared but doing it anyway",
  "used_user_key": false,
  "illustrations": [
    {
      "id": "uuid_123",
      "prompt": "Luna in adventure scene...",
      "image_data": "base64_encoded_png_data",
      "format": "png",
      "generated_at": "2025-11-24T15:30:00"
    }
  ],
  "illustration_count": 1
}
```

**Illustration Behavior:**
- **FREE Tier + learning_to_read_mode:** 1 illustration
- **PREMIUM Tier:** 1 illustration (all modes)
- **FAMILY Tier:** 2 illustrations (all modes)
- **BYOK:** Illustrations available on free tier with user_api_key

**Error Response (500):**
```json
{
  "error": "API key expired. Please renew the API key.",
  "hint": "Check your GEMINI_API_KEY configuration",
  "request_id": "abc123"
}
```

---

### POST /generate-interactive-story
**Description:** Generate the opening segment of an interactive branching story.

**Rate Limit:** 5 per minute

**Request Body:**
```json
{
  "user_id": "user_or_anon_id",
  "character_id": "optional_character_id",
  "theme": "Mystery",
  "tone": "whimsical",
  "length": "medium",
  "age": 10
}
```

**Response (200 OK):**
```json
{
  "story_id": "uuid_story_id",
  "title": "Story Title",
  "segment": {
    "id": "uuid_segment_id",
    "segment_number": 1,
    "content": "Opening segment text...",
    "choices": [
      {
        "id": "uuid_choice_id",
        "choice_number": 1,
        "text": "Choice text..."
      }
    ]
  },
  "inventory": [],
  "state": {},
  "is_completed": false
}
```

**Error Response (400):**
```json
{
  "error": "user_id is required"
}
```

---

### POST /continue-interactive-story
**Description:** Continue an interactive story based on user's choice.

**Rate Limit:** 5 per minute

**Request Body:**
```json
{
  "story_id": "uuid_story_id",
  "choice_id": "uuid_choice_id"
}
```

**Response (200 OK):**
```json
{
  "story_id": "uuid_story_id",
  "title": "Story Title",
  "segment": {
    "id": "uuid_segment_id",
    "segment_number": 2,
    "content": "Next segment text...",
    "choices": [
      {
        "id": "uuid_choice_id",
        "choice_number": 1,
        "text": "Choice text..."
      }
    ]
  },
  "inventory": [],
  "state": {},
  "is_completed": false
}
```

---

## Illustration Endpoints

### POST /generate-illustrations
**Description:** Generate story illustrations for a scene.

**Rate Limit:** Tier-based (varies). See `X-RateLimit-*` headers in responses.

**Request Body:**
```json
{
  "scene_description": "A brave girl exploring an enchanted forest with glowing crystals",
  "character_name": "Luna",
  "style": "vibrant children's book illustration",
  "num_images": 1,
  "age": 7,
  "therapeutic_focus": "courage and confidence",
  "user_api_key": "optional-gemini-key"
}
```

**Response (200 OK):**
```json
{
  "illustrations": [
    {
      "id": "uuid_456",
      "prompt": "Create vibrant, engaging children's book illustration...",
      "image_data": "iVBORw0KGgoAAAANSUh...(base64)",
      "format": "png",
      "generated_at": "2025-11-24T16:00:00"
    }
  ],
  "count": 1,
  "used_user_key": false
}
```

**Error Response (403):**
```json
{
  "error": "Image generation requires an API key",
  "hint": "Please provide your Gemini API key or upgrade to premium"
}
```

---

### POST /generate-coloring-pages
**Description:** Generate therapeutic coloring book pages.

**Rate Limit:** 10 per hour

**Request Body:**
```json
{
  "scene_description": "Luna holding a magic crystal, surrounded by friendly animals",
  "character_name": "Luna",
  "num_images": 1,
  "age": 7,
  "therapeutic_focus": "mindfulness and creativity"
}
```

**Response (200 OK):**
```json
{
  "coloring_pages": [
    {
      "id": "uuid_789",
      "prompt": "Create therapeutic coloring book page...",
      "image_data": "base64_encoded_line_art",
      "format": "png",
      "generated_at": "2025-11-24T16:05:00"
    }
  ],
  "count": 1
}
```

---

## Stripe Payment Endpoints

### POST /api/stripe/create-checkout-session
**Description:** Create a Stripe checkout session for subscription.

**Request Body:**
```json
{
  "tier": "premium",
  "user_id": "user_123"
}
```

**Valid Tiers:**
- `premium`: $9.99/month
- `family`: $14.99/month

**Response (200 OK):**
```json
{
  "checkout_url": "https://checkout.stripe.com/c/pay/cs_test_...",
  "id": "cs_test_a1kCyEU3XTlwRQZ1..."
}
```

**Error Response (400):**
```json
{
  "error": "Invalid subscription tier. Must be 'premium' or 'family'."
}
```

---

### GET /api/stripe/subscription-status/:user_id
**Description:** Get user's current subscription status from Stripe.

**Parameters:**
- `user_id` (path): User identifier

**Response (200 OK):**
```json
{
  "status": "active",
  "tier": "premium",
  "current_period_end": 1735689600,
  "cancel_at_period_end": false
}
```

---

### GET /api/user/:user_id/subscription
**Description:** Get user's internal subscription record.

**Parameters:**
- `user_id` (path): User identifier

**Response (200 OK):**
```json
{
  "user_id": "uuid",
  "tier": "premium",
  "status": "active",
  "current_period_end": "2025-12-24T16:00:00Z",
  "cancel_at_period_end": false
}
```

**Response (200 OK - No Subscription):**
```json
{
  "status": "inactive",
  "tier": "free"
}
```

---

### POST /api/webhooks/stripe
**Description:** Stripe webhook endpoint for subscription events.

**Events Handled:**
- `checkout.session.completed`: New subscription created
- `customer.subscription.updated`: Subscription modified
- `customer.subscription.deleted`: Subscription canceled

**Headers Required:**
- `stripe-signature`: Webhook signature for verification

**Response (200 OK):**
```json
{
  "received": true
}
```

**Note:** This endpoint uses webhook secret verification. Only Stripe servers can successfully call it.

---

## Character Management Endpoints

### GET /get-characters
**Description:** List all characters for the authenticated user.

**Headers:**
- `Authorization`: Bearer JWT_TOKEN

**Response (200 OK):**
```json
[
  {
    "id": "char_uuid",
    "name": "Luna",
    "age": 7,
    "personality_traits": ["brave"],
    "created_at": "2025-11-24T10:00:00Z"
  }
]
```

---

### POST /create-character
**Description:** Create a new character profile.

**Headers:**
- `Authorization`: Bearer JWT_TOKEN

**Request Body:**
```json
{
  "name": "Max",
  "age": 8,
  "traits": ["creative", "funny"],
  "likes": ["dinosaurs"],
  "personality_sliders": {
    "adventure": 80,
    "sociability": 60
  }
}
```

**Response (201 Created):**
```json
{
  "id": "char_uuid",
  "name": "Max",
  "age": 8,
  "created_at": "2025-11-24T16:10:00Z"
}
```

---

### GET /characters/:id
**Description:** Get detailed character information.

**Headers:**
- `Authorization`: Bearer JWT_TOKEN

**Response (200 OK):**
```json
{
  "id": "char_uuid",
  "name": "Luna",
  "age": 7,
  "personality_traits": ["curious", "empathetic"],
  "personality_sliders": {
    "energy": 70,
    "social": 50
  },
  "created_at": "2025-11-24T10:00:00Z"
}
```

---

### PATCH /characters/:id
**Description:** Update character details (partial update).

**Headers:**
- `Authorization`: Bearer JWT_TOKEN

**Request Body:** (all fields optional)
```json
{
  "traits": ["brave", "kind", "helpful"]
}
```

**Response (200 OK):**
```json
{
  "id": "char_uuid",
  "name": "Luna",
  "personality_traits": ["brave", "kind", "helpful"]
}
```

---

### DELETE /characters/:id
**Description:** Delete a character profile.

**Headers:**
- `Authorization`: Bearer JWT_TOKEN

**Response (200 OK):**
```json
{
  "status": "deleted",
  "id": "char_uuid"
}
```

---

## Copy-Paste API Examples

### POST /generate-story
```bash
curl -X POST https://story-weaver-app-production.up.railway.app/generate-story \
  -H "Content-Type: application/json" \
  -d '{
    "character": "Luna",
    "age": 7,
    "theme": "Adventure"
  }'
```

**Success (200):**
```json
{
  "status": "complete",
  "story": {
    "title": "Luna and the Starlight Path",
    "story_text": "Once upon a time..."
  },
  "task_id": "sync_task"
}
```

**Error (400):**
```json
{
  "error": "character_id or character is required"
}
```

### POST /create-character
```bash
curl -X POST https://story-weaver-app-production.up.railway.app/create-character \
  -H "Authorization: Bearer YOUR_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Luna",
    "age": 7
  }'
```

**Success (201):**
```json
{
  "id": "char_123",
  "name": "Luna",
  "age": 7
}
```

**Error (400):**
```json
{
  "error": "Missing required field(s): age"
}
```

### GET /get-characters
```bash
curl -X GET https://story-weaver-app-production.up.railway.app/get-characters \
  -H "Authorization: Bearer YOUR_JWT"
```

**Success (200):**
```json
[
  {
    "id": "char_123",
    "name": "Luna",
    "age": 7
  }
]
```

### PATCH /characters/:id
```bash
curl -X PATCH https://story-weaver-app-production.up.railway.app/characters/char_123 \
  -H "Authorization: Bearer YOUR_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Luna Updated"
  }'
```

**Success (200):**
```json
{
  "id": "char_123",
  "age": 8
}
```

**Error (404):**
```json
{
  "error": "Character not found"
}
```

### DELETE /characters/:id
```bash
curl -X DELETE https://story-weaver-app-production.up.railway.app/characters/char_123 \
  -H "Authorization: Bearer YOUR_JWT"
```

**Success (200):**
```json
{
  "status": "deleted",
  "id": "char_123"
}
```

**Error (403):**
```json
{
  "error": "Unauthorized"
}
```

### GET /api/user/:user_id/subscription
```bash
curl -X GET https://story-weaver-app-production.up.railway.app/api/user/user_123/subscription
```

**Success (200):**
```json
{
  "user_id": "user_123",
  "tier": "premium",
  "status": "active",
  "current_period_end": "2025-12-24T16:00:00Z",
  "cancel_at_period_end": false
}
```

**Error (404):**
```json
{
  "error": "User not found"
}
```

### GET /api/stripe/subscription-status/:user_id
```bash
curl -X GET https://story-weaver-app-production.up.railway.app/api/stripe/subscription-status/user_123 \
  -H "Authorization: Bearer YOUR_JWT"
```

**Success (200):**
```json
{
  "status": "active",
  "tier": "premium",
  "current_period_end": 1735689600,
  "cancel_at_period_end": false
}
```

### POST /api/user/:user_id/cancel-subscription
```bash
curl -X POST https://story-weaver-app-production.up.railway.app/api/user/user_123/cancel-subscription \
  -H "Authorization: Bearer YOUR_JWT"
```

**Success (200):**
```json
{
  "success": true,
  "message": "Subscription will be canceled at period end",
  "cancel_at_period_end": true
}
```

---

## Rate Limits

| Endpoint | Limit |
|----------|-------|
| `/generate-story` | Tier-based (varies) |
| `/generate-interactive-story` | 5 per minute |
| `/continue-interactive-story` | 5 per minute |
| `/generate-illustrations` | Tier-based (varies) |
| `/generate-coloring-pages` | 10 per hour |
| `/create-character` | 20 per hour |
| `/characters/:id` (PATCH/PUT) | 30 per hour |
| `/characters/:id` (DELETE) | 10 per hour |
| `/api/user/:user_id/subscription` | 60 per minute |
| `/api/user/:user_id/usage-stats` | 60 per minute |
| `/api/user/:user_id/cancel-subscription` | 5 per hour |

**Rate Limit Headers:**
```
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 8
X-RateLimit-Reset: 1700000000
```

**Rate Limit Exceeded (429):**
```json
{
  "error": "Rate limit exceeded",
  "retry_after": 45
}
```

---

## Error Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Created (new resource) |
| 204 | No Content (successful deletion) |
| 400 | Bad Request (invalid parameters) |
| 403 | Forbidden (API key issues, permission denied) |
| 404 | Not Found (resource doesn't exist) |
| 429 | Too Many Requests (rate limit exceeded) |
| 500 | Internal Server Error (server-side issue) |
| 503 | Service Unavailable (temporarily down) |

---

## Authentication

**Current Implementation:**
Some endpoints require a valid JWT (JSON Web Token) in the `Authorization` header.

**Header Format:**
`Authorization: Bearer <your_jwt_token>`

**Protected Endpoints:**
- Character management endpoints: `/create-character`, `/get-characters`, `/characters/:id`
- Stripe subscription status: `/api/stripe/subscription-status/:user_id`
- User actions: `/api/user/:user_id/usage-stats`, `/api/user/:user_id/cancel-subscription`
- Some administrative endpoints

**Public Endpoints:**
- `/health`
- `/version`
- `/auth/login` (to obtain JWT)
- `/auth/anonymous` (to obtain temporary JWT)
- Story generation endpoints: `/generate-story`, `/generate-interactive-story`, `/continue-interactive-story`

---

## CORS Configuration

**Allowed Origins:**
- Production Frontend: `https://grand-light-production-68d9.up.railway.app`

**Allowed Methods:**
- GET, POST, PUT, DELETE, OPTIONS

**Allowed Headers:**
- Content-Type, Authorization

---

## Environment Variables

**Required:**
- `GEMINI_API_KEY`: Google Gemini API key
- `DATABASE_URL`: PostgreSQL connection string
- `STRIPE_API_KEY`: Stripe secret key (sk_test_ or sk_live_)
- `STRIPE_PRICE_ID_PREMIUM`: Premium subscription price ID
- `STRIPE_PRICE_ID_FAMILY`: Family subscription price ID
- `STRIPE_WEBHOOK_SECRET`: Webhook signing secret

**Optional:**
- `GEMINI_MODEL`: Model name (default: gemini-2.0-flash)
- `ALLOWED_ORIGINS`: CORS origins (comma-separated)
- `RAILWAY_ENVIRONMENT`: Environment name

---

## Webhook Endpoints

### Stripe Webhooks

**URL:** `https://story-weaver-app-production.up.railway.app/api/webhooks/stripe`

**Events to Subscribe:**
- `checkout.session.completed`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_succeeded`
- `invoice.payment_failed`

**Configuration:**
1. Go to Stripe Dashboard → Developers → Webhooks
2. Add endpoint with URL above
3. Select events
4. Copy webhook signing secret to `STRIPE_WEBHOOK_SECRET`

---

## Testing

**Health Check:**
```bash
curl https://story-weaver-app-production.up.railway.app/health
```

**Generate Story:**
```bash
curl -X POST https://story-weaver-app-production.up.railway.app/generate-story \
  -H "Content-Type: application/json" \
  -d '{"character":"Test","age":7,"theme":"Adventure"}'
```

**Create Stripe Checkout:**
```bash
curl -X POST https://story-weaver-app-production.up.railway.app/api/stripe/create-checkout-session \
  -H "Content-Type: application/json" \
  -d '{"tier":"premium","user_id":"test_user"}'
```

---

## Changelog

**v1.0.2 (2025-11-24):**
- Added tier-based illustration generation
- Fixed SQLAlchemy 2.0 compatibility in health endpoint
- Enhanced health endpoint with Stripe configuration status
- Added timestamp and version to health response

**v1.0.1 (2025-11-23):**
- Fixed interactive story endpoints
- Added stripe_configured to health check
- Improved error handling

**v1.0.0 (2025-11-22):**
- Initial production release
- Story generation with therapeutic focus
- Interactive branching stories
- Stripe subscription integration
- Illustration and coloring page generation

---

## Support

**Issues:** GitHub Issues (if repository is public)
**Email:** [Your support email]
**Documentation:** This file

---

**Last Updated:** 2026-02-15
**API Version:** 1.0.2
**Status:** Production Ready ✅
