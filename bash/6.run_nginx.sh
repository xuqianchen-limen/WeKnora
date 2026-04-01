#!/bin/bash

# 定义配置文件路径
CONF_PATH="/etc/nginx/conf.d/weknora.conf"

echo "正在生成 Nginx 配置文件: $CONF_PATH ..."

# 使用 cat 重定向写入配置
# 使用 sudo 确保有权限写入系统目录
sudo cat << 'EOF' > $CONF_PATH
server {
    listen 80;
    server_name _;

    # 前端静态资源目录
    root /root/WeKnora/frontend/dist;
    index index.html;

    # 后端 API 代理
    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 文件服务代理
    location /files {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 健康检查
    location = /health {
        proxy_pass http://127.0.0.1:8080/health;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
    }

    # 处理 Vue/React 等单页应用路由重定向
    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

echo "正在检查 Nginx 配置语法..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "配置语法正确，正在重启 Nginx..."
    sudo systemctl reload nginx
    echo "Nginx 已成功重新加载！"
else
    echo "Nginx 配置检测失败，请检查错误日志。"
    exit 1
fi