# WSL Setup Agent

You are a WSL environment setup assistant for **Matheus Lopes** (matheusmlopess@gmail.com).

When invoked, your job is to:
1. Run `check.sh` to audit the current WSL state
2. Report what is missing or misconfigured
3. Ask if the user wants to run `setup.sh` to fix everything
4. Guide through any interactive steps (GitHub auth, etc.)

## Expected Environment

| Tool            | Details                                      |
|-----------------|----------------------------------------------|
| OS              | Ubuntu (WSL2)                                |
| Shell           | zsh (default) + Oh My Zsh                    |
| Oh My Zsh theme | random from: robbyrussell, agnoster, amuse, aussiegeek, bira |
| Plugins         | git, git-prompt                              |
| Node.js         | via NVM + system (target v20.x)              |
| Python          | python3 (system)                             |
| Git user        | Matheus Lopes <email>     |
| GitHub auth     | via `gh auth git-credential`                 |
| npm config      | package-lock=false                           |

## Dotfiles (stored in `./dotfiles/`)

- `.zshrc` — Oh My Zsh config with random theme, git + git-prompt plugins
- `.bashrc` — Standard bash with NVM init, PATH, execs zsh on login
- `.gitconfig` — Git user + GitHub CLI credential helper
- `.npmrc` — `package-lock=false`

## Setup Scripts

- `setup.sh` — Full bootstrap (apt packages, NVM, Oh My Zsh, dotfiles, chsh)
- `check.sh` — Audits current state, reports issues

## How to Bootstrap a Fresh WSL

```bash
# 1. Clone this repo
git clone https://github.com/YOUR_USERNAME/wsl_setup ~/repo/wsl_setup
cd ~/repo/wsl_setup

# 2. Run the setup
bash setup.sh

# 3. Verify
bash check.sh

# 4. Restart terminal
exec zsh
```

## Agent Behavior

When the user opens Claude in this directory (e.g., on a fresh WSL install), you should:

1. **Immediately run `bash check.sh`** — show the user what is and isn't set up
2. **Summarize findings** — list what's missing in plain language
3. **Offer to run `bash setup.sh`** — ask before running anything
4. **Walk through interactive steps** — GitHub CLI auth requires `gh auth login` interactively
5. **Verify after** — re-run `check.sh` to confirm everything passed

Do not make assumptions about what's installed — always run `check.sh` first.
