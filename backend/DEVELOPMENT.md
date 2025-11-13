# Local Development Setup Guide for Story Weaver Backend

This guide provides instructions for setting up and running the Python Flask backend of the Story Weaver application in a local development environment.

## Prerequisites

Before you begin, ensure you have the following installed:

*   **Python 3.9+**: Download from [python.org](https://www.python.org/downloads/).
*   **pip**: Python's package installer (usually comes with Python).
*   **git**: For cloning the repository.

## 1. Clone the Repository

If you haven't already, clone the Story Weaver repository:

```bash
git clone https://github.com/darcy0408/story-weaver-app.git
cd story-weaver-app/backend
```

## 2. Set up a Virtual Environment

It's highly recommended to use a virtual environment to manage project dependencies.

```bash
python3 -m venv .venv
source .venv/bin/activate  # On Windows, use: .venv\Scripts\activate
```

## 3. Install Dependencies

Install the required Python packages using pip:

```bash
pip install -r requirements.txt
```

## 4. Environment Variables

The backend requires a Google Gemini API key to function correctly.

1.  Create a file named `.env` in the `backend/` directory.
2.  Add your Gemini API key to this file:

    ```
    GEMINI_API_KEY="YOUR_GEMINI_API_KEY"
    ```
    (Replace `"YOUR_GEMINI_API_KEY"` with your actual key obtained from [Google AI Studio](https://aistudio.google.com/app/apikey)).

3.  Optionally, you can specify the Gemini model to use:

    ```
    GEMINI_MODEL="gemini-1.5-flash"
    ```
    (Defaults to `gemini-2.5-flash` if not specified).

4.  If you plan to use OpenRouter for image generation (an alternative to Gemini Imagen), also add your OpenRouter API key:

    ```
    OPENROUTER_API_KEY="YOUR_OPENROUTER_API_KEY"
    ```

## 5. Run the Flask Application

You can run the Flask application in development mode. This will automatically reload the server on code changes.

```bash
python app.py
```

The server will typically run on `http://127.0.0.1:5000`.

## 6. Running Tests

To run the backend tests, ensure your virtual environment is active and execute pytest from the `backend/` directory:

```bash
pytest
```

To run specific tests, you can specify the file or a specific test function:

```bash
pytest tests/test_app.py
pytest tests/test_app.py::test_generate_story
```

## 7. Accessing API Documentation (Swagger UI)

If Flasgger is correctly configured (which it should be if you followed the setup), you can access the interactive API documentation:

1.  Ensure the Flask application is running (`python app.py`).
2.  Open your web browser and navigate to `http://127.0.0.1:5000/apidocs`.

This will display the Swagger UI, allowing you to explore and test the API endpoints.

## 8. Database

The application uses SQLite for local development, with the database file `characters.db` created in the `backend/` directory. You generally don't need to interact with it directly, but tools like DB Browser for SQLite can be used to inspect its contents.

For production, a PostgreSQL database is used if `DATABASE_URL` environment variable is set.
