### 2026-04-01 — Security Audit: repository root (`/home/magooo/repo/wsl_setup`)

**Files audited:** 13
**Total findings:** 2 (Critical: 0 | High: 1 | Medium: 0 | Low: 0 | Info: 1)

---

#### [HIGH] — Vulnerable Python package versions are tracked in the environment snapshot

**File:** `packages.txt` (line 43)
**Description:** The tracked pip package snapshot contains multiple versions with known published vulnerabilities. This repository is explicitly intended to recreate the workstation state, so keeping vulnerable versions in the snapshot increases the chance that future machines inherit known issues. The `safety` scan reported 26 vulnerabilities across 11 packages in the tracked pip section.
**Evidence:** Representative vulnerable entries in `packages.txt` include `certifi==2023.11.17` (`line 47`), `Jinja2==3.1.2` (`line 59`), `pip==24.0` (`line 67`), `requests==2.31.0` (`line 77`), `setuptools==68.1.2` (`line 80`), `Twisted==24.3.0` (`line 82`), `urllib3==2.0.7` (`line 86`), and `wheel==0.42.0` (`line 88`). `safety check -r /tmp/wsl_setup_pip_requirements.txt` reported vulnerabilities affecting those packages, including CVE-2024-39689 (`certifi`), CVE-2024-34064 / CVE-2025-27516 (`Jinja2`), CVE-2024-35195 / CVE-2024-47081 (`requests`), CVE-2024-6345 / CVE-2025-47273 (`setuptools`), CVE-2024-41671 / CVE-2024-41810 (`Twisted`), multiple 2024-2026 advisories for `urllib3`, and CVE-2026-24049 (`wheel`).
**Recommendation:** Refresh the pip snapshot to patched versions before using it as a baseline. At minimum, review and upgrade the packages flagged by `safety`, regenerate `packages.txt`, and re-run the audit. If these packages are primarily OS-managed rather than intentionally installed, exclude them from the tracked pip snapshot so the repo only preserves packages you actually mean to reproduce.
**References:** OWASP A06 Vulnerable and Outdated Components

---

#### [INFO] — Bootstrap process executes remote scripts directly without integrity verification

**File:** `setup.sh` (line 98)
**Description:** The setup flow still downloads and executes remote installation scripts directly from network locations, including one path that executes with `sudo`. This remains a supply-chain hardening gap because the host trusts live remote content at execution time.
**Evidence:** `curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -` (`line 98`), `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash` (`line 109`), and `sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"` (`line 119`).
**Recommendation:** Download installers to disk, verify signatures or pinned checksums, and then execute only verified artifacts. Prefer repository packages or version-pinned release assets where possible.
**References:** OWASP A08 Software and Data Integrity Failures

---

#### Summary & Recommendations

Overall risk is **medium-to-high** because the repo no longer auto-publishes sensitive dotfiles, but it still preserves a Python package snapshot with multiple known vulnerable versions. The highest-priority remediation is to decide whether the pip section in `packages.txt` should be tracked at all; if yes, upgrade the flagged packages and regenerate the snapshot.

Additional audit notes:
- `bandit -r . -f json` completed successfully and reported no findings in the repository source files.
- `safety check -r /tmp/wsl_setup_pip_requirements.txt` completed successfully and reported 26 vulnerabilities across 11 packages from the tracked pip snapshot.
- `pip-audit -r /tmp/wsl_setup_pip_requirements.txt` could not fully resolve the snapshot because distro-specific packages such as `cloud-init==25.1.4` are not available from PyPI, so its results were incomplete.
- `npm audit --json` remains not applicable because the repository does not contain a `package.json`/lockfile-based Node project.
