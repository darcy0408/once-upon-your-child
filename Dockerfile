# ---- Stage 1: builder ----
# Compiles wheels with the full build toolchain. Nothing from this stage's
# apt packages (gcc, *-dev headers) ends up in the runtime image.
FROM python:3.11-slim-bookworm AS builder

WORKDIR /app

# Build-time system deps required to compile psycopg2 and Pillow wheels
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libpq-dev libjpeg62-turbo-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy backend requirements separately to leverage Docker caching
COPY backend/requirements.txt ./backend/requirements.txt

# Build all dependencies into wheels so the runtime stage installs without a compiler
RUN pip install --upgrade pip \
    && pip wheel --no-cache-dir --wheel-dir /wheels -r ./backend/requirements.txt

# ---- Stage 2: runtime ----
# Clean image with NO compiler / build toolchain. Only the runtime shared
# libraries needed by the compiled wheels are installed.
FROM python:3.11-slim-bookworm AS runtime

WORKDIR /app

# Runtime-only shared libraries (no -dev headers, no gcc)
RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq5 libjpeg62-turbo zlib1g \
    && rm -rf /var/lib/apt/lists/*

# Install the prebuilt wheels from the builder stage (no compilation here)
COPY --from=builder /wheels /wheels
COPY backend/requirements.txt ./backend/requirements.txt
RUN pip install --upgrade pip \
    && pip install --no-cache-dir --no-index --find-links=/wheels -r ./backend/requirements.txt \
    && pip show psycopg2-binary >/dev/null \
    && rm -rf /wheels

# Create a non-root user/group to run the application (CWE-250)
RUN groupadd --system app && useradd --system --gid app --create-home --home-dir /home/app app

# Copy the rest of the application code, owned by the non-root user
COPY --chown=app:app . .

# The app writes backend_errors.log into /app, so the app user must own the
# WORKDIR itself. `COPY --chown` only sets ownership of the copied files, not
# of the /app directory created by WORKDIR — chown it explicitly.
RUN chown app:app /app

# Drop privileges before running the app (CWE-250).
USER app

# Expose the port the app runs on (Railway will set $PORT dynamically)
EXPOSE 8080

# Define the command to run the application.
# Railway's startCommand in railway.toml is the canonical boot path and
# overrides this CMD; the two are kept identical so local `docker run` behaves
# the same. nixpacks.toml was removed (L-9) — the Docker build is authoritative.
CMD gunicorn wsgi:app --bind 0.0.0.0:${PORT:-8080} --timeout 120 --workers 2
