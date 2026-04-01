#!/bin/bash
# ============================================================
# clean_git_push.sh
# 从 Git 历史中彻底删除大文件并强制推送
# 用法: bash clean_git_push.sh
# ============================================================

set -e

# -------- 配置项（按需修改） --------
TARGET_FILE="bin/weknora-app"          # 要删除的大文件路径
BRANCH="feature/tcsabot"              # 目标分支
REMOTE="origin"                       # remote 名称
REMOTE_URL="cvychen:xuqianchen-limen/WeKnora.git"  # remote 地址
# ------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── 0. 确认在 Git 仓库中 ──────────────────────────────────
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || error "请在 Git 仓库根目录下运行此脚本"

info "开始清理大文件: $TARGET_FILE"

# ── 1. Stash 未暂存/未提交的更改 ─────────────────────────
STASH_NEEDED=false
if ! git diff --quiet || ! git diff --cached --quiet; then
  warn "检测到未提交的更改，自动 stash..."
  git stash push -m "auto-stash before clean_git_push"
  STASH_NEEDED=true
fi

# ── 2. 安装 git-filter-repo（若未安装）────────────────────
if ! command -v git-filter-repo &> /dev/null; then
  warn "git-filter-repo 未安装，尝试自动安装..."
  if command -v pip3 &> /dev/null; then
    pip3 install git-filter-repo --quiet && info "git-filter-repo 安装成功"
  elif command -v pip &> /dev/null; then
    pip install git-filter-repo --quiet && info "git-filter-repo 安装成功"
  elif command -v apt-get &> /dev/null; then
    sudo apt-get install -y git-filter-repo --quiet && info "git-filter-repo 安装成功"
  else
    error "无法自动安装 git-filter-repo，请手动安装后重试：pip install git-filter-repo"
  fi
fi

# ── 3. 从所有历史中删除大文件 ────────────────────────────
info "从全部历史记录中删除 $TARGET_FILE ..."
git filter-repo --path "$TARGET_FILE" --invert-paths --force

# ── 4. 清理残留对象 ──────────────────────────────────────
info "清理残留 Git 对象..."
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# ── 5. 重新设置 remote（filter-repo 会移除 remote）───────
if ! git remote get-url "$REMOTE" &> /dev/null; then
  warn "remote '$REMOTE' 已被移除，重新添加..."
  git remote add "$REMOTE" "$REMOTE_URL"
fi
info "Remote: $(git remote get-url $REMOTE)"

# ── 6. 恢复 stash ────────────────────────────────────────
if [ "$STASH_NEEDED" = true ]; then
  info "恢复之前 stash 的更改..."
  git stash pop
fi

# ── 7. 将大文件加入 .gitignore ───────────────────────────
if ! grep -qxF "$TARGET_FILE" .gitignore 2>/dev/null; then
  info "将 $TARGET_FILE 添加到 .gitignore..."
  echo "$TARGET_FILE" >> .gitignore
  git add .gitignore
  git commit -m "chore: ignore large binary $TARGET_FILE"
fi

# ── 8. 强制推送 ───────────────────────────────────────────
info "强制推送到 $REMOTE/$BRANCH ..."
git push "$REMOTE" "$BRANCH" --force

echo ""
echo -e "${GREEN}✅ 完成！大文件已从历史中清除，并成功推送到 $REMOTE/$BRANCH${NC}"