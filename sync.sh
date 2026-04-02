#!/usr/bin/env bash
# sync.sh — Snapshots current dotfiles + installed packages into a fresh branch and opens a PR.
# Designed to run via cron every 15 days, or manually at any time.
# Usage: bash sync.sh [--dry-run] [--no-pr] [--branch-name NAME]

set -euo pipefail

DRY_RUN=false
OPEN_PR=true
BRANCH_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --no-pr)
      OPEN_PR=false
      shift
      ;;
    --branch-name)
      BRANCH_NAME="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
LOG_FILE="$SCRIPT_DIR/sync.log"
LOCAL_LAST_SYNC_FILE="$SCRIPT_DIR/.last_sync.local"
REMOTE_NAME="${SYNC_REMOTE_NAME:-origin}"
BASE_BRANCH="${SYNC_BASE_BRANCH:-master}"
REMOTE_REF="$REMOTE_NAME/$BASE_BRANCH"

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
    echo "  [dry-run] would update .last_sync.local to $now"
  else
    echo "$now" > "$LOCAL_LAST_SYNC_FILE"
  fi
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g'
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

  diff_output=$(git diff --name-status "$range" -- dotfiles packages.txt 2>/dev/null || true)
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

ensure_clean_branch_context() {
  local current_branch extra_dirty

  current_branch=$(git branch --show-current)
  if [ "$current_branch" != "$BASE_BRANCH" ]; then
    abort_sync "sync.sh must start from the local $BASE_BRANCH branch so it can create a fresh sync branch."
  fi

  extra_dirty=$(git status --porcelain --untracked-files=all -- . ':(exclude)dotfiles' ':(exclude)packages.txt' ':(exclude).last_sync.local' ':(exclude)sync.log' ':(exclude).codex' 2>/dev/null || true)
  if [ -n "$extra_dirty" ]; then
    echo "$extra_dirty" | while IFS= read -r line; do
      note "local worktree change pending: $line"
    done
    abort_sync "Worktree must be clean before sync creates a branch. Commit or stash unrelated changes first."
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

  if [ "$local_head" = "$merge_base" ] && [ "$local_head" != "$remote_head" ]; then
    print_managed_diff "HEAD..$REMOTE_REF"
    note "Local $BASE_BRANCH is behind $REMOTE_REF — pulling automatically"
    if ! $DRY_RUN; then
      git pull --ff-only "$REMOTE_NAME" "$BASE_BRANCH" || abort_sync "Auto-pull failed. Resolve manually before syncing."
      info "Pulled latest changes from $REMOTE_REF"
    else
      echo "  [dry-run] would run: git pull --ff-only $REMOTE_NAME $BASE_BRANCH"
    fi
    return
  fi

  if [ "$remote_head" = "$merge_base" ] && [ "$local_head" != "$remote_head" ]; then
    abort_sync "Local $BASE_BRANCH is ahead of $REMOTE_REF. Rebase or reconcile it before syncing."
  fi

  if [ "$local_head" = "$remote_head" ]; then
    info "Local $BASE_BRANCH matches $REMOTE_REF"
    return
  fi

  print_managed_diff "$merge_base..$REMOTE_REF"
  abort_sync "Local $BASE_BRANCH has diverged from $REMOTE_REF. Reconcile the branch before syncing."
}

make_sync_branch_name() {
  local host_slug stamp
  host_slug=$(slugify "$(hostname -s 2>/dev/null || hostname)")
  stamp=$(date '+%Y%m%d-%H%M%S')

  if [ -n "$BRANCH_NAME" ]; then
    echo "$BRANCH_NAME"
  else
    echo "sync/${host_slug}-${stamp}"
  fi
}

create_sync_branch() {
  local branch="$1"

  if $DRY_RUN; then
    echo "  [dry-run] would create branch $branch"
  else
    git switch -c "$branch"
    info "Created branch $branch"
  fi
}

push_sync_branch() {
  local branch="$1"

  if $DRY_RUN; then
    echo "  [dry-run] would push branch $branch to $REMOTE_NAME"
  else
    git push -u "$REMOTE_NAME" "$branch"
    info "Pushed branch $branch"
  fi
}

open_pull_request() {
  local branch="$1"
  local title="$2"
  local body

  if ! $OPEN_PR; then
    note "PR creation disabled by --no-pr"
    return
  fi

  if ! command -v gh &>/dev/null; then
    note "gh not installed — skipping PR creation"
    return
  fi

  if ! gh auth status &>/dev/null 2>&1; then
    note "gh is not authenticated — skipping PR creation"
    return
  fi

  body=$(cat <<EOF
## Summary

- sync dotfiles snapshot
- sync package snapshot

## Notes

- generated from environment: $(hostname -s 2>/dev/null || hostname)
- review package and dotfile drift before merge
EOF
)

  if $DRY_RUN; then
    echo "  [dry-run] would open PR from $branch to $BASE_BRANCH"
  else
    gh pr create --base "$BASE_BRANCH" --head "$branch" --title "$title" --body "$body"
    info "Opened PR for $branch"
  fi
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
ensure_clean_branch_context

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
step "Creating branch and publishing review"

SYNC_TS=$(date +%s)
SYNC_BRANCH=$(make_sync_branch_name)

if ! $DRY_RUN; then
  scan_for_secrets

  if [ "$CHANGED" = true ]; then
    create_sync_branch "$SYNC_BRANCH"
    refresh_last_sync "$SYNC_TS"
    git add dotfiles/.zshrc dotfiles/.bashrc dotfiles/.gitconfig.template dotfiles/.npmrc.template packages.txt 2>/dev/null || true
  else
    git add dotfiles/.zshrc dotfiles/.bashrc dotfiles/.gitconfig.template dotfiles/.npmrc.template packages.txt 2>/dev/null || true
  fi

  if ! git diff --cached --quiet; then
    COMMIT_MSG="chore: sync environment snapshot — $(date '+%Y-%m-%d')"
    git commit -m "$COMMIT_MSG"
    push_sync_branch "$SYNC_BRANCH"
    open_pull_request "$SYNC_BRANCH" "$COMMIT_MSG"
    log "Sync complete — branch pushed for review"
  else
    refresh_last_sync "$SYNC_TS"
    info "Nothing to commit — repo is up to date"
    info "Refreshed local .last_sync.local without creating a commit"
    log "Sync complete — no changes"
  fi
else
  if [ "$CHANGED" = true ]; then
    create_sync_branch "$SYNC_BRANCH"
    echo "  [dry-run] would update .last_sync.local, commit, push $SYNC_BRANCH, and open a PR"
  else
    echo "  [dry-run] would refresh local .last_sync.local without creating a commit"
  fi
fi

echo ""
echo "========================================"
echo -e "  ${GREEN}Sync complete!${NC}"
echo "========================================"
echo ""
