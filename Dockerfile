# Use an official Python runtime as a parent image
FROM python:3.11-slim-buster

# Set the working directory in the container
WORKDIR /app

# Install any needed packages specified in requirements.txt
# Copy backend requirements separately to leverage Docker caching
COPY backend/requirements.txt ./backend/requirements.txt
RUN pip install --no-cache-dir -r ./backend/requirements.txt

# Copy the rest of the application code
COPY . .

# Expose the port the app runs on
EXPOSE 8080

# Define the command to run the application
# Use gunicorn wsgi:app as the entry point
CMD ["gunicorn", "wsgi:app", "--bind", "0.0.0.0:8080", "--timeout", "120", "--workers", "2"]
