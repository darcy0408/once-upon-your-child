# Use an official Python runtime as a parent image
FROM python:3.11-slim-bookworm

# Set the working directory in the container
WORKDIR /app

# System deps required for psycopg2 and Pillow wheels; keep image lean
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libpq-dev libjpeg62-turbo-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install any needed packages specified in requirements.txt
# Copy backend requirements separately to leverage Docker caching
COPY backend/requirements.txt ./backend/requirements.txt
RUN pip install --upgrade pip \
    && pip install --no-cache-dir -r ./backend/requirements.txt \
    && pip show psycopg2-binary >/dev/null

# Copy the rest of the application code
COPY . .

# Expose the port the app runs on (Railway will set $PORT dynamically)
EXPOSE 8080

# Define the command to run the application
# Use gunicorn wsgi:app as the entry point
# Note: Railway's startCommand in railway.toml will override this CMD
# This is here as a fallback for local development
CMD gunicorn wsgi:app --bind 0.0.0.0:${PORT:-8080} --timeout 120 --workers 2
