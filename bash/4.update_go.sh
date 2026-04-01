#!/usr/bin/env bash
set -euo pipefail

# 建议使用目前已发布的稳定版本，1.24.1 是目前的最新版
GO_VERSION="${GO_VERSION:-1.24.1}"
GO_FILE="go${GO_VERSION}.linux-amd64.tar.gz"

# 使用 golang.google.cn (Google中国官方镜像)，下载速度极快
GO_URL="https://golang.google.cn/dl/${GO_FILE}"

info() { echo -e "\033[32m[INFO]\033[0m $*"; }

info "正在下载 Go ${GO_VERSION} 来自 ${GO_URL}..."
cd /tmp
rm -f "${GO_FILE}"
# 使用 wget 下载，并增加重试机制
wget -c --tries=3 "${GO_URL}"

info "正在清理旧版本 Go..."
rm -rf /usr/local/go

info "正在解压并安装 Go 到 /usr/local/go..."
tar -C /usr/local -xzf "${GO_FILE}"

# 配置环境变量
info "配置环境变量与 GOPROXY 镜像..."

# 确保 /usr/local/go/bin 在 PATH 中
if ! grep -q '/usr/local/go/bin' /root/.bashrc 2>/dev/null; then
    echo 'export PATH=/usr/local/go/bin:$PATH' >> /root/.bashrc
fi

# 配置 Go Proxy 镜像 (使用七牛云加速 go mod download)
if ! grep -q 'GOPROXY' /root/.bashrc 2>/dev/null; then
    echo 'export GOPROXY=https://goproxy.cn,direct' >> /root/.bashrc
fi

# 在当前 Shell 中立即生效
export PATH=/usr/local/go/bin:$PATH
export GOPROXY=https://goproxy.cn,direct
hash -r

info "检查安装结果:"
which go
go version

info "检查镜像配置:"
go env GOPROXY

info "🎉 Go 环境配置完成！你可以开始编译了。"