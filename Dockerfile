# Build stage
FROM node:22-alpine AS builder

WORKDIR /app

# Install uv for fast python package management
RUN npm install -g uv

# Copy package files
COPY pyproject.toml uv.lock ./
COPY frontend ./frontend
COPY backend ./backend
COPY assets ./assets
COPY set_state.py ./
COPY *.json *.md ./

# Install python deps with uv (faster)
RUN uv sync --frozen --no-dev

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

# Copy build artifacts
COPY --from=builder /app/frontend/dist /app/static
COPY frontend/index.html /app/templates/
COPY backend/app.py /app/backend/
COPY backend/security_utils.py /app/backend/
COPY backend/memo_utils.py /app/backend/
COPY backend/store_utils.py /app/backend/
COPY set_state.py /app/
COPY *.json /app/
COPY assets /app/assets
COPY runtime-config.sample.json /app/runtime-config.json

# Create state file
RUN echo '{"state":"idle","detail":"待命中","progress":0}' > /app/state.json

# Create .env file template
RUN echo '# Production config\nSTAR_OFFICE_ENV=production\nFLASK_SECRET_KEY=replace_with_random_secret\nASSET_DRAWER_PASS=replace_with_strong_password' > /app/.env.example

# Expose port
EXPOSE 19000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:19000/status || exit 1

# Start backend + nginx
CMD sh -c "python3 /app/backend/app.py & nginx -g 'daemon off;'"