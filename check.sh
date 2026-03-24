#!/usr/bin/env bash
# check.sh — Audits the current WSL environment against the expected setup.
# Run: bash check.sh
# Outputs a report of what is installed, missing, or misconfigured.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ok()   { echo -e "  ${GREEN}[OK]${NC}    $1"; }
miss() { echo -e "  ${RED}[MISS]${NC}  $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC}  $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISSUES=0

echo ""
echo "========================================"
echo "  WSL Setup Check — $(date '+%Y-%m-%d %H:%M')"
echo "========================================"

# ── 1. CLI Tools ─────────────────────────────────────────────────────────────
echo ""
echo "── CLI Tools ───────────────────────────"

check_cmd() {
  local cmd="$1"
  local label="${2:-$1}"
  if command -v "$cmd" &>/dev/null; then
    ok "$label ($(command -v "$cmd"))"
  else
    miss "$label — not found"
    ISSUES=$((ISSUES+1))
  fi
}

check_cmd git     "git"
check_cmd zsh     "zsh"
check_cmd curl    "curl"
check_cmd wget    "wget"
check_cmd make    "make"
check_cmd gcc     "gcc / build-essential"
check_cmd gh      "GitHub CLI (gh)"
check_cmd node    "Node.js"
check_cmd npm     "npm"
check_cmd python3 "python3"
check_cmd jq      "jq"
check_cmd unzip   "unzip"

# ── 2. NVM ───────────────────────────────────────────────────────────────────
echo ""
echo "── NVM ─────────────────────────────────"
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  ok "NVM installed at ~/.nvm"
else
  miss "NVM — not found at ~/.nvm"
  ISSUES=$((ISSUES+1))
fi

# ── 3. Oh My Zsh ─────────────────────────────────────────────────────────────
echo ""
echo "── Oh My Zsh ───────────────────────────"
if [ -d "$HOME/.oh-my-zsh" ]; then
  ok "Oh My Zsh installed at ~/.oh-my-zsh"
else
  miss "Oh My Zsh — not found"
  ISSUES=$((ISSUES+1))
fi

# ── 4. Dotfiles ──────────────────────────────────────────────────────────────
echo ""
echo "── Dotfiles ────────────────────────────"

check_dotfile() {
  local file="$1"
  if [ -f "$HOME/$file" ]; then
    ok "$file"
  else
    miss "$file — not found in ~/"
    ISSUES=$((ISSUES+1))
  fi
}

check_dotfile ".zshrc"
check_dotfile ".bashrc"
check_dotfile ".gitconfig"
check_dotfile ".npmrc"

# ── 5. Git config ────────────────────────────────────────────────────────────
echo ""
echo "── Git Config ──────────────────────────"
GIT_USER=$(git config --global user.name 2>/dev/null || echo "")
GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

if [ -n "$GIT_USER" ]; then
  ok "git user.name = $GIT_USER"
else
  miss "git user.name — not set"
  ISSUES=$((ISSUES+1))
fi

if [ -n "$GIT_EMAIL" ]; then
  ok "git user.email = $GIT_EMAIL"
else
  miss "git user.email — not set"
  ISSUES=$((ISSUES+1))
fi

# ── 6. GitHub CLI auth ───────────────────────────────────────────────────────
echo ""
echo "── GitHub CLI Auth ─────────────────────"
if command -v gh &>/dev/null; then
  if gh auth status &>/dev/null 2>&1; then
    ok "gh is authenticated"
  else
    warn "gh is installed but NOT authenticated — run: gh auth login"
    ISSUES=$((ISSUES+1))
  fi
fi

# ── 7. Default shell ─────────────────────────────────────────────────────────
echo ""
echo "── Default Shell ───────────────────────"
CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
if [[ "$CURRENT_SHELL" == *"zsh"* ]]; then
  ok "Default shell is zsh ($CURRENT_SHELL)"
else
  warn "Default shell is $CURRENT_SHELL (expected zsh)"
  warn "Run: chsh -s \$(which zsh)"
  ISSUES=$((ISSUES+1))
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
if [ "$ISSUES" -eq 0 ]; then
  echo -e "  ${GREEN}All checks passed! Setup looks good.${NC}"
else
  echo -e "  ${RED}$ISSUES issue(s) found. Run setup.sh to fix.${NC}"
fi
echo "========================================"
echo ""
