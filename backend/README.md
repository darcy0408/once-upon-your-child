# Story Weaver Backend

This directory contains the Python Flask backend for the Story Weaver application. The backend is responsible for:

*   Managing character profiles (CRUD operations).
*   Generating AI-powered stories using the Gemini API.
*   Generating interactive choose-your-own-adventure stories.
*   Extracting story scenes for illustration.
*   Generating illustrations and coloring pages using Gemini Imagen or OpenRouter.
*   Providing Text-to-Speech functionality via Google Cloud TTS.

## Technologies Used

*   **Python Flask**: Web framework.
*   **SQLAlchemy**: ORM for database interactions (SQLite for development, PostgreSQL for production).
*   **Google Generative AI (Gemini API)**: For story and image generation.
*   **OpenRouter API**: Alternative for image generation (Stable Diffusion).
*   **Google Cloud Text-to-Speech**: For audio narration.
*   **Flasgger**: For OpenAPI/Swagger API documentation.

## Setup and Local Development

Please refer to [DEVELOPMENT.md](DEVELOPMENT.md) for detailed instructions on setting up your local development environment, installing dependencies, and running the application.

## Environment Variables

The following environment variables are used by the backend. They should be set in a `.env` file in this directory for local development, or configured in your deployment environment.

*   `GEMINI_API_KEY`: **Required** Your Google Gemini API key. Obtain it from [Google AI Studio](https://aistudio.google.com/app/apikey).
*   `GEMINI_MODEL`: (Optional) The specific Gemini model to use for story generation (e.g., `gemini-1.5-flash`). Defaults to `gemini-2.5-flash`.
*   `OPENROUTER_API_KEY`: (Optional) Your OpenRouter API key, if you wish to use OpenRouter for image generation. Obtain it from [OpenRouter](https://openrouter.ai/keys).
*   `DATABASE_URL`: (Optional) A PostgreSQL connection string for production deployments (e.g., `postgresql://user:password@host:port/database`). If not set, SQLite (`characters.db`) will be used for local development.
*   `PORT`: (Optional) The port on which the Flask application will run. Defaults to `5000`.

## API Documentation

Interactive API documentation (Swagger UI) is available when the Flask application is running. Navigate to `http://127.0.0.1:5000/apidocs` in your browser.
