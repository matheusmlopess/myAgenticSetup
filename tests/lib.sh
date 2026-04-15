#!/usr/bin/env bash

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
PATH_ORIG="$PATH"
TEST_USER="${USER:-tester}"

fail() {
  echo "ASSERTION FAILED: $*" >&2
  return 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    fail "expected output to contain: $needle"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    fail "expected output not to contain: $needle"
  fi
}

assert_file_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "expected $file to contain: $needle"
}

assert_file_not_contains() {
  local file="$1"
  local needle="$2"
  if grep -Fq "$needle" "$file"; then
    fail "expected $file not to contain: $needle"
  fi
}

assert_branch_prefix() {
  local prefix="$1"
  local branch
  branch="$(git -C "$FIXTURE_REPO" branch --show-current)"
  [[ "$branch" == "$prefix"* ]] || fail "expected branch prefix $prefix, got $branch"
}

capture_in_repo() {
  local tmp
  tmp="$(mktemp)"
  if (
    cd "$FIXTURE_REPO"
    HOME="$FIXTURE_HOME" PATH="$FIXTURE_BIN:$PATH_ORIG" USER="$TEST_USER" "$@"
  ) >"$tmp" 2>&1; then
    CMD_STATUS=0
  else
    CMD_STATUS=$?
  fi
  CMD_OUTPUT="$(cat "$tmp")"
  rm -f "$tmp"
}

run_sync_capture() {
  capture_in_repo bash ./sync.sh "$@"
}

run_check_capture() {
  capture_in_repo bash ./check.sh
}

section_entries() {
  local source_file="$1"
  local section_header="$2"

  awk -v target="$section_header" '
    $0 == target { in_section=1; next }
    /^## / && in_section { exit }
    in_section && NF { print }
  ' "$source_file"
}

write_package_state() {
  local apt_lines="$1"
  local npm_lines="$2"
  local pip_lines="$3"
  local line

  printf '%s\n' "$apt_lines" > "$FIXTURE_STATE_DIR/apt.txt"
  {
    echo "/mock/global"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      echo "/mock/global/lib/node_modules/$line"
    done <<< "$npm_lines"
  } > "$FIXTURE_STATE_DIR/npm.txt"
  printf '%s\n' "$pip_lines" > "$FIXTURE_STATE_DIR/pip.txt"
}

set_package_state_from_tracked_baseline() {
  write_package_state \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## APT (manually installed)")" \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## npm global packages")" \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## pip3 global packages")"
}

setup_fake_home() {
  mkdir -p "$FIXTURE_HOME/.oh-my-zsh" "$FIXTURE_HOME/.nvm"
  : > "$FIXTURE_HOME/.nvm/nvm.sh"
  cp "$FIXTURE_REPO/dotfiles/.zshrc" "$FIXTURE_HOME/.zshrc"
  cp "$FIXTURE_REPO/dotfiles/.bashrc" "$FIXTURE_HOME/.bashrc"
  cp "$FIXTURE_REPO/dotfiles/.gitconfig.template" "$FIXTURE_HOME/.gitconfig"
  cp "$FIXTURE_REPO/dotfiles/.npmrc.template" "$FIXTURE_HOME/.npmrc"
  HOME="$FIXTURE_HOME" git config --global user.name "Test User"
  HOME="$FIXTURE_HOME" git config --global user.email "test@example.com"
}

create_stub_commands() {
  mkdir -p "$FIXTURE_BIN" "$FIXTURE_STATE_DIR"

  cat > "$FIXTURE_BIN/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  auth)
    [[ "${2:-}" == "status" ]] && exit 0
    ;;
  pr)
    if [[ "${2:-}" == "create" ]]; then
      echo "https://example.test/pr/1"
      exit 0
    fi
    ;;
esac
exit 0
EOF

  cat > "$FIXTURE_BIN/getent" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "passwd" ]]; then
  echo "\${2:-$TEST_USER}:x:1000:1000::${FIXTURE_HOME}:/usr/bin/zsh"
  exit 0
fi
exit 1
EOF

  cat > "$FIXTURE_BIN/dpkg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-s" ]]; then
  exit 0
fi
exec /usr/bin/dpkg "$@"
EOF

  cat > "$FIXTURE_BIN/apt-mark" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "showmanual" ]]; then
  cat "${FIXTURE_STATE_DIR}/apt.txt"
  exit 0
fi
exit 1
EOF

  cat > "$FIXTURE_BIN/npm" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "list" && "\${2:-}" == "-g" ]]; then
  cat "${FIXTURE_STATE_DIR}/npm.txt"
  exit 0
fi
exit 1
EOF

  cat > "$FIXTURE_BIN/pip3" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "list" ]]; then
  cat "${FIXTURE_STATE_DIR}/pip.txt"
  exit 0
fi
exit 1
EOF

  for cmd in claude codex bandit pip-audit safety; do
    cat > "$FIXTURE_BIN/$cmd" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  done

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ || -z "${line// }" ]] && continue
    local cmd="${line##*:}"
    [[ "$cmd" == "$line" ]] && cmd="$line"
    cat > "$FIXTURE_BIN/$cmd" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  done < "$REPO_ROOT/npm-globals.txt"

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ || -z "${line// }" ]] && continue
    local cmd="${line##*:}"
    [[ "$cmd" == "$line" ]] && cmd="$line"
    cat > "$FIXTURE_BIN/$cmd" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  done < "$REPO_ROOT/python-globals.txt"

  chmod +x "$FIXTURE_BIN"/*
}

copy_repo_tree() {
  mkdir -p "$FIXTURE_SEED/dotfiles" "$FIXTURE_SEED/docs"
  cp "$REPO_ROOT"/sync.sh "$FIXTURE_SEED/"
  cp "$REPO_ROOT"/check.sh "$FIXTURE_SEED/"
  cp "$REPO_ROOT"/setup.sh "$FIXTURE_SEED/"
  cp "$REPO_ROOT"/teardown.sh "$FIXTURE_SEED/"
  cp "$REPO_ROOT"/packages.txt "$FIXTURE_SEED/"
  cp "$REPO_ROOT"/packages-desired.txt "$FIXTURE_SEED/"
  cp "$REPO_ROOT"/npm-globals.txt "$FIXTURE_SEED/"
  cp "$REPO_ROOT"/python-globals.txt "$FIXTURE_SEED/"
  cp "$REPO_ROOT"/README.md "$FIXTURE_SEED/"
  cp "$REPO_ROOT"/CLAUDE.md "$FIXTURE_SEED/"
  cp "$REPO_ROOT"/.gitignore "$FIXTURE_SEED/"
  cp "$REPO_ROOT"/.last_sync "$FIXTURE_SEED/"
  cp -R "$REPO_ROOT/dotfiles/." "$FIXTURE_SEED/dotfiles/"
  if [[ -d "$REPO_ROOT/docs" ]]; then
    cp -R "$REPO_ROOT/docs/." "$FIXTURE_SEED/docs/"
  fi
}

create_fixture_repo() {
  FIXTURE_ROOT="$(mktemp -d)"
  FIXTURE_ORIGIN="$FIXTURE_ROOT/origin.git"
  FIXTURE_SEED="$FIXTURE_ROOT/seed"
  FIXTURE_REPO="$FIXTURE_ROOT/repo"
  FIXTURE_HOME="$FIXTURE_ROOT/home"
  FIXTURE_BIN="$FIXTURE_ROOT/bin"
  FIXTURE_STATE_DIR="$FIXTURE_ROOT/state"

  export FIXTURE_ROOT FIXTURE_ORIGIN FIXTURE_SEED FIXTURE_REPO FIXTURE_HOME FIXTURE_BIN FIXTURE_STATE_DIR

  create_stub_commands
  copy_repo_tree

  git init --bare "$FIXTURE_ORIGIN" >/dev/null
  git init -b master "$FIXTURE_SEED" >/dev/null
  git -C "$FIXTURE_SEED" config user.name "Test User"
  git -C "$FIXTURE_SEED" config user.email "test@example.com"
  git -C "$FIXTURE_SEED" add .
  git -C "$FIXTURE_SEED" commit -m "seed" >/dev/null
  git -C "$FIXTURE_SEED" remote add origin "$FIXTURE_ORIGIN"
  git -C "$FIXTURE_SEED" push -u origin master >/dev/null

  git clone "$FIXTURE_ORIGIN" "$FIXTURE_REPO" >/dev/null
  git -C "$FIXTURE_REPO" config user.name "Test User"
  git -C "$FIXTURE_REPO" config user.email "test@example.com"

  setup_fake_home
  set_package_state_from_tracked_baseline
}

create_remote_clone() {
  local remote_clone="$FIXTURE_ROOT/remote-$(date +%s%N)"
  git clone "$FIXTURE_ORIGIN" "$remote_clone" >/dev/null
  git -C "$remote_clone" config user.name "Remote User"
  git -C "$remote_clone" config user.email "remote@example.com"
  printf '%s\n' "$remote_clone"
}

append_unique_entry_to_section() {
  local file="$1"
  local section="$2"
  local entry="$3"

  python3 - "$file" "$section" "$entry" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
section = sys.argv[2]
entry = sys.argv[3]
text = path.read_text().splitlines()

start = None
end = len(text)
for i, line in enumerate(text):
    if line == section:
        start = i + 1
        continue
    if start is not None and line.startswith("## "):
        end = i
        break

if start is None:
    if text and text[-1] != "":
        text.append("")
    text.extend([section, entry])
else:
    body = [line for line in text[start:end] if line]
    if entry not in body:
        body.append(entry)
    body = sorted(body, key=str.lower)
    text = text[:start] + body + text[end:]

path.write_text("\n".join(text) + "\n")
PY
}

run_scenario() {
  local name="$1"
  shift
  echo "==> $name"
  "$@"
}
