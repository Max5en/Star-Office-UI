# Build stage
FROM node:22-alpine AS builder

WORKDIR /app

# Copy package files
COPY pyproject.toml ./
COPY frontend ./frontend

# Build frontend
WORKDIR /app/frontend
RUN npm install && npm run build

# Final stage
FROM python:3.11-slim

WORKDIR /app

# Install runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy backend files
COPY backend/app.py /app/backend/
COPY backend/security_utils.py /app/backend/
COPY backend/memo_utils.py /app/backend/
COPY backend/store_utils.py /app/backend/

# Copy other files
COPY set_state.py /app/
COPY runtime-config.sample.json /app/runtime-config.json
COPY assets /app/assets

# Install Python deps
RUN pip install --no-cache-dir flask flask-cors

# Create state file (runtime)
RUN echo '{"state":"idle","detail":"待命中","progress":0}' > /app/state.json

# Create agents state file
RUN echo '{}' > /app/agents-state.json

# Create join-keys file
RUN echo '{}' > /app/join-keys.json

# Expose port
EXPOSE 19000

# Start backend + nginx
CMD sh -c "python3 /app/backend/app.py & nginx -g 'daemon off;'"