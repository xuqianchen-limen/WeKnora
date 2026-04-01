cat <<EOF > /etc/nginx/sites-enabled/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    root /root/WeKnora/frontend/dist;
    index index.html;

    # 1. 静态文件
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # 2. API 转发（修正版：去掉末尾斜杠，保持路径完整）
    location /api/ {
        proxy_pass http://127.0.0.1:8080; 
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
    }

    # 3. 针对你刚才报错的 /v1 路径做专门转发
    location /v1/ {
        proxy_pass http://127.0.0.1:8080/api/v1/;
        proxy_set_header Host \$host;
    }
}
EOF