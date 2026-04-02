# 阶段1: 构建前端
FROM node:18-alpine AS builder

WORKDIR /app

# 安装 git
RUN apk add --no-cache git

# 克隆仓库
RUN git clone https://github.com/Max5en/Star-Office-UI.git . --depth 1

WORKDIR /app/frontend

RUN npm install && npm run build

# 阶段2: Python + Nginx 运行
FROM python:3.11-slim

WORKDIR /app

# 安装 nginx 和 curl
RUN apt-get update && apt-get install -y nginx curl && rm -rf /var/lib/apt/lists/*

# 安装 Python 依赖
RUN pip install --no-cache-dir flask flask-cors

# 复制后端文件
COPY --from=builder /app/backend/app.py /app/backend/
COPY --from=builder /app/backend/*.py /app/backend/
COPY --from=builder /app/set_state.py /app/
COPY --from=builder /app/state.json /app/
COPY --from=builder /app/runtime-config.sample.json /app/runtime-config.json
COPY --from=builder /app/assets /app/assets
COPY --from=builder /app/frontend/dist /app/static/

# 初始化状态文件
RUN echo '{"state":"idle","detail":"待命中","progress":0}' > /app/state.json && \
    echo '{}' > /app/agents-state.json && \
    echo '{}' > /app/join-keys.json

# 创建 .env 文件
RUN echo "ASSET_DRAWER_PASS=1234" > /app/.env

# Nginx 配置
RUN echo 'server { listen 80; server_name localhost; root /app/static; index index.html; \
    location / { try_files $uri $uri/ /index.html; } \
    location /api/ { proxy_pass http://127.0.0.1:19000; proxy_set_header Host $host; } \
    location /set_state { proxy_pass http://127.0.0.1:19000; } \
    location /status { proxy_pass http://127.0.0.1:19000; } \
    location /agents { proxy_pass http://127.0.0.1:19000; } \
}' > /etc/nginx/conf.d/star.conf

EXPOSE 19000 80

# 启动 Flask 后端 + Nginx
CMD sh -c "python3 /app/backend/app.py & nginx -g 'daemon off;'"