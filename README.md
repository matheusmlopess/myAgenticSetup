# WSL Setup

Personal WSL2 environment bootstrap for Ubuntu. Installs tools, copies dotfiles, and sets up shell — from zero to productive in one command.

Also includes a **Claude Code agent** (`CLAUDE.md`) that guides the setup interactively when you don't want to run blind scripts.

---

## Quick Start

```bash
git clone https://github.com/matheusmlopess/myAgenticSetup ~/repo/wsl_setup
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
| AI tools       | Claude CLI, Codex CLI                             |
| Dev tools      | git, gh (GitHub CLI), make, gcc, build-essential, pipx |
| Utilities      | curl, wget, jq, unzip, htop                       |

## What Gets Configured

- **Dotfiles** — `.zshrc`, `.bashrc`, `.gitconfig`, `.npmrc` copied to `~/`
- **Git identity** — restored from existing global config or prompted during setup
- **GitHub CLI** — credential helper wired up (prompts for `gh auth login`)
- **Default shell** — set to zsh via `chsh`
- **Startup reminders** — zsh warns when sync is due or the repo is behind `origin/master`

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

Validates local `master` against `origin/master`, then copies current non-sensitive dotfiles and a snapshot of installed packages into the repo. When there is a real snapshot change, `sync.sh` creates a fresh sync branch, commits there, pushes the branch, and opens a PR if `gh` is available and authenticated. If local `master` is behind or diverged, if tracked snapshot files already have local edits, if the worktree has unrelated changes, or if a secret-like value is detected in the managed files, sync stops instead of publishing.

```bash
bash sync.sh                        # sync, branch, push, and try to open a PR
bash sync.sh --no-pr                # sync and push a branch without opening a PR
bash sync.sh --branch-name env/wsl  # use a custom branch name
bash sync.sh --dry-run              # preview what would happen, no changes made
```

Two mechanisms keep sync visible even if WSL was off on the scheduled day:

1. **Cron job** — fires every 15 days at 9am if WSL is on:
   ```
   0 9 */15 * * /bin/bash ~/repo/wsl_setup/sync.sh >> ~/repo/wsl_setup/sync.log 2>&1
   ```

2. **Terminal startup reminder** — every time you open a terminal, `.zshrc` reads `.last_sync.local` if present and falls back to the tracked `.last_sync` baseline. It reminds you to run sync manually if 15+ days have passed, and warns when the local repo is behind `origin/master`. This catches the case where WSL was off when cron was supposed to fire and also nudges you to update before syncing.

`.last_sync.local` is machine-local and is refreshed after successful sync runs or no-op runs. The tracked `.last_sync` remains only as a fallback baseline for fresh clones. This avoids timestamp-only merge churn between environments.

To install the cron job on a new machine after cloning:

```bash
(crontab -l 2>/dev/null; echo "0 9 */15 * * /bin/bash ~/repo/wsl_setup/sync.sh >> ~/repo/wsl_setup/sync.log 2>&1") | crontab -
```

Sync history is logged to `sync.log`.

Recommended multi-environment strategy:

1. Keep `master` as the reviewed integration branch.
2. Run `sync.sh` from a clean local `master`.
3. Let `sync.sh` create a fresh branch and PR for that environment snapshot.
4. Review and merge manually.
5. Keep script/template changes in separate PRs from environment snapshot PRs.

---

### `check.sh` — Audit current state

Run this anytime to see what's installed, missing, or misconfigured. It also checks repo sync status against `origin/master`, warns about local snapshot drift for dotfiles, and flags when the current package snapshot differs from `packages.txt`.

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

### Overall lifecycle

```text
                    +----------------------+
                    |   Fresh clone / use  |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    |      setup.sh        |
                    | install + configure  |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    |      check.sh        |
                    | audit current state  |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    |     normal usage     |
                    | open terminal / work |
                    +----------+-----------+
                               |
                  +------------+-------------+
                  |                          |
                  v                          v
        +-------------------+      +-------------------+
        | sync reminder in  |      | manual sync via   |
        | dotfiles/.zshrc   |      | sync.sh           |
        +---------+---------+      +---------+---------+
                  |                          |
                  +------------+-------------+
                               |
                               v
                    +----------------------+
                    |      sync.sh         |
                    | validate, snapshot,  |
                    | branch, PR           |
                    +----------------------+
```

### `setup.sh`

```text
start
  |
  v
resolve SCRIPT_DIR
  |
  v
pre-flight: remove stale Chromium PPAs if present
  |
  v
install APT packages from packages.txt
  |
  v
install Chromium (WSL-safe: PPA on focal/jammy, skip on noble+)
  |
  v
install gh if missing
  |
  v
install Node.js if missing
  |
  v
install NVM if missing
  |
  v
install Oh My Zsh if missing
  |
  v
install global npm packages from npm-globals.txt
  |
  v
install Claude CLI via curl
  |
  v
install Codex CLI via npm
  |
  v
install Python tools from python-globals.txt
  |
  v
copy tracked dotfiles/templates -> ~/
  |
  v
backup existing home dotfiles before overwrite
  |
  v
restore or prompt for git identity
  |
  v
set default shell to zsh
  |
  v
optionally run gh auth login
  |
  v
initialize .last_sync.local
  |
  v
done
```

### `check.sh`

```text
start
  |
  v
resolve SCRIPT_DIR
  |
  v
repo sync checks
  |
  +--> git fetch origin master
  |
  +--> check if managed repo files have local edits
  |
  +--> compare HEAD vs origin/master
  |      - up to date
  |      - behind
  |      - ahead
  |      - diverged
  |
  v
check installed APT packages against packages.txt
  |      (chromium-browser skipped on Ubuntu 24.04+)
  |
  v
check NVM exists
  |
  v
check Oh My Zsh exists
  |
  v
check home dotfiles exist
  |
  v
check snapshot drift
  |
  +--> compare ~/.zshrc vs dotfiles/.zshrc
  +--> compare ~/.bashrc vs dotfiles/.bashrc
  +--> compare generated package snapshot vs packages.txt
  |
  v
check git user.name / user.email
  |
  v
check gh auth
  |
  v
check default shell
  |
  v
check npm globals from npm-globals.txt
  |
  v
check Claude CLI and Codex CLI
  |
  v
check Python tools from python-globals.txt
  |
  v
print summary
```

### `python-globals.txt` — Security audit toolchain

Tracks Python CLI tools installed with `pipx`. `setup.sh` installs them and `check.sh` verifies them so the security audit workflow has the expected tooling available.

Current tools:
- `bandit`
- `pip-audit`
- `safety`

### `sync.sh`

```text
start
  |
  v
resolve SCRIPT_DIR
  |
  v
validate repo state
  |
  +--> ensure dotfiles/ and packages.txt have no local uncommitted edits
  |
  +--> git fetch origin master
  |
  +--> ensure worktree is on master branch with no unrelated edits
  |
  +--> compare HEAD vs origin/master
         - if behind: git pull --ff-only, then continue
         - if ahead: abort
         - if diverged: abort
         - if up to date: continue
  |
  v
sync dotfiles
  |
  +--> for each managed non-sensitive dotfile:
  |      compare ~/file vs repo dotfiles/file
  |      if different -> copy home file into repo snapshot
  |
  v
snapshot packages
  |
  +--> generate current installed package list
  +--> compare with packages.txt
  +--> if different -> overwrite packages.txt
  |
  v
publish phase
  |
  +--> run secret scan gate
  |
  +--> if dotfiles/packages changed:
  |      create fresh sync branch
  |      update .last_sync.local
  |      git add managed snapshots
  |      git commit
  |      git push origin <sync-branch>
  |      gh pr create (when available)
  |
  +--> else:
         update .last_sync.local only
         no commit
         no push
  |
  v
done
```

### Sync reminder in `.zshrc`

```text
new shell starts
  |
  v
run _wsl_sync_check()
  |
  +--> read .last_sync.local
  +--> if missing, fall back to tracked .last_sync
  +--> compute now - last_sync
  +--> if < 15 days: do nothing
  +--> if >= 15 days:
          print reminder to run sync.sh manually
  |
  +--> fetch origin/master
  +--> if local repo is behind:
          print update suggestion
  +--> if local repo diverged:
          print review warning
  |
  v
continue normal shell startup
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

Stored in `dotfiles/` and deployed to `~/` by `setup.sh`. Any existing file is backed up to `~/.<file>.bak.<timestamp>` before being overwritten. Sensitive user-specific values are no longer tracked directly; setup uses templates for those files and configures Git identity separately.

| File         | Purpose                                          |
|--------------|--------------------------------------------------|
| `.zshrc`     | Oh My Zsh config, theme, plugins, aliases        |
| `.bashrc`    | NVM init, PATH, auto-launches zsh on login       |
| `.gitconfig.template` | GitHub CLI credential helper + placeholders |
| `.npmrc.template`     | baseline npm config                          |

`.last_sync.local` is the machine-local Unix timestamp used by the sync reminder. The tracked `.last_sync` remains in the repo only as a fallback baseline for fresh clones. `sync.sh` refreshes `.last_sync.local` on successful runs but does not commit it, which avoids timestamp-only conflicts across environments.

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
