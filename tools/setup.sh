#!/usr/bin/env bash
# Usage: ./tools/setup.sh
# Description: Sets up the local development environment for DevPose contributors
# Dependencies: git, curl, npm (optional)

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[info]${NC}  $*"; }
log_ok()      { echo -e "${GREEN}[ok]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[warn]${NC}  $*"; }
log_error()   { echo -e "${RED}[error]${NC} $*"; }

# ─── Checks ───────────────────────────────────────────────────────────────────
check_command() {
  local cmd="$1"
  if command -v "$cmd" &>/dev/null; then
    log_ok "$cmd is installed ($(command -v "$cmd"))"
  else
    log_warn "$cmd is NOT installed — some features may not work"
  fi
}

echo ""
echo "  DevPose — Developer Environment Setup"
echo "  ──────────────────────────────────────"
echo ""

# ─── Required Tools ───────────────────────────────────────────────────────────
log_info "Checking required tools..."
check_command git
check_command curl
check_command bash

echo ""

# ─── Recommended Tools ────────────────────────────────────────────────────────
log_info "Checking recommended tools..."
check_command shellcheck
check_command jq
check_command npm
check_command node

echo ""

# ─── Git Configuration ────────────────────────────────────────────────────────
log_info "Configuring git defaults..."

git config --local pull.rebase true
log_ok "pull.rebase = true"

git config --local rebase.autoStash true
log_ok "rebase.autoStash = true"

# Set up useful aliases (local to this repo)
git config --local alias.lg "log --oneline --graph --decorate --all"
git config --local alias.st "status -sb"
git config --local alias.undo "reset --soft HEAD~1"
log_ok "git aliases set: lg, st, undo"

echo ""

# ─── Claude Code (AI) ─────────────────────────────────────────────────────────
log_info "Checking AI tools..."
if command -v claude &>/dev/null; then
  log_ok "Claude Code is installed: $(claude --version 2>/dev/null || echo 'version unknown')"
else
  log_warn "Claude Code is not installed."
  echo "         Install with: npm install -g @anthropic-ai/claude-code"
  echo "         Docs: https://docs.anthropic.com/claude-code"
fi

echo ""

# ─── Done ─────────────────────────────────────────────────────────────────────
log_ok "Setup complete! You're ready to contribute."
echo ""
echo "  Next steps:"
echo "  1. Read guidelines/code-of-conduct.md"
echo "  2. Read guidelines/git-workflow.md"
echo "  3. Read docs/ai-workflow.md for AI productivity tips"
echo "  4. Check for open issues labeled 'good-first-issue'"
echo ""
