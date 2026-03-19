#!/bin/bash
# 1. 加速 Apt 并安装依赖
sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources
apt-get update
apt-get install -y libsqlite3-dev g++

# 2. 加速 Go 并安装 Air
export GOPROXY=https://goproxy.cn,direct
go install github.com/air-verse/air@v1.52.3

# 3. 创建链接器包装器（修复 DuckDB 参数错误）
cat <<EOF > /usr/local/bin/ld-wrapper
#!/bin/bash
args=()
for arg in "\$@"; do
    [[ "\$arg" != "-no_warn_duplicate_libraries" ]] && args+=("\$arg")
done
/usr/bin/ld.bfd "\${args[@]}"
EOF

chmod +x /usr/local/bin/ld-wrapper
ln -sf /usr/local/bin/ld-wrapper /usr/bin/ld

# 4. 启动热重载
air -c .air.toml