#!/usr/bin/env bash
set -euo pipefail

SESSION_NAME="${WEKNORA_TMUX_SESSION:-weknora}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    printf "%b\n" "${BLUE}[INFO]${NC} $1"
}

log_success() {
    printf "%b\n" "${GREEN}[OK]${NC} $1"
}

log_warn() {
    printf "%b\n" "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    printf "%b\n" "${RED}[ERROR]${NC} $1" >&2
}

fail() {
    log_error "$1"
    exit 1
}

require_cmd() {
    local name="$1"
    if ! command -v "$name" >/dev/null 2>&1; then
        fail "Missing required command: $name"
    fi
}

session_exists() {
    tmux has-session -t "$SESSION_NAME" 2>/dev/null
}

quote_path() {
    printf '%q' "$1"
}

load_env() {
    cd "$PROJECT_ROOT"
    if [ ! -f .env ]; then
        fail "Missing .env in $PROJECT_ROOT. Create it before starting the server."
    fi

    set -a
    . ./.env
    set +a
}

apply_local_defaults() {
    export DB_HOST="${DB_HOST:-127.0.0.1}"
    export DB_PORT="${DB_PORT:-5432}"
    export REDIS_ADDR="${REDIS_ADDR:-127.0.0.1:6379}"
    export DOCREADER_ADDR="${DOCREADER_ADDR:-127.0.0.1:50051}"
    export DOCREADER_TRANSPORT="${DOCREADER_TRANSPORT:-grpc}"
    export LOCAL_STORAGE_BASE_DIR="${LOCAL_STORAGE_BASE_DIR:-$PROJECT_ROOT/data/files}"
    export WEKNORA_WEB_DIR="${WEKNORA_WEB_DIR:-./frontend/dist}"
    export WEKNORA_SANDBOX_MODE="${WEKNORA_SANDBOX_MODE:-disabled}"
    export GIN_MODE="${GIN_MODE:-release}"
}

ensure_directories() {
    local storage_dir

    storage_dir="$LOCAL_STORAGE_BASE_DIR"

    mkdir -p "$PROJECT_ROOT/bin" "$PROJECT_ROOT/logs" "$PROJECT_ROOT/tmp" "$storage_dir"
}

check_dependencies() {
    if command -v pg_isready >/dev/null 2>&1; then
        if pg_isready -h "${DB_HOST:-127.0.0.1}" -p "${DB_PORT:-5432}" >/dev/null 2>&1; then
            log_success "PostgreSQL is reachable"
        else
            log_warn "PostgreSQL is not reachable at ${DB_HOST:-127.0.0.1}:${DB_PORT:-5432}"
        fi
    fi

    if command -v redis-cli >/dev/null 2>&1 && [ -n "${REDIS_ADDR:-}" ]; then
        local redis_host redis_port
        redis_host="${REDIS_ADDR%%:*}"
        redis_port="${REDIS_ADDR##*:}"
        if [ -z "$redis_host" ] || [ "$redis_host" = "$REDIS_ADDR" ]; then
            redis_host="127.0.0.1"
        fi
        if [ -z "$redis_port" ] || [ "$redis_port" = "$REDIS_ADDR" ]; then
            redis_port="6379"
        fi

        if [ -n "${REDIS_PASSWORD:-}" ]; then
            if redis-cli -h "$redis_host" -p "$redis_port" -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
                log_success "Redis is reachable"
            else
                log_warn "Redis is not reachable at ${redis_host}:${redis_port}"
            fi
        else
            if redis-cli -h "$redis_host" -p "$redis_port" ping >/dev/null 2>&1; then
                log_success "Redis is reachable"
            else
                log_warn "Redis is not reachable at ${redis_host}:${redis_port}"
            fi
        fi
    fi
}

ensure_frontend_dependencies() {
    if [ ! -d "$PROJECT_ROOT/frontend/node_modules" ]; then
        log_info "frontend/node_modules missing, running npm install"
        (
            cd "$PROJECT_ROOT/frontend"
            npm install
        )
    fi
}

build_frontend() {
    log_info "Building frontend assets"
    (
        cd "$PROJECT_ROOT/frontend"
        VITE_IS_DOCKER=true npm run build
    )
    log_success "Frontend build completed"
}

build_backend() {
    local ldflags

    log_info "Building backend binary"
    cd "$PROJECT_ROOT"
    ldflags="$(./scripts/get_version.sh ldflags) -X 'google.golang.org/protobuf/reflect/protoregistry.conflictPolicy=warn'"
    go build -ldflags="$ldflags" -o "$PROJECT_ROOT/bin/weknora-app" ./cmd/server
    log_success "Backend build completed"
}

choose_docreader_command() {
    if [ -x "$PROJECT_ROOT/venv_weknora/bin/python" ]; then
        DOCREADER_COMMAND="$(quote_path "$PROJECT_ROOT/venv_weknora/bin/python") -m docreader.main"
        return
    fi

    if command -v uv >/dev/null 2>&1; then
        DOCREADER_COMMAND="uv run -m docreader.main"
        return
    fi

    if command -v python3 >/dev/null 2>&1; then
        DOCREADER_COMMAND="python3 -m docreader.main"
        return
    fi

    if command -v python >/dev/null 2>&1; then
        DOCREADER_COMMAND="python -m docreader.main"
        return
    fi

    fail "Unable to find a Python runtime for DocReader. Expected venv_weknora/bin/python, uv, python3, or python."
}

create_tmux_session() {
    local project_quoted env_quoted doc_log_quoted app_log_quoted app_bin_quoted storage_quoted
    local runtime_defaults docreader_cmd app_cmd

    project_quoted="$(quote_path "$PROJECT_ROOT")"
    env_quoted="$(quote_path "$PROJECT_ROOT/.env")"
    doc_log_quoted="$(quote_path "$PROJECT_ROOT/logs/docreader.log")"
    app_log_quoted="$(quote_path "$PROJECT_ROOT/logs/app.log")"
    app_bin_quoted="$(quote_path "$PROJECT_ROOT/bin/weknora-app")"
    storage_quoted="$(quote_path "$LOCAL_STORAGE_BASE_DIR")"

    tmux new-session -d -s "$SESSION_NAME" -n docreader
    tmux new-window -t "$SESSION_NAME" -n app
    tmux set-window-option -t "$SESSION_NAME:docreader" remain-on-exit on >/dev/null
    tmux set-window-option -t "$SESSION_NAME:app" remain-on-exit on >/dev/null

    runtime_defaults="export DB_HOST=\${DB_HOST:-127.0.0.1} && export DB_PORT=\${DB_PORT:-5432} && export REDIS_ADDR=\${REDIS_ADDR:-127.0.0.1:6379} && export DOCREADER_ADDR=\${DOCREADER_ADDR:-127.0.0.1:50051} && export DOCREADER_TRANSPORT=\${DOCREADER_TRANSPORT:-grpc} && export LOCAL_STORAGE_BASE_DIR=\${LOCAL_STORAGE_BASE_DIR:-$storage_quoted} && export WEKNORA_WEB_DIR=\${WEKNORA_WEB_DIR:-./frontend/dist} && export WEKNORA_SANDBOX_MODE=\${WEKNORA_SANDBOX_MODE:-disabled} && export GIN_MODE=\${GIN_MODE:-release}"
    docreader_cmd="cd $project_quoted && set -a && . $env_quoted && set +a && $runtime_defaults && export DOCREADER_GRPC_PORT=\${DOCREADER_GRPC_PORT:-50051} && export PYTHONUNBUFFERED=1 && $DOCREADER_COMMAND >> $doc_log_quoted 2>&1"
    app_cmd="cd $project_quoted && set -a && . $env_quoted && set +a && $runtime_defaults && $app_bin_quoted >> $app_log_quoted 2>&1"

    tmux send-keys -t "$SESSION_NAME:docreader" "$docreader_cmd" C-m
    tmux send-keys -t "$SESSION_NAME:app" "$app_cmd" C-m
}

print_summary() {
    echo
    log_success "Services started in tmux session: $SESSION_NAME"
    echo "  attach: tmux attach -t $SESSION_NAME"
    echo "  detach: Ctrl+b then d"
    echo "  status: bash/status_server_tmux.sh"
    echo "  stop:   bash/stop_server_tmux.sh"
    echo
    echo "  docreader log: $PROJECT_ROOT/logs/docreader.log"
    echo "  app log:       $PROJECT_ROOT/logs/app.log"
    echo
    echo "  open in browser: http://<server-ip>:8080"
}

main() {
    require_cmd tmux
    require_cmd go
    require_cmd npm

    if session_exists; then
        fail "tmux session '$SESSION_NAME' already exists. Stop it first or set WEKNORA_TMUX_SESSION to another name."
    fi

    load_env
    apply_local_defaults
    ensure_directories
    check_dependencies
    ensure_frontend_dependencies
    build_frontend
    build_backend
    choose_docreader_command
    create_tmux_session
    print_summary
}

main "$@"
