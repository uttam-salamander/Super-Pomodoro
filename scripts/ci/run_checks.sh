#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---full}"

if [[ "$MODE" != "--fast" && "$MODE" != "--full" && "$MODE" != "--ci" ]]; then
  echo "Usage: $0 [--fast|--full|--ci]"
  exit 1
fi

run_rust_checks() {
  if [[ ! -f "src-tauri/Cargo.toml" ]]; then
    echo "[checks] No Rust backend found at src-tauri/Cargo.toml, skipping Rust checks."
    return
  fi

  echo "[checks] Rust: cargo fmt --check"
  cargo fmt --all --check --manifest-path src-tauri/Cargo.toml

  echo "[checks] Rust: cargo clippy"
  cargo clippy --manifest-path src-tauri/Cargo.toml --workspace --all-targets --all-features -- -D warnings

  if [[ "$MODE" == "--full" || "$MODE" == "--ci" ]]; then
    echo "[checks] Rust: cargo test"
    cargo test --manifest-path src-tauri/Cargo.toml --workspace --all-features
  fi
}

run_frontend_checks() {
  if [[ ! -f "package.json" ]]; then
    echo "[checks] No frontend package.json found, skipping frontend checks."
    return
  fi

  if [[ "$MODE" == "--ci" ]]; then
    if [[ -f "package-lock.json" ]]; then
      echo "[checks] Frontend: npm ci"
      npm ci
    else
      echo "[checks] package-lock.json is required for CI."
      exit 1
    fi
  elif [[ ! -d "node_modules" ]]; then
    echo "[checks] node_modules is missing. Run npm install, or rely on CI."
    return
  fi

  echo "[checks] Frontend: lint"
  npm run lint --if-present

  if [[ "$MODE" == "--full" || "$MODE" == "--ci" ]]; then
    echo "[checks] Frontend: test"
    npm run test --if-present

    echo "[checks] Frontend: build"
    npm run build --if-present
  fi
}

echo "[checks] Starting checks in mode: $MODE"
run_rust_checks
run_frontend_checks
echo "[checks] Completed."
