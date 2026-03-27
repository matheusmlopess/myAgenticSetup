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

# ── 1. APT Packages ──────────────────────────────────────────────────────────
echo ""
echo "── APT Packages ────────────────────────"

while IFS= read -r line || [[ -n "$line" ]]; do
  # skip comments and blank lines
  [[ "$line" =~ ^#.*$ || -z "${line// }" ]] && continue
  pkg="${line%% *}"  # strip inline comments
  if dpkg -s "$pkg" &>/dev/null 2>&1; then
    ok "$pkg"
  else
    miss "$pkg — not installed (apt)"
    ISSUES=$((ISSUES+1))
  fi
done < "$SCRIPT_DIR/packages.txt"

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

# ── 8. Global npm packages ────────────────────────────────────────────────────
echo ""
echo "── Global npm packages ─────────────────"

if [ -f "$SCRIPT_DIR/npm-globals.txt" ]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ || -z "${line// }" ]] && continue
    pkg="${line%%:*}"
    cmd="${line##*:}"
    [[ "$cmd" == "$pkg" ]] && cmd="$pkg"  # no colon = use pkg name as cmd
    if command -v "$cmd" &>/dev/null; then
      ok "$pkg ($cmd)"
    else
      miss "$pkg — not installed globally"
      ISSUES=$((ISSUES+1))
    fi
  done < "$SCRIPT_DIR/npm-globals.txt"
else
  warn "npm-globals.txt not found — skipping"
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
