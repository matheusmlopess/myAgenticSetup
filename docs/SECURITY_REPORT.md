### 2026-04-01 — Security Audit: repository root (`/home/magooo/repo/wsl_setup`)

**Files audited:** 12
**Total findings:** 4 (Critical: 0 | High: 2 | Medium: 0 | Low: 1 | Info: 1)

---

#### [HIGH] — Automatic sync can publish secrets from home directory dotfiles to GitHub

**File:** `sync.sh` (line 134)
**Description:** The sync workflow copies live files from `$HOME` into the repository and then pushes them to `origin/master` without any content inspection for secrets. This is especially risky for `.npmrc` and `.gitconfig`, which commonly contain auth tokens, private registry credentials, or machine-specific credential helpers. Because the repo is intended to be pushed to GitHub, any future secret added to one of those dotfiles can be exfiltrated automatically.
**Evidence:** `sync.sh` copies `.zshrc`, `.bashrc`, `.gitconfig`, and `.npmrc` from `$HOME` (`lines 134-155`) and then stages and pushes them with `git push origin master` (`lines 208-216`).
**Recommendation:** Remove secret-bearing files such as `.npmrc` and `.gitconfig` from the auto-sync set, or sanitize them before commit. Add a pre-push secret scan (for example `gitleaks` or `trufflehog`) and block the push on findings. Prefer explicit user approval before publishing dotfile changes.
**References:** OWASP A02 Cryptographic Failures, OWASP A09 Security Logging and Monitoring Failures, OWASP Secrets Management Cheat Sheet

---

#### [HIGH] — Terminal startup triggers unattended `git push` behavior

**File:** `dotfiles/.zshrc` (line 120)
**Description:** Opening a shell can automatically execute `sync.sh`, which performs network operations and may commit and push repository changes. This creates a non-interactive publication path tied to terminal startup rather than an intentional release step. In practice, that increases the chance of pushing sensitive local changes or manipulated config snapshots without review.
**Evidence:** `_wsl_sync_check()` in `dotfiles/.zshrc` runs `bash "$sync_script" >> "$log_file" 2>&1` when 15 days have elapsed (`lines 121-136`). `sync.sh` then commits and pushes if changes are detected (`lines 213-216`).
**Recommendation:** Remove auto-push behavior from shell startup. Limit startup behavior to a notification that sync is due, and require an explicit interactive command to commit and push. If automation is required, run only a dry-run diff from startup and require confirmation before any network write.
**References:** OWASP A04 Insecure Design

---

#### [LOW] — Tracked dotfile snapshot exposes personal email address

**File:** `dotfiles/.gitconfig` (line 3)
**Description:** The repository stores a real personal email address in a tracked config file. This is not a credential by itself, but it is unnecessary personal data exposure if the repository is shared publicly or broadly within an organization.
**Evidence:** `email =matheusmlopess@gmail.com`
**Recommendation:** Replace the committed identity with a placeholder template, environment-specific bootstrap step, or a documented post-setup manual configuration step. Keep personal identity values out of version-controlled dotfile snapshots.
**References:** OWASP A01 Broken Access Control (data exposure context), Principle of Least Exposure

---

#### [INFO] — Bootstrap process executes remote scripts directly without integrity verification

**File:** `setup.sh` (line 85)
**Description:** The setup flow downloads and executes remote installation scripts directly from network locations, including one path that executes with `sudo`. This is a common bootstrap shortcut, but it expands supply-chain risk because the host fully trusts live remote content at execution time.
**Evidence:** `curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -` (`line 85`), `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash` (`line 96`), and `sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"` (`line 106`).
**Recommendation:** Download installers to disk, verify signatures or pinned checksums, and then execute only verified artifacts. Prefer repository packages or version-pinned release assets where possible.
**References:** OWASP A08 Software and Data Integrity Failures

---

#### Summary & Recommendations

Overall risk is **high** because the design combines auto-executed sync logic with automatic Git pushes of user home-directory configuration files. The most important remediation is to stop publishing dotfiles from shell startup and to treat `.npmrc` and `.gitconfig` as potentially sensitive inputs unless they are sanitized first.

Additional audit notes:
- `bandit`, `pip-audit`, and `safety` were not installed in the environment.
- `npm audit --json` was not applicable because the repository has no `package.json`/lockfile-based Node project to audit.
- No hardcoded secrets or private keys were found in the audited repository files.
