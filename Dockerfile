FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y nginx curl && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir flask flask-cors

# Backend
COPY backend /app/backend/
COPY set_state.py /app/
COPY runtime-config.sample.json /app/runtime-config.json

# Frontend - 全部复制到一个地方
COPY frontend /app/frontend

# Assets
COPY assets /app/assets

# State files
RUN echo '{"state":"idle","detail":"待命中","progress":0}' > /app/state.json && \
    echo '{}' > /app/agents-state.json && \
    echo '{}' > /app/join-keys.json && \
    echo "ASSET_DRAWER_PASS=1234" > /app/.env

# Nginx - root 指向前端目录
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    root /app/frontend; \
    index index.html; \
    location / { try_files $uri $uri/ /index.html; } \
    location /set_state { proxy_pass http://127.0.0.1:19000; } \
    location /status { proxy_pass http://127.0.0.1:19000; } \
    location /agents { proxy_pass http://127.0.0.1:19000; } \
}' > /etc/nginx/conf.d/star.conf

EXPOSE 19000 80

CMD sh -c "python3 /app/backend/app.py & nginx -g 'daemon off;'"