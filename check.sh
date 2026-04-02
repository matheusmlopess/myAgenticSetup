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
REMOTE_REF="origin/master"

generate_packages() {
  echo "# APT packages explicitly installed (auto-generated $(date '+%Y-%m-%d'))"
  echo "# Do not edit manually — updated by sync.sh"
  echo ""
  echo "## APT (manually installed)"
  apt-mark showmanual 2>/dev/null | sort
  echo ""
  if command -v npm &>/dev/null; then
    echo "## npm global packages"
    npm list -g --depth=0 --parseable 2>/dev/null | tail -n +2 | xargs -I{} basename {} || true
  fi
  echo ""
  if command -v pip3 &>/dev/null; then
    echo "## pip3 global packages"
    pip3 list --not-required --format=freeze 2>/dev/null | grep -v "^#" || true
  fi
}

check_repo_sync_status() {
  local fetch_ok=true
  local local_head remote_head merge_base
  local managed_dirty remote_managed_changes

  echo ""
  echo "── Repo Sync Status ────────────────────"

  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    warn "Not inside a git worktree — skipping repo sync checks"
    return
  fi

  if git fetch --quiet origin master 2>/dev/null; then
    ok "Fetched latest remote state"
  else
    warn "Could not fetch $REMOTE_REF — remote drift could not be verified"
    ISSUES=$((ISSUES+1))
    fetch_ok=false
  fi

  managed_dirty=$(git status --porcelain -- dotfiles packages.txt 2>/dev/null || true)
  if [ -n "$managed_dirty" ]; then
    warn "Managed repo snapshot has local edits pending"
    ISSUES=$((ISSUES+1))
  else
    ok "Managed repo snapshot is clean"
  fi

  if [ "$fetch_ok" = false ]; then
    return
  fi

  local_head=$(git rev-parse HEAD)
  remote_head=$(git rev-parse "$REMOTE_REF")
  merge_base=$(git merge-base HEAD "$REMOTE_REF")

  if [ "$local_head" = "$remote_head" ]; then
    ok "Branch is up to date with $REMOTE_REF"
  elif [ "$local_head" = "$merge_base" ]; then
    warn "Branch is behind $REMOTE_REF"
    remote_managed_changes=$(git diff --name-status "HEAD..$REMOTE_REF" -- dotfiles packages.txt 2>/dev/null || true)
    if [ -n "$remote_managed_changes" ]; then
      echo "$remote_managed_changes" | while IFS= read -r line; do
        warn "Remote managed change: $line"
      done
    fi
    ISSUES=$((ISSUES+1))
  elif [ "$remote_head" = "$merge_base" ]; then
    ok "Branch is ahead of $REMOTE_REF"
  else
    warn "Branch has diverged from $REMOTE_REF"
    remote_managed_changes=$(git diff --name-status "$merge_base..$REMOTE_REF" -- dotfiles packages.txt 2>/dev/null || true)
    if [ -n "$remote_managed_changes" ]; then
      echo "$remote_managed_changes" | while IFS= read -r line; do
        warn "Remote managed change: $line"
      done
    fi
    ISSUES=$((ISSUES+1))
  fi
}

echo ""
echo "========================================"
echo "  WSL Setup Check — $(date '+%Y-%m-%d %H:%M')"
echo "========================================"

check_repo_sync_status

# ── 1. APT Packages ──────────────────────────────────────────────────────────
echo ""
echo "── APT Packages ────────────────────────"

UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "")
IN_APT_SECTION=false
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" == "## APT (manually installed)" ]]; then
    IN_APT_SECTION=true
    continue
  fi
  if [[ "$line" == "## "* ]]; then
    IN_APT_SECTION=false
    continue
  fi
  # skip comments and blank lines
  [[ "$line" =~ ^#.*$ || -z "${line// }" ]] && continue
  [[ "$IN_APT_SECTION" != true ]] && continue
  pkg="${line%% *}"  # strip inline comments
  # chromium-browser is not installable on Ubuntu 24.04+ (noble) — skip check
  if [[ "$pkg" == "chromium-browser" ]] && [[ "$UBUNTU_CODENAME" != "focal" && "$UBUNTU_CODENAME" != "jammy" ]]; then
    warn "chromium-browser — skipped (not supported on Ubuntu $UBUNTU_CODENAME)"
    continue
  fi
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

echo ""
echo "── Snapshot Drift ──────────────────────"

check_snapshot_drift() {
  local file="$1"
  local repo_file="$SCRIPT_DIR/dotfiles/$file"

  if [ ! -f "$HOME/$file" ] || [ ! -f "$repo_file" ]; then
    return
  fi

  if diff -q "$HOME/$file" "$repo_file" &>/dev/null; then
    ok "$file matches tracked snapshot"
  else
    warn "$file differs from tracked snapshot"
    ISSUES=$((ISSUES+1))
  fi
}

check_snapshot_drift ".zshrc"
check_snapshot_drift ".bashrc"

CURRENT_PACKAGES=$(generate_packages)
TRACKED_PACKAGES=$(cat "$SCRIPT_DIR/packages.txt" 2>/dev/null || echo "")
if [ "$CURRENT_PACKAGES" = "$TRACKED_PACKAGES" ]; then
  ok "packages.txt matches current package snapshot"
else
  warn "packages.txt differs from current package snapshot"
  ISSUES=$((ISSUES+1))
fi

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

# ── 9. AI CLI tools ───────────────────────────────────────────────────────────
echo ""
echo "── AI CLI tools ────────────────────────"

if command -v claude &>/dev/null; then
  ok "claude"
else
  miss "claude — not installed"
  ISSUES=$((ISSUES+1))
fi

if command -v codex &>/dev/null; then
  ok "codex"
else
  miss "codex — not installed"
  ISSUES=$((ISSUES+1))
fi

# ── 10. Global Python tools ───────────────────────────────────────────────────
echo ""
echo "── Global Python tools ─────────────────"

if [ -f "$SCRIPT_DIR/python-globals.txt" ]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ || -z "${line// }" ]] && continue
    pkg="${line%%:*}"
    cmd="${line##*:}"
    [[ "$cmd" == "$pkg" ]] && cmd="$pkg"
    if command -v "$cmd" &>/dev/null; then
      ok "$pkg ($cmd)"
    else
      miss "$pkg — not installed globally"
      ISSUES=$((ISSUES+1))
    fi
  done < "$SCRIPT_DIR/python-globals.txt"
else
  warn "python-globals.txt not found — skipping"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
if [ "$ISSUES" -eq 0 ]; then
  echo -e "  ${GREEN}All checks passed! Setup looks good.${NC}"
else
  echo -e "  ${RED}$ISSUES issue(s) found. Review the warnings above and run setup.sh or sync.sh as appropriate.${NC}"
fi
echo "========================================"
echo ""
