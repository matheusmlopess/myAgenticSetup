# WSL Setup

Personal WSL2 environment bootstrap for Ubuntu. Installs tools, copies dotfiles, and sets up shell — from zero to productive in one command.

Also includes a **Claude Code agent** (`CLAUDE.md`) that guides the setup interactively when you don't want to run blind scripts.

---

## Quick Start

```bash
git clone https://github.com/matheusmlopess/wsl_setup ~/repo/wsl_setup
cd ~/repo/wsl_setup
bash setup.sh
```

Then restart your terminal:

```bash
exec zsh
```

---

## What Gets Installed

| Category       | Tools                                              |
|----------------|----------------------------------------------------|
| Shell          | zsh, Oh My Zsh (random theme), git + git-prompt plugins |
| Version mgmt   | NVM                                                |
| Runtime        | Node.js 20.x, npm, python3, pip, venv             |
| Dev tools      | git, gh (GitHub CLI), make, gcc, build-essential  |
| Utilities      | curl, wget, jq, unzip, htop                       |

## What Gets Configured

- **Dotfiles** — `.zshrc`, `.bashrc`, `.gitconfig`, `.npmrc` copied to `~/`
- **Git identity** — name and email pre-configured
- **GitHub CLI** — credential helper wired up (prompts for `gh auth login`)
- **Default shell** — set to zsh via `chsh`

---

## Scripts

### `setup.sh` — Full bootstrap

Installs everything from scratch. Safe to re-run — skips anything already installed, backs up existing dotfiles before overwriting.

```bash
bash setup.sh           # normal run
bash setup.sh --dry-run # preview what would happen, no changes made
```

### `check.sh` — Audit current state

Run this anytime to see what's installed, missing, or misconfigured. Useful to verify after setup or to quickly check a machine you haven't touched in a while.

```bash
bash check.sh
```

Example output:

```
── CLI Tools ───────────────────────────
  [OK]    git
  [OK]    zsh
  [MISS]  jq — not found

── GitHub CLI Auth ─────────────────────
  [WARN]  gh is installed but NOT authenticated — run: gh auth login

── Default Shell ───────────────────────
  [OK]    Default shell is zsh
```

---

## Claude Code Agent (Interactive Mode)

If you have [Claude Code](https://github.com/anthropics/claude-code) installed, you can use it to guide the setup interactively instead of running scripts manually.

```bash
cd ~/repo/wsl_setup
claude
```

Claude will read `CLAUDE.md`, run `check.sh` automatically, explain what's missing, and walk you through fixing everything — including interactive steps like GitHub authentication.

---

## Dotfiles

Stored in `dotfiles/` and deployed to `~/` by `setup.sh`. Any existing file is backed up to `~/.<file>.bak.<timestamp>` before being overwritten.

| File         | Purpose                                          |
|--------------|--------------------------------------------------|
| `.zshrc`     | Oh My Zsh config, theme, plugins, aliases        |
| `.bashrc`    | NVM init, PATH, auto-launches zsh on login       |
| `.gitconfig` | Git identity + GitHub CLI credential helper      |
| `.npmrc`     | `package-lock=false`                             |

---

## After Setup

```bash
# Verify everything is in order
bash check.sh

# Authenticate GitHub CLI (if not done during setup)
gh auth login

# Reload shell
exec zsh
```
