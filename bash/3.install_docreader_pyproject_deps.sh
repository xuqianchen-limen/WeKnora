#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCREADER_DIR="$PROJECT_ROOT/docreader"
VENV_DIR="${VENV_DIR:-$PROJECT_ROOT/venv_weknora}"
PYTHON_BIN="$VENV_DIR/bin/python"

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

require_path() {
    local path="$1"
    local message="$2"
    if [ ! -e "$path" ]; then
        fail "$message"
    fi
}

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        fail "Missing required command: $cmd"
    fi
}

install_with_uv() {
    log_info "Installing docreader dependencies with uv sync --active"
    (
        cd "$DOCREADER_DIR"
        VIRTUAL_ENV="$VENV_DIR" uv sync --active
    )
}

install_with_pip() {
    log_info "Installing docreader dependencies from pyproject.toml with pip"
    "$PYTHON_BIN" -m pip install --upgrade pip setuptools wheel
    "$PYTHON_BIN" -m pip install -e "$DOCREADER_DIR"
}

verify_imports() {
    log_info "Verifying core docreader imports"
    "$PYTHON_BIN" -c "import grpc; from grpc_health.v1 import health_pb2_grpc; import textract; from docreader.main import DocReaderServicer; print('docreader deps ok')"
    log_success "DocReader Python dependencies verified"
}

main() {
    require_path "$DOCREADER_DIR/pyproject.toml" "Missing $DOCREADER_DIR/pyproject.toml"
    require_path "$VENV_DIR" "Missing virtual environment: $VENV_DIR"
    require_path "$PYTHON_BIN" "Missing Python interpreter: $PYTHON_BIN"

    if command -v uv >/dev/null 2>&1; then
        install_with_uv
        if ! "$PYTHON_BIN" -c "import grpc; from grpc_health.v1 import health_pb2_grpc; import textract" >/dev/null 2>&1; then
            log_warn "uv sync did not install all required imports into $VENV_DIR, retrying with pip"
            install_with_pip
        fi
    else
        install_with_pip
    fi

    verify_imports
}

main "$@"
