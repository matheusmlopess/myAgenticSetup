#!/usr/bin/env bash
# sync.sh — Snapshots current dotfiles + installed packages into the repo and pushes.
# Designed to run via cron every 15 days, or manually at any time.
# Usage: bash sync.sh [--dry-run]

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
LOG_FILE="$SCRIPT_DIR/sync.log"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "\n${BLUE}==>${NC} $1"; }
info() { echo -e "  ${GREEN}✓${NC} $1"; }
note() { echo -e "  ${YELLOW}!${NC} $1"; }

run() {
  if $DRY_RUN; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

echo ""
echo "========================================"
echo "  WSL Sync — $(date '+%Y-%m-%d %H:%M')"
$DRY_RUN && echo "  MODE: DRY RUN (no changes will be made)"
echo "========================================"

# ── 1. Copy current dotfiles into the repo ────────────────────────────────────
step "Syncing dotfiles"

DOTFILES=(
  ".zshrc"
  ".bashrc"
  ".gitconfig"
  ".npmrc"
)

CHANGED=false

for f in "${DOTFILES[@]}"; do
  src="$HOME/$f"
  dst="$DOTFILES_DIR/$f"

  if [ ! -f "$src" ]; then
    note "$f not found in ~/ — skipping"
    continue
  fi

  if [ ! -f "$dst" ] || ! diff -q "$src" "$dst" &>/dev/null; then
    note "$f changed — updating"
    run cp "$src" "$dst"
    CHANGED=true
  else
    info "$f unchanged"
  fi
done

# ── 2. Snapshot installed packages ───────────────────────────────────────────
step "Snapshotting installed packages"

PKG_SNAPSHOT="$SCRIPT_DIR/packages.txt"

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

NEW_PACKAGES=$(generate_packages)
OLD_PACKAGES=$(cat "$PKG_SNAPSHOT" 2>/dev/null || echo "")

if [ "$NEW_PACKAGES" != "$OLD_PACKAGES" ]; then
  note "packages.txt changed — updating"
  if ! $DRY_RUN; then
    echo "$NEW_PACKAGES" > "$PKG_SNAPSHOT"
  else
    echo "  [dry-run] would write new packages.txt"
  fi
  CHANGED=true
else
  info "packages.txt unchanged"
fi

# ── 3. Commit and push if anything changed ────────────────────────────────────
step "Pushing to GitHub"

cd "$SCRIPT_DIR"

if ! $DRY_RUN; then
  git add dotfiles/ packages.txt 2>/dev/null || true

  if ! git diff --cached --quiet; then
    COMMIT_MSG="chore: sync dotfiles and packages — $(date '+%Y-%m-%d')"
    git commit -m "$COMMIT_MSG"
    git push origin master
    info "Pushed to GitHub"
    log "Sync complete — changes pushed"
  else
    info "Nothing to commit — repo is up to date"
    log "Sync complete — no changes"
  fi
else
  echo "  [dry-run] would commit and push if changes detected"
fi

echo ""
echo "========================================"
echo -e "  ${GREEN}Sync complete!${NC}"
echo "========================================"
echo ""
