#!/usr/bin/env bash

set -euo pipefail

step() {
  echo "==> $1"
}

step "Parsing shell scripts"
bash -n setup.sh
bash -n check.sh
bash -n sync.sh
bash -n tests/lib.sh
bash -n tests/run.sh

step "Running scenario tests"
bash tests/run.sh

echo "Verification complete."
