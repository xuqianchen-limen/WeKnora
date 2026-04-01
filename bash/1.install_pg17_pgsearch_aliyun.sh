#!/usr/bin/env bash
set -euo pipefail

# Install PostgreSQL 17 + pgvector + pg_search for WeKnora using Aliyun PGDG mirror.
# Supported: Ubuntu 22.04/24.04, Debian 12/13; amd64/arm64.
# Run as root: sudo bash bash/install_pg17_pgsearch_aliyun.sh

PG_MAJOR="${PG_MAJOR:-18}"
PG_SEARCH_VERSION="${PG_SEARCH_VERSION:-0.21.14}"
DB_NAME="${DB_NAME:-WeKnora}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres123!@#}"
REPLACE_5432="${REPLACE_5432:-1}"   # 1 = stop old cluster on 5432 and switch PG17 to 5432

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
err()  { echo "[ERROR] $*" >&2; }

if [[ "${EUID}" -ne 0 ]]; then
  err "Please run as root: sudo bash $0"
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  err "/etc/os-release not found"
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
OS_ID="${ID:-}"
CODENAME="${VERSION_CODENAME:-}"
ARCH_RAW="$(uname -m)"

case "$ARCH_RAW" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) err "Unsupported architecture: $ARCH_RAW"; exit 1 ;;
esac

case "${OS_ID}:${CODENAME}" in
  ubuntu:jammy|ubuntu:noble|debian:bookworm|debian:trixie)
    ;;
  *)
    err "Unsupported distro: ${OS_ID} ${CODENAME}. This script supports Ubuntu 22.04/24.04 and Debian 12/13."
    exit 1
    ;;
esac

export DEBIAN_FRONTEND=noninteractive

info "Installing base packages"
apt-get update
apt-get install -y curl ca-certificates gnupg lsb-release wget apt-transport-https software-properties-common

info "Configuring PostgreSQL APT Aliyun mirror"
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://mirrors.aliyun.com/postgresql/repos/apt/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/keyrings/postgresql.gpg
cat > /etc/apt/sources.list.d/pgdg-aliyun.list <<EOF
# PostgreSQL PGDG mirror via Aliyun
deb [signed-by=/etc/apt/keyrings/postgresql.gpg] https://mirrors.aliyun.com/postgresql/repos/apt ${CODENAME}-pgdg main
EOF

info "Installing PostgreSQL ${PG_MAJOR} + pgvector"
apt-get update
apt-get install -y \
  "postgresql-${PG_MAJOR}" \
  "postgresql-client-${PG_MAJOR}" \
  postgresql-contrib \
  "postgresql-server-dev-${PG_MAJOR}" \
  "postgresql-${PG_MAJOR}-pgvector"

info "Downloading and installing pg_search ${PG_SEARCH_VERSION}"
PG_SEARCH_DEB="/tmp/postgresql-${PG_MAJOR}-pg-search_${PG_SEARCH_VERSION}-1PARADEDB-${CODENAME}_${ARCH}.deb"
# 添加了加速前缀
PG_SEARCH_URL="https://gh.llkk.cc/https://github.com/paradedb/paradedb/releases/download/v${PG_SEARCH_VERSION}/postgresql-${PG_MAJOR}-pg-search_${PG_SEARCH_VERSION}-1PARADEDB-${CODENAME}_${ARCH}.deb"
if [[ ! -f "$PG_SEARCH_DEB" ]]; then
  info "Download URL: $PG_SEARCH_URL"
  curl -fL "$PG_SEARCH_URL" -o "$PG_SEARCH_DEB"
else
  info "Using cached package: $PG_SEARCH_DEB"
fi
apt-get install -y "$PG_SEARCH_DEB"

info "Current PostgreSQL clusters"
pg_lsclusters || true

PG17_PORT="$(pg_lsclusters | awk '$1 == "'"${PG_MAJOR}"'" {print $3; exit}')"
if [[ -z "${PG17_PORT:-}" ]]; then
  err "PostgreSQL ${PG_MAJOR} cluster not found"
  exit 1
fi

if [[ "$REPLACE_5432" == "1" && "$PG17_PORT" != "5432" ]]; then
  info "Switching PostgreSQL ${PG_MAJOR} to port 5432"
  OLD_ON_5432="$(pg_lsclusters | awk '$3 == "5432" {print $1" "$2}')"
  if [[ -n "$OLD_ON_5432" ]]; then
    OLD_VER="$(echo "$OLD_ON_5432" | awk '{print $1}')"
    OLD_NAME="$(echo "$OLD_ON_5432" | awk '{print $2}')"
    warn "Stopping old cluster on 5432: ${OLD_VER}/${OLD_NAME}"
    pg_ctlcluster "$OLD_VER" "$OLD_NAME" stop || true
  fi

  PG17_CONF="/etc/postgresql/${PG_MAJOR}/main/postgresql.conf"
  if [[ ! -f "$PG17_CONF" ]]; then
    err "Config not found: $PG17_CONF"
    exit 1
  fi
  sed -ri 's/^[#[:space:]]*port[[:space:]]*=.*/port = 5432/' "$PG17_CONF"
  pg_ctlcluster "${PG_MAJOR}" main restart
  PG17_PORT="5432"
fi

info "Ensuring PostgreSQL ${PG_MAJOR} is running"
pg_ctlcluster "${PG_MAJOR}" main start || true

info "Setting password for ${DB_USER}"
su - postgres -c "psql -p ${PG17_PORT} -c \"ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';\""

info "Creating database ${DB_NAME} if missing"
su - postgres -c "psql -p ${PG17_PORT} -tc \"SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'\" | grep -q 1 || createdb -p ${PG17_PORT} ${DB_NAME}"

info "Enabling required extensions in ${DB_NAME}"
su - postgres -c "psql -p ${PG17_PORT} -d ${DB_NAME} -c 'CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";'"
su - postgres -c "psql -p ${PG17_PORT} -d ${DB_NAME} -c 'CREATE EXTENSION IF NOT EXISTS pg_trgm;'"
su - postgres -c "psql -p ${PG17_PORT} -d ${DB_NAME} -c 'CREATE EXTENSION IF NOT EXISTS vector;'"
su - postgres -c "psql -p ${PG17_PORT} -d ${DB_NAME} -c 'CREATE EXTENSION IF NOT EXISTS pg_search;'"

cat <<EOF

================ Installation Complete ================
PostgreSQL version : ${PG_MAJOR}
Database port      : ${PG17_PORT}
Database name      : ${DB_NAME}
Database user      : ${DB_USER}
Database password  : ${DB_PASSWORD}

Recommended .env values:
DB_DRIVER=postgres
RETRIEVE_DRIVER=postgres
DB_HOST=127.0.0.1
DB_PORT=${PG17_PORT}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=${DB_NAME}

Next steps:
1) Update /root/WeKnora/.env with the values above
2) Restart app: systemctl restart weknora-app
3) Check logs:   journalctl -u weknora-app -n 200 --no-pager
4) Check ext:    su - postgres -c 'psql -p ${PG17_PORT} -d ${DB_NAME} -c "\\dx"'
=======================================================
EOF
