#!/usr/bin/env bash

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TESTS_DIR/lib.sh"

scenario_sync_no_changes() {
  create_fixture_repo
  run_sync_capture
  [[ "$CMD_STATUS" -eq 0 ]] || fail "sync.sh should succeed"
  assert_contains "$CMD_OUTPUT" "packages.txt baseline already covers local package state"
  assert_contains "$CMD_OUTPUT" "Nothing to commit — repo is up to date"
  assert_file_contains "$FIXTURE_HOME/.config/wsl-setup/config.sh" "$FIXTURE_REPO/sync.sh"
  [[ "$(git -C "$FIXTURE_REPO" branch --show-current)" == "master" ]] || fail "expected to remain on master"
}

scenario_sync_dotfiles_local_ahead() {
  create_fixture_repo
  echo "# local change" >> "$FIXTURE_HOME/.zshrc"
  run_sync_capture
  [[ "$CMD_STATUS" -eq 0 ]] || fail "sync.sh should succeed"
  assert_contains "$CMD_OUTPUT" ".zshrc local ahead of tracked snapshot — updating"
  assert_branch_prefix "sync/"
  assert_file_contains "$FIXTURE_REPO/dotfiles/.zshrc" "# local change"
}

scenario_sync_remote_behind_fast_forward() {
  create_fixture_repo
  remote_clone="$(create_remote_clone)"
  append_unique_entry_to_section "$remote_clone/packages.txt" "## APT (manually installed)" "remote-only-package"
  git -C "$remote_clone" add packages.txt
  git -C "$remote_clone" commit -m "remote package update" >/dev/null
  git -C "$remote_clone" push origin master >/dev/null

  run_sync_capture
  [[ "$CMD_STATUS" -eq 0 ]] || fail "sync.sh should succeed after fast-forward"
  assert_contains "$CMD_OUTPUT" "packages.txt baseline remote ahead of local master"
  assert_contains "$CMD_OUTPUT" "Pulled latest changes from origin/master"
  assert_file_contains "$FIXTURE_REPO/packages.txt" "remote-only-package"
}

scenario_sync_diverged_branch_aborts() {
  create_fixture_repo
  remote_clone="$(create_remote_clone)"
  append_unique_entry_to_section "$remote_clone/packages.txt" "## APT (manually installed)" "remote-diverged-package"
  git -C "$remote_clone" add packages.txt
  git -C "$remote_clone" commit -m "remote diverged" >/dev/null
  git -C "$remote_clone" push origin master >/dev/null

  echo "# local diverged change" >> "$FIXTURE_REPO/dotfiles/.bashrc"
  git -C "$FIXTURE_REPO" add dotfiles/.bashrc
  git -C "$FIXTURE_REPO" commit -m "local diverged" >/dev/null

  run_sync_capture
  [[ "$CMD_STATUS" -ne 0 ]] || fail "sync.sh should fail on divergence"
  assert_contains "$CMD_OUTPUT" "has diverged from origin/master"
}

scenario_sync_unrelated_worktree_aborts() {
  create_fixture_repo
  echo "temp" > "$FIXTURE_REPO/notes.tmp"
  run_sync_capture
  [[ "$CMD_STATUS" -ne 0 ]] || fail "sync.sh should fail with unrelated worktree changes"
  assert_contains "$CMD_OUTPUT" "Worktree must be clean before sync creates a branch"
}

scenario_packages_add_missing_apt() {
  create_fixture_repo
  current_apt="$(cat "$FIXTURE_STATE_DIR/apt.txt")"
  write_package_state "${current_apt}"$'\n'"new-apt-package" \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## npm global packages")" \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## pip3 global packages")"
  run_sync_capture
  [[ "$CMD_STATUS" -eq 0 ]] || fail "sync.sh should succeed"
  assert_branch_prefix "sync/"
  assert_file_contains "$FIXTURE_REPO/packages.txt" "new-apt-package"
}

scenario_packages_add_missing_npm() {
  create_fixture_repo
  write_package_state \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## APT (manually installed)")" \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## npm global packages")"$'\n'"new-npm-cli" \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## pip3 global packages")"
  run_sync_capture
  [[ "$CMD_STATUS" -eq 0 ]] || fail "sync.sh should succeed"
  assert_file_contains "$FIXTURE_REPO/packages.txt" "new-npm-cli"
}

scenario_packages_add_missing_pip() {
  create_fixture_repo
  write_package_state \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## APT (manually installed)")" \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## npm global packages")" \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## pip3 global packages")"$'\n'"newpip==1.2.3"
  run_sync_capture
  [[ "$CMD_STATUS" -eq 0 ]] || fail "sync.sh should succeed"
  assert_file_contains "$FIXTURE_REPO/packages.txt" "newpip==1.2.3"
}

scenario_packages_keep_tracked_if_local_missing() {
  create_fixture_repo
  write_package_state \
    "bash"$'\n'"zsh" \
    "codex" \
    "requests==2.31.0"
  run_sync_capture
  [[ "$CMD_STATUS" -eq 0 ]] || fail "sync.sh should succeed"
  assert_file_contains "$FIXTURE_REPO/packages.txt" "ansible"
  assert_file_contains "$FIXTURE_REPO/packages.txt" "mermaid-cli"
}

scenario_packages_keep_tracked_pip_version() {
  create_fixture_repo
  write_package_state \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## APT (manually installed)")" \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## npm global packages")" \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## pip3 global packages" | grep -vi '^requests==')"$'\n'"requests==9.9.9"
  run_sync_capture
  [[ "$CMD_STATUS" -eq 0 ]] || fail "sync.sh should succeed"
  assert_file_contains "$FIXTURE_REPO/packages.txt" "requests==2.31.0"
  assert_file_not_contains "$FIXTURE_REPO/packages.txt" "requests==9.9.9"
}

scenario_packages_package_only_change_creates_publishable_diff() {
  create_fixture_repo
  current_apt="$(cat "$FIXTURE_STATE_DIR/apt.txt")"
  write_package_state "${current_apt}"$'\n'"pkg-only-addition" \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## npm global packages")" \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## pip3 global packages")"
  run_sync_capture
  [[ "$CMD_STATUS" -eq 0 ]] || fail "sync.sh should succeed"
  assert_branch_prefix "sync/"
  assert_contains "$CMD_OUTPUT" "Local package state has additions missing from tracked packages.txt baseline"
  assert_file_contains "$FIXTURE_REPO/packages.txt" "pkg-only-addition"
}

scenario_check_packages_baseline_covers_local() {
  create_fixture_repo
  run_check_capture
  [[ "$CMD_STATUS" -eq 0 ]] || fail "check.sh should succeed"
  assert_contains "$CMD_OUTPUT" "packages.txt baseline covers local package state"
}

scenario_check_packages_local_additions_missing() {
  create_fixture_repo
  current_apt="$(cat "$FIXTURE_STATE_DIR/apt.txt")"
  write_package_state "${current_apt}"$'\n'"check-only-addition" \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## npm global packages")" \
    "$(section_entries "$FIXTURE_REPO/packages.txt" "## pip3 global packages")"
  run_check_capture
  [[ "$CMD_STATUS" -eq 0 ]] || fail "check.sh should complete"
  assert_contains "$CMD_OUTPUT" "Local package state has additions missing from tracked packages.txt baseline"
}

scenario_check_remote_packages_ahead() {
  create_fixture_repo
  remote_clone="$(create_remote_clone)"
  append_unique_entry_to_section "$remote_clone/packages.txt" "## npm global packages" "remote-npm-only"
  git -C "$remote_clone" add packages.txt
  git -C "$remote_clone" commit -m "remote package baseline" >/dev/null
  git -C "$remote_clone" push origin master >/dev/null
  run_check_capture
  [[ "$CMD_STATUS" -eq 0 ]] || fail "check.sh should complete"
  assert_contains "$CMD_OUTPUT" "packages.txt remote baseline changed"
  assert_contains "$CMD_OUTPUT" "Tracked packages baseline is behind origin/master"
}

scenario_check_dotfiles_ahead() {
  create_fixture_repo
  echo "# ahead" >> "$FIXTURE_HOME/.bashrc"
  run_check_capture
  [[ "$CMD_STATUS" -eq 0 ]] || fail "check.sh should complete"
  assert_contains "$CMD_OUTPUT" ".bashrc is ahead of tracked snapshot"
}

main() {
  run_scenario "sync_no_changes" scenario_sync_no_changes
  run_scenario "sync_dotfiles_local_ahead" scenario_sync_dotfiles_local_ahead
  run_scenario "sync_remote_behind_fast_forward" scenario_sync_remote_behind_fast_forward
  run_scenario "sync_diverged_branch_aborts" scenario_sync_diverged_branch_aborts
  run_scenario "sync_unrelated_worktree_aborts" scenario_sync_unrelated_worktree_aborts
  run_scenario "packages_add_missing_apt" scenario_packages_add_missing_apt
  run_scenario "packages_add_missing_npm" scenario_packages_add_missing_npm
  run_scenario "packages_add_missing_pip" scenario_packages_add_missing_pip
  run_scenario "packages_keep_tracked_if_local_missing" scenario_packages_keep_tracked_if_local_missing
  run_scenario "packages_keep_tracked_pip_version" scenario_packages_keep_tracked_pip_version
  run_scenario "packages_package_only_change_creates_publishable_diff" scenario_packages_package_only_change_creates_publishable_diff
  run_scenario "check_packages_baseline_covers_local" scenario_check_packages_baseline_covers_local
  run_scenario "check_packages_local_additions_missing" scenario_check_packages_local_additions_missing
  run_scenario "check_remote_packages_ahead" scenario_check_remote_packages_ahead
  run_scenario "check_dotfiles_ahead" scenario_check_dotfiles_ahead
  echo "All scenario tests passed."
}

main "$@"
