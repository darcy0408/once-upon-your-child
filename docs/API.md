# Story Weaver App - API Documentation

**Last Updated:** 2025-11-15

This document provides a comprehensive overview of the Story Weaver App's backend API endpoints.

## Authentication Endpoints

These endpoints handle user authentication and account management.

### `POST /auth/register`

Registers a new user.

**Request Body:**

```json
{
  "username": "your_username",
  "email": "your_email@example.com",
  "password": "your_password"
}
```

**Responses:**

*   **200 OK:**
    ```json
    {
      "message": "New user created!"
    }
    ```
*   **400 Bad Request:** If required fields are missing or invalid.

---

### `POST /auth/login`

Logs in a user and returns a JWT token.

**Request Headers:**

*   `Authorization`: Basic authentication with username and password.

**Responses:**

*   **200 OK:**
    ```json
    {
      "token": "your_jwt_token"
    }
    ```
*   **401 Unauthorized:** If authentication fails.

---

### `POST /auth/setup-test-account`

Creates or updates a test account for E2E tests.

**Request Body:**

(No request body required)

**Responses:**

*   **201 Created:** If a new test account is created.
    ```json
    {
      "status": "created",
      "username": "testuser"
    }
    ```
*   **200 OK:** If an existing test account is updated.
    ```json
    {
      "status": "updated",
      "username": "testuser"
    }
    ```

---

## Character Endpoints

These endpoints handle character creation, retrieval, updating, and deletion.

### `POST /character/create-character`

Creates a new character.

**Request Body:**

```json
{
  "name": "Character Name",
  "age": 10,
  "gender": "Female",
  "role": "Princess",
  "magic_type": "Fire",
  "challenge": "Overcoming fear of the dark",
  "traits": ["Brave", "Curious"],
  "likes": ["Reading", "Exploring"],
  "dislikes": ["Spiders", "Loud noises"],
  "fears": ["The dark"],
  "comfort_item": "A teddy bear"
}
```

**Responses:**

*   **201 Created:** Returns the created character object.
*   **400 Bad Request:** If required fields are missing or invalid.

---

### `PATCH/PUT /character/characters/<string:char_id>`

Updates a character.

**URL Parameters:**

*   `char_id`: The ID of the character to update.

**Request Body:**

(Partial or full character object with fields to update)

**Responses:**

*   **200 OK:** Returns the updated character object.
*   **404 Not Found:** If the character is not found.
*   **400 Bad Request:** If the request body is invalid.

---

### `DELETE /character/characters/<string:char_id>`

Deletes a character.

**URL Parameters:**

*   `char_id`: The ID of the character to delete.

**Responses:**

*   **200 OK:**
    ```json
    {
      "status": "deleted",
      "id": "char_id"
    }
    ```
*   **404 Not Found:** If the character is not found.

---

### `GET /character/get-characters`

Retrieves all characters.

**Responses:**

*   **200 OK:** Returns a list of character objects.

---

### `GET /character/characters/<string:char_id>`

Retrieves a single character.

**URL Parameters:**

*   `char_id`: The ID of the character to retrieve.

**Responses:**

*   **200 OK:** Returns the character object.
*   **404 Not Found:** If the character is not found.

---

## Progression Endpoints

These endpoints handle user progression data.

### `POST /progression/sync-progression`

Syncs user progression data.

**Authentication:** Requires a valid JWT token in the `x-access-token` header.

**Request Body:**

```json
{
  "achievements": ["first_story", "five_stories"],
  "unlocked_themes": ["Space", "Dragons"]
}
```

**Responses:**

*   **200 OK:**
    ```json
    {
      "message": "Synced"
    }
    ```
*   **401 Unauthorized:** If the token is missing or invalid.

---

### `GET /progression/get-progression`

Retrieves user progression data.

**Authentication:** Requires a valid JWT token in the `x-access-token` header.

**Responses:**

*   **200 OK:** Returns the user's progression data.
    ```json
    {
      "achievements": ["first_story", "five_stories"],
      "unlocked_themes": ["Space", "Dragons"]
    }
    ```
*   **401 Unauthorized:** If the token is missing or invalid.

---

## Story Endpoints

These endpoints handle story generation and related functionalities.

### `GET /story/get-story-themes`

Retrieves a list of available story themes.

**Responses:**

*   **200 OK:**
    ```json
    [
      "Adventure",
      "Friendship",
      "Magic",
      "Dragons",
      "Castles",
      "Unicorns",
      "Space",
      "Ocean"
    ]
    ```

---

### `POST /story/generate-story`

Generates a regular story.

**Request Body:**

```json
{
  "character": "Character Name",
  "theme": "Adventure",
  "companion": "A friendly dragon",
  "learning_to_read_mode": false,
  "character_age": 10,
  "current_feeling": {
    "emotion": "Happy",
    "intensity": 8,
    "what_happened": "I won a game."
  }
}
```

**Responses:**

*   **200 OK:**
    ```json
    {
      "title": "The Dragon's Gift",
      "story_text": "Once upon a time...",
      "wisdom_gem": "True friendship is a treasure."
    }
    ```
*   **200 OK (Fallback):** If the model fails, a fallback story is returned.

---

### `POST /story/generate-multi-character-story`

Generates a story with multiple characters.

**Request Body:**

```json
{
  "character_ids": ["char_id_1", "char_id_2"],
  "main_character_id": "char_id_1",
  "theme": "Friendship",
  "learning_to_read_mode": false,
  "current_feeling": {
    "emotion": "Excited",
    "intensity": 9,
    "what_happened": "We're going on an adventure!"
  }
}
```

**Responses:**

*   **200 OK:**
    ```json
    {
      "story": "The two friends went on an adventure..."
    }
    ```
*   **400 Bad Request:** If required fields are missing or invalid.
*   **404 Not Found:** If the main character is not found.

---

### `POST /story/generate-interactive-story`

Generates the first segment of an interactive story.

**Request Body:**

```json
{
  "character": "Hero",
  "theme": "Adventure",
  "companion": "A wise owl",
  "friends": ["Friend1", "Friend2"],
  "therapeutic_prompt": "Learning to be brave"
}
```

**Responses:**

*   **200 OK:**
    ```json
    {
      "text": "The story begins...",
      "choices": [
        {"text": "Go left"},
        {"text": "Go right"},
        {"text": "Ask the owl for advice"}
      ],
      "is_ending": false
    }
    ```

---

### `POST /story/continue-interactive-story`

Continues an interactive story based on the user's choice.

**Request Body:**

```json
{
  "character": "Hero",
  "theme": "Adventure",
  "companion": "A wise owl",
  "friends": ["Friend1", "Friend2"],
  "choice": "Go left",
  "story_so_far": "The story so far...",
  "choices_made": ["Go left"],
  "therapeutic_prompt": "Learning to be brave"
}
```

**Responses:**

*   **200 OK (Not Ending):**
    ```json
    {
      "text": "The story continues...",
      "choices": [
        {"text": "Open the chest"},
        {"text": "Ignore the chest"},
        {"text": "Look for traps"}
      ],
      "is_ending": false
    }
    ```
*   **200 OK (Ending):**
    ```json
    {
      "text": "The story concludes...",
      "choices": [],
      "is_ending": true
    }
    ```

---