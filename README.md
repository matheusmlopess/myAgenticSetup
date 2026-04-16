# WSL Setup

Personal WSL2 environment bootstrap for Ubuntu. Installs tools, copies dotfiles, and sets up shell — from zero to productive in one command.

Also includes a **Claude Code agent** (`CLAUDE.md`) that guides the setup interactively when you don't want to run blind scripts.

---

## Quick Start

```bash
git clone https://github.com/matheusmlopess/myAgenticSetup
cd myAgenticSetup
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
| AI tools       | Claude CLI, Codex CLI                             |
| Dev tools      | git, gh (GitHub CLI), make, gcc, build-essential, pipx |
| Utilities      | curl, wget, jq, unzip, htop                       |

## What Gets Configured

- **Dotfiles** — `.zshrc`, `.bashrc`, `.gitconfig`, `.npmrc` copied to `~/`
- **Git identity** — restored from existing global config or prompted during setup
- **GitHub CLI** — credential helper wired up (prompts for `gh auth login`)
- **Default shell** — set to zsh via `chsh`
- **Runtime helpers** — `~/.config/wsl-setup/config.sh` plus `wsl-sync`, `wsl-check`, and `wsl-verify`
- **Startup reminders** — zsh warns when sync is due without assuming a fixed clone path

---

## Scripts

### `setup.sh` — Full bootstrap

Installs everything from scratch. Safe to re-run — skips anything already installed, backs up existing dotfiles before overwriting.

```bash
bash setup.sh           # normal run
bash setup.sh --dry-run # preview what would happen, no changes made
```

CLI install commands used by setup:

```bash
curl -fsSL https://claude.ai/install.sh | bash
npm install -g @openai/codex
```

### `sync.sh` — Snapshot, branch, and open a PR

Validates local `master` against `origin/master`, then copies current non-sensitive dotfiles into the repo when the local workstation is ahead of the tracked snapshot. It also reads the current installed package state and merges any missing local packages into `packages.txt` using an add-only union policy. Existing tracked package entries stay in place, and for pip packages the tracked version wins when the package name already exists. When there is a real dotfile or package-baseline change, `sync.sh` creates a fresh sync branch, commits there, pushes the branch, and opens a PR if `gh` is available and authenticated. If local `master` is behind or diverged, if tracked snapshot files already have local edits, if the worktree has unrelated changes, or if a secret-like value is detected in the managed files, sync stops instead of publishing.

```bash
bash sync.sh                        # sync, branch, push, and try to open a PR
bash sync.sh --no-pr                # sync and push a branch without opening a PR
bash sync.sh --branch-name env/wsl  # use a custom branch name
bash sync.sh --dry-run              # preview what would happen, no changes made
```

Before pushing changes to this repo, run:

```bash
bash verify.sh
```

Two mechanisms keep sync visible even if WSL was off on the scheduled day:

1. **Cron job** — fires every 15 days at 9am if WSL is on:
   ```
   0 9 */15 * * $HOME/.local/bin/wsl-sync >> $HOME/.config/wsl-setup/cron.log 2>&1
   ```

2. **Terminal startup reminder** — every time you open a terminal, `.zshrc` loads `~/.config/wsl-setup/config.sh`, reads `.last_sync.local` if present, and falls back to the tracked `.last_sync` baseline. It reminds you to run sync manually if 15+ days have passed. This catches the case where WSL was off when cron was supposed to fire.

`.last_sync.local` is machine-local and is refreshed after successful sync runs or no-op runs. The tracked `.last_sync` remains only as a fallback baseline for fresh clones. This avoids timestamp-only merge churn between environments.

To install the cron job on a new machine after cloning:

```bash
(crontab -l 2>/dev/null; echo '0 9 */15 * * $HOME/.local/bin/wsl-sync >> $HOME/.config/wsl-setup/cron.log 2>&1') | crontab -
```

Sync history is logged to `sync.log`.

`verify.sh` is the local pre-push gate. It runs shell parsing checks for the main scripts and then executes the full temp-fixture scenario suite in `tests/run.sh`.

Recommended multi-environment strategy:

1. Keep `master` as the reviewed integration branch.
2. Run `sync.sh` from a clean local `master`.
3. Let `sync.sh` create a fresh branch and PR for local dotfile snapshot changes and missing package additions.
4. Treat `packages.txt` as a monotonic shared baseline: sync adds missing local packages but does not remove tracked ones.
5. Review and merge manually.
6. Keep script/template changes in separate PRs from environment snapshot PRs.

---

### `check.sh` — Audit current state

Run this anytime to see what's installed, missing, or misconfigured. It also checks repo sync status against `origin/master`, warns when local dotfiles are ahead of the tracked snapshot, and flags when the local machine has package additions missing from the tracked `packages.txt` baseline.

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

## Workflow

### Daily Flow

```text
┌──────────────┐
│ fresh clone  │
└──────┬───────┘
       │
       v
┌──────────────┐
│  setup.sh    │  install + configure
└──────┬───────┘
       │
       v
┌──────────────┐
│  check.sh    │  audit local state
└──────┬───────┘
       │
       v
┌──────────────┐
│ normal usage │
└───┬─────┬────┘
    │     │
    │     └───────────────┐
    v                     v
┌──────────────┐   ┌──────────────┐
│ zsh reminder │   │   sync.sh    │
│ due / behind │   │ sync + PR    │
└──────┬───────┘   └──────┬───────┘
       │                  │
       └────────┬─────────┘
                v
          ┌──────────────┐
          │  verify.sh   │
          │ before push  │
          └──────────────┘
```

### `setup.sh`

Installs APT packages from `packages-desired.txt`, sets up shell/tooling, copies dotfiles, and initializes local sync state.

### `check.sh`

Audits repo sync status, package/tool installation, local dotfile drift, and package additions missing from `packages.txt`.

### `python-globals.txt` — Security audit toolchain

Tracks Python CLI tools installed with `pipx`. `setup.sh` installs them and `check.sh` verifies them so the security audit workflow has the expected tooling available.

Current tools:
- `bandit`
- `pip-audit`
- `safety`

### `sync.sh`

```text
┌──────────────────────────────┐
│ validate repo + branch state │
└──────────────┬───────────────┘
               │
               v
┌──────────────────────────────┐
│ sync ~/.zshrc and ~/.bashrc  │
│ into repo dotfile snapshots  │
└──────────────┬───────────────┘
               │
               v
┌──────────────────────────────┐
│ read local package state     │
│ merge missing entries into   │
│ packages.txt                 │
│ keep tracked entries sticky  │
│ keep tracked pip versions    │
└──────────────┬───────────────┘
               │
               v
        ┌───────────────┐
        │ changes found?│
        └──────┬────────┘
               │
      ┌────────┴────────┐
      │                 │
      v                 v
┌──────────────┐  ┌──────────────┐
│ create sync  │  │ refresh      │
│ branch + PR  │  │ .last_sync   │
│ stage files  │  │ no commit    │
└──────────────┘  └──────────────┘
```

### Sync reminder in `.zshrc`

Runs on shell startup, loads `~/.config/wsl-setup/config.sh`, checks `.last_sync.local` with fallback to tracked `.last_sync`, and warns when sync is due.

---

## Claude Code Agent (Interactive Mode)

If you have [Claude Code](https://github.com/anthropics/claude-code) installed, you can use it to guide the setup interactively instead of running scripts manually.

```bash
cd myAgenticSetup
claude
```

Claude will read `CLAUDE.md`, run `check.sh` automatically, explain what's missing, and walk you through fixing everything — including interactive steps like GitHub authentication.

---

## Dotfiles

Stored in `dotfiles/` and deployed to `~/` by `setup.sh`. Any existing file is backed up to `~/.<file>.bak.<timestamp>` before being overwritten. Sensitive user-specific values are no longer tracked directly; setup uses templates for those files and configures Git identity separately.

| File         | Purpose                                          |
|--------------|--------------------------------------------------|
| `.zshrc`     | Oh My Zsh config, theme, plugins, aliases        |
| `.bashrc`    | NVM init, PATH, auto-launches zsh on login       |
| `.gitconfig.template` | GitHub CLI credential helper + placeholders |
| `.npmrc.template`     | baseline npm config                          |

`.last_sync.local` is the machine-local Unix timestamp used by the sync reminder. The tracked `.last_sync` remains in the repo only as a fallback baseline for fresh clones. `sync.sh` refreshes `.last_sync.local` on successful runs but does not commit it, which avoids timestamp-only conflicts across environments. `~/.config/wsl-setup/config.sh` records the current repo location so the reminder and helper commands stay valid even when the repo is not cloned under `~/repo/wsl_setup`.

---

## After Setup

```bash
# Verify everything is in order
bash check.sh

# Authenticate GitHub CLI (if not done during setup)
gh auth login

# Verify AI CLIs
claude --version
codex --version

# Reload shell
exec zsh
```
