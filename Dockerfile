FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y nginx curl && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir flask flask-cors

COPY backend/app.py /app/backend/
COPY backend/security_utils.py /app/backend/
COPY backend/memo_utils.py /app/backend/
COPY backend/store_utils.py /app/backend/
COPY set_state.py /app/
COPY runtime-config.sample.json /app/runtime-config.json

# Frontend files need to go to /app/frontend (not /app/static)
RUN mkdir -p /app/frontend
COPY frontend/index.html /app/frontend/
COPY frontend/game.js /app/frontend/
COPY frontend/layout.js /app/frontend/

RUN mkdir -p /app/frontend/vendor /app/frontend/fonts
COPY frontend/vendor /app/frontend/vendor
COPY frontend/fonts /app/frontend/fonts

COPY frontend/*.webp /app/frontend/
COPY frontend/*.png /app/frontend/

RUN mkdir -p /app/assets
COPY assets /app/assets

RUN echo '{"state":"idle","detail":"待命中","progress":0}' > /app/state.json
RUN echo '{}' > /app/agents-state.json
RUN echo '{}' > /app/join-keys.json
RUN echo "ASSET_DRAWER_PASS=1234" > /app/.env

RUN echo 'server { listen 80; server_name localhost; root /app/frontend; index index.html; location / { try_files $uri $uri/ /index.html; } location /set_state { proxy_pass http://127.0.0.1:19000; } location /status { proxy_pass http://127.0.0.1:19000; } location /agents { proxy_pass http://127.0.0.1:19000; } }' > /etc/nginx/conf.d/star.conf

EXPOSE 19000 80

CMD sh -c "python3 /app/backend/app.py & nginx -g 'daemon off;'"