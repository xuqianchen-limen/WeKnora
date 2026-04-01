#!/bin/bash

# --- 颜色定义 ---
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}开始一键配置 WeKnora 运行环境...${NC}"

# 1. 更新系统并安装基础工具
apt-get update
apt-get install -y golang-go nodejs npm redis-server postgresql postgresql-contrib sudo

# 2. Python 虚拟环境配置
echo -e "${GREEN}正在创建 Python 虚拟环境...${NC}"
# 安装 venv 模块（Ubuntu 系统通常需要手动安装此包）
apt-get install -y python3-venv 

# 创建名为 venv_weknora 的虚拟环境
python3 -m venv venv_weknora

# 激活虚拟环境并在其中安装依赖
source venv_weknora/bin/activate
echo -e "${GREEN}虚拟环境已激活: $(which python)${NC}"

if [ -f "requirements.txt" ]; then
    pip install --upgrade pip
    pip install -r requirements.txt
else
    echo "未找到 requirements.txt，跳过 Python 依赖安装。"
fi

# 3. Go 依赖下载
echo -e "${GREEN}正在下载 Go 项目依赖...${NC}"
export GOPROXY=https://goproxy.cn,direct  # 设置国内加速
go mod download

# 4. 前端依赖安装
if [ -d "frontend" ]; then
    echo -e "${GREEN}正在安装前端依赖 (这可能需要较长时间)...${NC}"
    cd frontend
    npm install
    cd ..
fi

# 5. 启动服务与数据库初始化
echo -e "${GREEN}正在启动 Redis 和 Postgres...${NC}"
service redis-server start
service postgresql start

# 初始化数据库（如果不存在）
sudo -u postgres psql -c "CREATE DATABASE \"WeKnora\";" || echo "数据库已存在"
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres123!@#';"

# 6. 生成 .env 文件（如果不存在）
if [ ! -f ".env" ]; then
    cp .env.example .env
    # 修正 .env 中的主机地址，将 docker 服务名改为本地回环地址
    sed -i 's/DB_HOST=db/DB_HOST=127.0.0.1/g' .env
    sed -i 's/REDIS_HOST=redis/REDIS_HOST=127.0.0.1/g' .env
    echo -e "${GREEN}.env 文件已生成并修正 IP 指向。${NC}"
fi

echo -e "${GREEN}--------------------------------------${NC}"
echo -e "${GREEN}✅ 所有环境已就绪！${NC}"
echo -e "1. Python 虚拟环境路径: ~/WeKnora/venv_weknora"
echo -e "2. 激活虚拟环境请执行: ${NC}source venv_weknora/bin/activate"
echo -e "${GREEN}3. 启动后端命令: ${NC}go run main.go"
echo -e "${GREEN}4. 启动前端命令: ${NC}cd frontend && npm run dev"
echo -e "${GREEN}--------------------------------------${NC}"


# 赋权并运行
