#!/usr/bin/env bash
# setup.sh — Bootstraps a fresh WSL Ubuntu install to match Matheus's setup.
# Usage: bash setup.sh [--dry-run]
#
# What it does:
#   1. Installs APT packages (git, zsh, curl, gh, node, python3, etc.)
#   2. Installs NVM
#   3. Installs Oh My Zsh
#   4. Copies dotfiles (.zshrc, .bashrc, .gitconfig, .npmrc)
#   5. Installs Claude CLI
#   6. Installs Codex CLI
#   7. Sets zsh as the default shell
#   8. Prompts to authenticate GitHub CLI
#   9. Installs Python security audit tools via pipx
#  10. Initializes the local sync reminder timestamp

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
EXISTING_GIT_USER="$(git config --global user.name 2>/dev/null || true)"
EXISTING_GIT_EMAIL="$(git config --global user.email 2>/dev/null || true)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

step()  { echo -e "\n${BLUE}==>${NC} $1"; }
info()  { echo -e "  ${GREEN}✓${NC} $1"; }
note()  { echo -e "  ${YELLOW}!${NC} $1"; }

run() {
  if $DRY_RUN; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

export PATH="$HOME/.local/bin:$PATH"

echo ""
echo "========================================"
echo "  WSL Setup — $(date '+%Y-%m-%d %H:%M')"
$DRY_RUN && echo "  MODE: DRY RUN (no changes will be made)"
echo "========================================"

# ── 0. Pre-flight: clean up any stale PPAs ────────────────────────────────────
if ls /etc/apt/sources.list.d/ 2>/dev/null | grep -q "saiarcot895"; then
  note "Removing incompatible Chromium PPA (leftover from a previous run)..."
  run sudo rm -f /etc/apt/sources.list.d/*saiarcot895*
  run sudo rm -f /etc/apt/trusted.gpg.d/*saiarcot895*
fi

# ── 1. APT packages ───────────────────────────────────────────────────────────
step "Installing APT packages (from packages-desired.txt)"

run sudo apt-get update -qq
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^#.*$ || -z "${line// }" ]] && continue
  pkg="${line%% *}"
  # chromium-browser is handled separately (WSL snap workaround)
  [[ "$pkg" == "chromium-browser" ]] && continue
  # npm is bundled with NodeSource nodejs — skip apt if already available, or fall through gracefully
  if [[ "$pkg" == "npm" ]] && command -v npm &>/dev/null; then
    info "npm already installed (via NodeSource/NVM) — skipping apt"
    continue
  fi
  if dpkg -s "$pkg" &>/dev/null 2>&1; then
    info "$pkg already installed"
  else
    note "Installing $pkg..."
    if [[ "$pkg" == "npm" ]]; then
      run sudo apt-get install -y -qq "$pkg" 2>/dev/null || note "npm apt install skipped — npm will be provided by NodeSource nodejs (step 4)"
    else
      run sudo apt-get install -y -qq "$pkg"
      info "$pkg installed"
    fi
    dpkg -s "$pkg" &>/dev/null 2>&1 && info "$pkg installed"
  fi
done < "$SCRIPT_DIR/packages-desired.txt"

# ── 2. Chromium (WSL-safe) ────────────────────────────────────────────────────
step "Installing Chromium Browser"
UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "")
if command -v chromium-browser &>/dev/null || command -v chromium &>/dev/null; then
  info "chromium already installed"
elif [[ "$UBUNTU_CODENAME" == "focal" || "$UBUNTU_CODENAME" == "jammy" ]]; then
  note "Installing Chromium via PPA (Ubuntu $UBUNTU_CODENAME)..."
  run sudo add-apt-repository -y ppa:saiarcot895/chromium-beta
  run sudo apt-get update -qq
  run sudo apt-get install -y chromium-browser
  info "chromium-browser installed"
else
  note "Skipping Chromium — Ubuntu $UBUNTU_CODENAME not supported by this installer (requires focal or jammy)"
fi

# ── 3. GitHub CLI ─────────────────────────────────────────────────────────────
step "Installing GitHub CLI (gh)"
if command -v gh &>/dev/null; then
  info "gh already installed ($(gh --version | head -1))"
else
  note "Adding GitHub CLI apt repo..."
  run bash -c '
    type -p curl >/dev/null || sudo apt install curl -y
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update -qq
    sudo apt install gh -y
  '
  info "gh installed"
fi

# ── 4. Node.js via NodeSource ─────────────────────────────────────────────────
step "Installing Node.js"
if command -v node &>/dev/null; then
  info "node already installed ($(node --version))"
else
  note "Installing Node.js 20.x via NodeSource..."
  run bash -c 'curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -'
  run sudo apt-get install -y nodejs
  info "node installed"
fi

# ── 5. NVM ────────────────────────────────────────────────────────────────────
step "Installing NVM"
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  info "NVM already installed"
else
  note "Installing NVM..."
  run bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash'
  info "NVM installed"
fi

# ── 6. Oh My Zsh ─────────────────────────────────────────────────────────────
step "Installing Oh My Zsh"
if [ -d "$HOME/.oh-my-zsh" ]; then
  info "Oh My Zsh already installed"
else
  note "Installing Oh My Zsh..."
  run bash -c 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
  info "Oh My Zsh installed"
fi

# ── 7. Global npm packages ────────────────────────────────────────────────────
step "Installing global npm packages (from npm-globals.txt)"

if [ -f "$SCRIPT_DIR/npm-globals.txt" ]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ || -z "${line// }" ]] && continue
    pkg="${line%%:*}"
    cmd="${line##*:}"
    [[ "$cmd" == "$pkg" ]] && cmd="$pkg"
    if command -v "$cmd" &>/dev/null; then
      info "$pkg already installed"
    else
      note "Installing $pkg..."
      run npm install -g "$pkg"
      info "$pkg installed"
    fi
  done < "$SCRIPT_DIR/npm-globals.txt"
else
  note "npm-globals.txt not found — skipping"
fi

# ── 8. Claude CLI ──────────────────────────────────────────────────────────────
step "Installing Claude CLI"
if command -v claude &>/dev/null; then
  info "claude already installed"
else
  note "Installing Claude CLI..."
  run bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
  info "claude installed"
fi

# ── 9. Global Python packages ─────────────────────────────────────────────────
step "Installing global Python tools (from python-globals.txt)"

if [ -f "$SCRIPT_DIR/python-globals.txt" ]; then
  if ! command -v pipx &>/dev/null; then
    note "pipx is required for Python CLI tools but was not found"
  else
    run pipx ensurepath >/dev/null 2>&1 || true
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" =~ ^#.*$ || -z "${line// }" ]] && continue
      pkg="${line%%:*}"
      cmd="${line##*:}"
      [[ "$cmd" == "$pkg" ]] && cmd="$pkg"
      if command -v "$cmd" &>/dev/null; then
        info "$pkg already installed"
      else
        note "Installing $pkg..."
        run pipx install "$pkg"
        info "$pkg installed"
      fi
    done < "$SCRIPT_DIR/python-globals.txt"
  fi
else
  note "python-globals.txt not found — skipping"
fi

# ── 10. Dotfiles ───────────────────────────────────────────────────────────────
step "Copying dotfiles"

copy_dotfile() {
  local src_name="$1"
  local dst_name="${2:-$1}"
  local src="$DOTFILES_DIR/$src_name"
  local dst="$HOME/$dst_name"
  if [ ! -f "$src" ]; then
    note "Source $src not found — skipping"
    return
  fi
  if [ -f "$dst" ]; then
    run cp "$dst" "${dst}.bak.$(date +%Y%m%d%H%M%S)"
    note "Backed up existing $dst_name → ${dst_name}.bak.*"
  fi
  run cp "$src" "$dst"
  info "Copied $src_name → ~/$dst_name"
}

copy_dotfile ".zshrc"
copy_dotfile ".bashrc"
copy_dotfile ".gitconfig.template" ".gitconfig"
copy_dotfile ".npmrc.template" ".npmrc"

step "Configuring Git identity"
TARGET_GIT_USER="$EXISTING_GIT_USER"
TARGET_GIT_EMAIL="$EXISTING_GIT_EMAIL"

if ! $DRY_RUN; then
  if [ -z "$TARGET_GIT_USER" ]; then
    read -rp "  Git user.name: " TARGET_GIT_USER
  fi
  if [ -z "$TARGET_GIT_EMAIL" ]; then
    read -rp "  Git user.email: " TARGET_GIT_EMAIL
  fi
fi

if [ -n "$TARGET_GIT_USER" ]; then
  run git config --global user.name "$TARGET_GIT_USER"
  info "Configured git user.name"
else
  note "git user.name left unset"
fi

if [ -n "$TARGET_GIT_EMAIL" ]; then
  run git config --global user.email "$TARGET_GIT_EMAIL"
  info "Configured git user.email"
else
  note "git user.email left unset"
fi

# ── 11. Default shell ─────────────────────────────────────────────────────────
step "Setting zsh as default shell"
CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
if [[ "$CURRENT_SHELL" == *"zsh"* ]]; then
  info "zsh is already the default shell"
else
  run chsh -s "$(which zsh)"
  info "Default shell set to zsh (restart terminal to apply)"
fi

# ── 12. GitHub CLI auth ───────────────────────────────────────────────────────
step "GitHub CLI authentication"
if gh auth status &>/dev/null 2>&1; then
  info "gh is already authenticated"
else
  note "gh is not authenticated."
  if ! $DRY_RUN; then
    read -rp "  Authenticate with GitHub now? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      gh auth login
    else
      note "Skipped. Run 'gh auth login' later."
    fi
  fi
fi

# ── 13. Initialise sync timestamp ────────────────────────────────────────────
step "Initialising sync timestamp"
run bash -c "date +%s > \"$SCRIPT_DIR/.last_sync.local\""
info ".last_sync.local created — first auto-sync will run in 15 days"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo -e "  ${GREEN}Setup complete!${NC}"
echo ""
echo "  Next steps:"
echo "   • Restart your terminal (or run: exec zsh)"
echo "   • Run check.sh to verify everything"
echo "   • If gh isn't authed yet: gh auth login"
echo "   • Run claude or codex to verify the AI CLIs respond"
echo "========================================"
echo ""
