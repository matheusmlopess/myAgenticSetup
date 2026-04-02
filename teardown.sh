#!/usr/bin/env bash
# teardown.sh — Reverses what setup.sh did.
# Usage: bash teardown.sh [--dry-run]
#
# What it does (in reverse order of setup.sh):
#   1. Uninstalls global npm packages (from npm-globals.txt)
#   2. Uninstalls global pipx tools (from python-globals.txt)
#   3. Removes NVM (~/.nvm)
#   4. Removes Oh My Zsh (~/.oh-my-zsh)
#   5. Restores dotfile backups (or removes managed dotfiles)
#   6. Reverts default shell to bash
#   7. Warns about APT packages (not removed automatically)

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

step()  { echo -e "\n${GREEN}==>${NC} $1"; }
note()  { echo -e "  ${YELLOW}!${NC} $1"; }
info()  { echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { echo -e "  ${RED}✗${NC} $1"; }

run() {
  if $DRY_RUN; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

echo ""
echo "========================================"
echo "  WSL Teardown — $(date '+%Y-%m-%d %H:%M')"
$DRY_RUN && echo "  MODE: DRY RUN (no changes will be made)"
echo "========================================"

# ── 1. Global npm packages ────────────────────────────────────────────────────
step "Uninstalling global npm packages"

if [ -f "$SCRIPT_DIR/npm-globals.txt" ]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ || -z "${line// }" ]] && continue
    pkg="${line%%:*}"
    if npm list -g --depth=0 "$pkg" &>/dev/null 2>&1; then
      note "Removing $pkg..."
      run npm uninstall -g "$pkg"
      info "$pkg removed"
    else
      info "$pkg not installed — skipping"
    fi
  done < "$SCRIPT_DIR/npm-globals.txt"
else
  note "npm-globals.txt not found — skipping"
fi

# ── 2. Global pipx tools ─────────────────────────────────────────────────────
step "Uninstalling global pipx tools"

if [ -f "$SCRIPT_DIR/python-globals.txt" ]; then
  if command -v pipx &>/dev/null; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" =~ ^#.*$ || -z "${line// }" ]] && continue
      pkg="${line%%:*}"
      if pipx list 2>/dev/null | grep -q "$pkg"; then
        note "Removing $pkg..."
        run pipx uninstall "$pkg"
        info "$pkg removed"
      else
        info "$pkg not installed — skipping"
      fi
    done < "$SCRIPT_DIR/python-globals.txt"
  else
    note "pipx not found — skipping"
  fi
else
  note "python-globals.txt not found — skipping"
fi

# ── 3. NVM ────────────────────────────────────────────────────────────────────
step "Removing NVM"

if [ -d "$HOME/.nvm" ]; then
  note "Removing ~/.nvm..."
  run rm -rf "$HOME/.nvm"
  info "~/.nvm removed"
else
  info "~/.nvm not found — skipping"
fi

# ── 4. Oh My Zsh ─────────────────────────────────────────────────────────────
step "Removing Oh My Zsh"

if [ -d "$HOME/.oh-my-zsh" ]; then
  if [ -f "$HOME/.oh-my-zsh/tools/uninstall.sh" ] && ! $DRY_RUN; then
    note "Running Oh My Zsh uninstall script..."
    env ZSH="$HOME/.oh-my-zsh" bash "$HOME/.oh-my-zsh/tools/uninstall.sh" --unattended || true
    info "Oh My Zsh uninstalled"
  elif $DRY_RUN; then
    echo "  [dry-run] would run: ~/.oh-my-zsh/tools/uninstall.sh --unattended"
  else
    note "Uninstall script not found — removing ~/.oh-my-zsh directly"
    run rm -rf "$HOME/.oh-my-zsh"
    info "~/.oh-my-zsh removed"
  fi
else
  info "~/.oh-my-zsh not found — skipping"
fi

# ── 5. Dotfiles ───────────────────────────────────────────────────────────────
step "Restoring dotfiles"

restore_dotfile() {
  local file="$1"
  local dst="$HOME/$file"
  local latest_bak

  latest_bak=$(ls -t "${dst}.bak."* 2>/dev/null | head -1 || true)

  if [ -n "$latest_bak" ]; then
    note "Restoring $file from $latest_bak..."
    run cp "$latest_bak" "$dst"
    info "$file restored"
  elif [ -f "$dst" ]; then
    note "No backup for $file — removing"
    run rm "$dst"
    info "$file removed"
  else
    info "$file not found — skipping"
  fi
}

restore_dotfile ".zshrc"
restore_dotfile ".bashrc"
restore_dotfile ".gitconfig"
restore_dotfile ".npmrc"

# ── 6. Default shell ─────────────────────────────────────────────────────────
step "Reverting default shell to bash"

CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
if [[ "$CURRENT_SHELL" == *"bash"* ]]; then
  info "Default shell is already bash"
else
  run chsh -s "$(which bash)"
  info "Default shell reverted to bash (restart terminal to apply)"
fi

# ── 7. APT packages ───────────────────────────────────────────────────────────
step "APT packages (manual removal required)"

if [ -f "$SCRIPT_DIR/packages-desired.txt" ]; then
  pkgs=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ || -z "${line// }" ]] && continue
    pkgs+=("${line%% *}")
  done < "$SCRIPT_DIR/packages-desired.txt"

  echo ""
  note "The following packages were installed by setup.sh."
  note "Remove them manually if needed:"
  echo ""
  echo "  sudo apt remove ${pkgs[*]}"
  echo ""
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo -e "  ${GREEN}Teardown complete!${NC}"
echo ""
echo "  Next steps:"
echo "   • Restart your terminal"
echo "   • Remove APT packages manually if needed (see above)"
echo "   • Claude CLI lives in ~/.local — remove manually if needed"
echo "========================================"
echo ""
