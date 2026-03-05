# Story Weaver App - Backend Setup

**Last Updated:** 2025-11-15

This document provides instructions for setting up and running the Story Weaver App's backend.

## Prerequisites

*   Python 3.10+
*   pip
*   virtualenv

## Setup

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/darcy0408/story-weaver-app.git
    cd story-weaver-app
    ```

2.  **Create and activate a virtual environment:**

    ```bash
    python3 -m venv backend/.venv
    source backend/.venv/bin/activate
    ```

3.  **Install dependencies:**

    ```bash
    pip install -r backend/requirements.txt
    ```

4.  **Set up environment variables:**

    Create a `.env` file in the `backend` directory and add the following:

    ```
    GEMINI_API_KEY="YOUR_GEMINI_API_KEY"
    SECRET_KEY="YOUR_SECRET_KEY"
    ```

5.  **Initialize the database:**

    ```bash
    export FLASK_APP=backend.app:create_app('development')
    flask db init
    flask db migrate -m "Initial migration."
    flask db upgrade
    ```

## Running the Application

To run the application in development mode, use the following command:

```bash
export FLASK_APP=backend.app:create_app('development')
flask run
```

The application will be available at `http://127.0.0.1:5000`.

## API Documentation

The API documentation is available at `http://127.0.0.1:5000/api/docs`. This documentation is generated using Swagger UI and provides a comprehensive overview of all available endpoints.
