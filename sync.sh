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
REMOTE_REF="origin/master"

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

refresh_last_sync() {
  local now="$1"

  if $DRY_RUN; then
    echo "  [dry-run] would update .last_sync to $now"
  else
    echo "$now" > "$SCRIPT_DIR/.last_sync"
  fi
}

abort_sync() {
  note "$1"
  log "Sync aborted — $1"
  exit 1
}

scan_for_secrets() {
  local pattern
  pattern='(-----BEGIN (RSA|OPENSSH|EC|PGP) PRIVATE KEY-----|_authToken=|authToken=|password=|passwd=|ghp_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]+|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{20,})'

  if ! command -v rg &>/dev/null; then
    note "ripgrep not installed — skipping secret scan gate"
    return
  fi

  if rg -n -H -e "$pattern" dotfiles/.zshrc dotfiles/.bashrc dotfiles/.gitconfig.template dotfiles/.npmrc.template packages.txt >/tmp/wsl_setup_secret_scan.out 2>/dev/null; then
    cat /tmp/wsl_setup_secret_scan.out | while IFS= read -r line; do
      note "secret-like content detected: $line"
    done
    rm -f /tmp/wsl_setup_secret_scan.out
    abort_sync "Secret scan failed. Remove sensitive values before syncing."
  fi

  rm -f /tmp/wsl_setup_secret_scan.out
}

print_managed_diff() {
  local range="$1"
  local diff_output

  diff_output=$(git diff --name-status "$range" -- dotfiles packages.txt .last_sync 2>/dev/null || true)
  if [ -n "$diff_output" ]; then
    echo "$diff_output" | while IFS= read -r line; do
      note "managed change: $line"
    done
  fi
}

ensure_clean_managed_files() {
  local dirty

  dirty=$(git status --porcelain -- dotfiles packages.txt 2>/dev/null || true)
  if [ -n "$dirty" ]; then
    echo "$dirty" | while IFS= read -r line; do
      note "local repo change pending: $line"
    done
    abort_sync "Managed repo files already have local edits. Commit, stash, or discard them before running sync."
  fi
}

fetch_remote_state() {
  if git fetch --quiet origin master; then
    info "Fetched latest remote state"
  else
    abort_sync "Unable to fetch $REMOTE_REF. Sync requires remote validation before updating managed files."
  fi
}

validate_branch_state() {
  local local_head remote_head merge_base

  local_head=$(git rev-parse HEAD)
  remote_head=$(git rev-parse "$REMOTE_REF")
  merge_base=$(git merge-base HEAD "$REMOTE_REF")

  if [ "$local_head" = "$remote_head" ]; then
    info "Local branch matches $REMOTE_REF"
    return
  fi

  if [ "$local_head" = "$merge_base" ]; then
    print_managed_diff "HEAD..$REMOTE_REF"
    abort_sync "Local branch is behind $REMOTE_REF. Pull the remote changes before syncing."
  fi

  if [ "$remote_head" = "$merge_base" ]; then
    info "Local branch is ahead of $REMOTE_REF"
    return
  fi

  print_managed_diff "$merge_base..$REMOTE_REF"
  abort_sync "Local branch has diverged from $REMOTE_REF. Reconcile the branch before syncing."
}

echo ""
echo "========================================"
echo "  WSL Sync — $(date '+%Y-%m-%d %H:%M')"
$DRY_RUN && echo "  MODE: DRY RUN (no changes will be made)"
echo "========================================"

cd "$SCRIPT_DIR"

# ── 1. Validate repo state ────────────────────────────────────────────────────
step "Validating repo state"

ensure_clean_managed_files

if git rev-parse --is-inside-work-tree &>/dev/null; then
  fetch_remote_state
  validate_branch_state
else
  abort_sync "sync.sh must run inside the repo worktree."
fi

# ── 2. Copy current dotfiles into the repo ────────────────────────────────────
step "Syncing dotfiles"

DOTFILES=(
  ".zshrc"
  ".bashrc"
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

# ── 3. Snapshot installed packages ───────────────────────────────────────────
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

# ── 4. Commit and push if anything changed ────────────────────────────────────
step "Pushing to GitHub"

SYNC_TS=$(date +%s)

if ! $DRY_RUN; then
  scan_for_secrets

  if [ "$CHANGED" = true ]; then
    # Include the sync timestamp when there is a real snapshot update to publish.
    refresh_last_sync "$SYNC_TS"
    git add dotfiles/.zshrc dotfiles/.bashrc dotfiles/.gitconfig.template dotfiles/.npmrc.template packages.txt .last_sync 2>/dev/null || true
  else
    git add dotfiles/.zshrc dotfiles/.bashrc dotfiles/.gitconfig.template dotfiles/.npmrc.template packages.txt 2>/dev/null || true
  fi

  if ! git diff --cached --quiet; then
    COMMIT_MSG="chore: sync dotfiles and packages — $(date '+%Y-%m-%d')"
    git commit -m "$COMMIT_MSG"
    git push origin master
    info "Pushed to GitHub"
    log "Sync complete — changes pushed"
  else
    refresh_last_sync "$SYNC_TS"
    info "Nothing to commit — repo is up to date"
    info "Refreshed local .last_sync without creating a commit"
    log "Sync complete — no changes"
  fi
else
  if [ "$CHANGED" = true ]; then
    echo "  [dry-run] would update .last_sync, commit, and push detected changes"
  else
    echo "  [dry-run] would refresh local .last_sync without creating a commit"
  fi
fi

echo ""
echo "========================================"
echo -e "  ${GREEN}Sync complete!${NC}"
echo "========================================"
echo ""
