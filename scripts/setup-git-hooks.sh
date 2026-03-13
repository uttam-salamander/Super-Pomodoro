#!/usr/bin/env bash
set -euo pipefail

git config core.hooksPath .githooks
chmod +x .githooks/pre-commit .githooks/pre-push scripts/ci/run_checks.sh

echo "Git hooks installed from .githooks/"
echo "Configured via: git config core.hooksPath .githooks"
