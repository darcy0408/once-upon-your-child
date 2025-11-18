# Story Weaver App - Database Documentation

**Last Updated:** 2025-11-15

This document provides a comprehensive overview of the Story Weaver App's database schemas and models.

## User Model

The `User` model represents a user of the application.

**File:** `backend/models/user.py`

**Schema:**

| Column          | Type         | Constraints              | Description                                      |
|-----------------|--------------|--------------------------|--------------------------------------------------|
| `id`            | `String(36)` | Primary Key, UUID        | Unique identifier for the user.                  |
| `username`      | `String(80)` | Unique, Not Nullable     | The user's username.                             |
| `email`         | `String(120)`| Unique, Not Nullable     | The user's email address.                        |
| `password_hash` | `String(200)`| Not Nullable             | The user's hashed password.                      |
| `created_at`    | `DateTime`   | Default: `utcnow`        | The timestamp when the user was created.         |
| `progression_data` | `JSON`    | Default: `{}`            | JSON blob to store user progression data.        |

**Relationships:**

*   **`characters`**: A one-to-many relationship with the `Character` model.

---

## Character Model

The `Character` model represents a character created by a user.

**File:** `backend/models/character.py`

**Schema:**

| Column               | Type          | Constraints              | Description                                      |
|----------------------|---------------|--------------------------|--------------------------------------------------|
| `user_id`            | `String(36)`  | Foreign Key (`user.id`)  | The ID of the user who created the character.    |
| `id`                 | `String(36)`  | Primary Key, UUID        | Unique identifier for the character.             |
| `name`               | `String(100)` | Not Nullable             | The character's name.                            |
| `age`                | `Integer`     | Not Nullable             | The character's age.                             |
| `gender`             | `String(50)`  | Nullable                 | The character's gender.                          |
| `role`               | `String(50)`  | Nullable                 | The character's role in the story.               |
| `magic_type`         | `String(50)`  | Nullable                 | The character's magic type.                      |
| `challenge`          | `Text`        | Nullable                 | The character's current challenge.               |
| `personality_traits` | `JSON`        | Default: `[]`            | A list of the character's personality traits.    |
| `siblings`           | `JSON`        | Default: `[]`            | A list of the character's siblings.              |
| `friends`            | `JSON`        | Default: `[]`            | A list of the character's friends.               |
| `likes`              | `JSON`        | Default: `[]`            | A list of things the character likes.            |
| `dislikes`           | `JSON`        | Default: `[]`            | A list of things the character dislikes.         |
| `fears`              | `JSON`        | Default: `[]`            | A list of the character's fears.                 |
| `comfort_item`       | `String(200)` | Nullable                 | The character's comfort item.                    |
| `created_at`         | `DateTime`    | Default: `now`, Indexed  | The timestamp when the character was created.    |

---
