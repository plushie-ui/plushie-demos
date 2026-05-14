#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LANGUAGE="${1:-all}"
SMOKE_TIMEOUT="${PACKAGE_SMOKE_TIMEOUT:-10}"
BUILD_PAYLOADS="${PACKAGE_SMOKE_BUILD:-0}"
RUN_ARTIFACTS="${PACKAGE_SMOKE_RUN_ARTIFACTS:-0}"
ARTIFACT_TIMEOUT="${PACKAGE_ARTIFACT_TIMEOUT:-10s}"
PACKAGE_COMMAND_BUILT=0

run_clean_from_temp_cwd() {
  local smoke_cwd
  local status

  smoke_cwd="$(mktemp -d "${TMPDIR:-/tmp}/plushie-package-smoke-cwd.XXXXXXXXXX")"

  if (
    set -e
    cd "$smoke_cwd"

    env -u PLUSHIE_BINARY_PATH \
      -u PLUSHIE_RENDERER_BINARY \
      -u PLUSHIE_RUST_SOURCE_PATH \
      -u PLUSHIE_TEST_BACKEND \
      -u PLUSHIE_PACKAGE_SMOKE \
      -u PLUSHIE_PACKAGE_DIR \
      "$@"
  ); then
    status=0
  else
    status=$?
  fi

  rm -rf "$smoke_cwd"
  return "$status"
}

run_package_command() {
  local manifest="$1"
  local out="$2"
  local cargo_plushie_dir=""

  PACKAGE_COMMAND_BUILT=0

  if ! command -v cargo >/dev/null 2>&1; then
    echo "skip: package smoke - cargo is unavailable; install Rust or set up cargo-plushie" >&2
    return 0
  fi

  if [ -n "${PLUSHIE_RUST_SOURCE_PATH:-}" ] && [ -f "$PLUSHIE_RUST_SOURCE_PATH/Cargo.toml" ]; then
    cargo_plushie_dir="$(cd "$PLUSHIE_RUST_SOURCE_PATH" && pwd)"
  elif ! command -v cargo-plushie >/dev/null 2>&1; then
    echo "skip: package smoke - cargo-plushie is unavailable; install cargo-plushie or set PLUSHIE_RUST_SOURCE_PATH" >&2
    return 0
  fi

  if [ -n "$cargo_plushie_dir" ]; then
    run_clean_from_temp_cwd \
      cargo run -q -p cargo-plushie \
      --manifest-path "$cargo_plushie_dir/Cargo.toml" \
      -- package \
      --manifest "$manifest" \
      --smoke \
      --smoke-timeout "$SMOKE_TIMEOUT" \
      --out "$out"
  else
    run_clean_from_temp_cwd \
      cargo plushie package \
      --manifest "$manifest" \
      --smoke \
      --smoke-timeout "$SMOKE_TIMEOUT" \
      --out "$out"
  fi
  PACKAGE_COMMAND_BUILT=1
}

run_artifact_command() {
  local artifact="$1"
  local cache_dir
  local log
  local status
  local timeout_args

  if [ "$RUN_ARTIFACTS" != "1" ]; then
    return 0
  fi

  if [ -z "${WAYLAND_DISPLAY:-}${WAYLAND_SOCKET:-}${DISPLAY:-}" ]; then
    echo "skip: package artifact smoke - no display server is available" >&2
    return 0
  fi

  if [ "$PACKAGE_COMMAND_BUILT" != "1" ]; then
    echo "skip: package artifact smoke - launcher was not built in this run" >&2
    return 0
  fi

  if ! command -v timeout >/dev/null 2>&1; then
    echo "skip: package artifact smoke - timeout is unavailable" >&2
    return 0
  fi

  if [ ! -x "$artifact" ]; then
    echo "failed: package artifact smoke - launcher is not executable: $artifact" >&2
    return 1
  fi

  log="$(mktemp "${TMPDIR:-/tmp}/plushie-package-artifact.XXXXXXXXXX")"
  cache_dir="$(mktemp -d "${TMPDIR:-/tmp}/plushie-package-artifact-cache.XXXXXXXXXX")"

  echo "==> artifact ${artifact#$ROOT/}"

  timeout_args=("$ARTIFACT_TIMEOUT" "$artifact")
  if timeout --help 2>&1 | grep -q -- '--kill-after'; then
    timeout_args=(--kill-after=2s "$ARTIFACT_TIMEOUT" "$artifact")
  fi

  set +e
  (
    export PLUSHIE_CACHE_DIR="$cache_dir"
    run_clean_from_temp_cwd \
      timeout "${timeout_args[@]}"
  ) >"$log" 2>&1
  status=$?
  set -e

  if grep -q "plushie launcher: smoke ok" "$log"; then
    echo "failed: artifact used launcher smoke mode" >&2
    sed -n '1,120p' "$log" >&2
    rm -f "$log"
    rm -rf "$cache_dir"
    return 1
  fi

  if ! grep -q "plushie launcher: app=" "$log"; then
    echo "failed: artifact did not emit launcher diagnostics" >&2
    sed -n '1,120p' "$log" >&2
    rm -f "$log"
    rm -rf "$cache_dir"
    return 1
  fi

  case "$status" in
    0)
      if ! grep -q "plushie launcher: renderer exited" "$log"; then
        echo "failed: artifact exited before renderer shutdown" >&2
        sed -n '1,120p' "$log" >&2
        rm -f "$log"
        rm -rf "$cache_dir"
        return 1
      fi
      echo "ok: artifact exited cleanly"
      ;;
    124|137)
      echo "ok: artifact stayed alive until timeout"
      ;;
    *)
      echo "failed: artifact exit status $status" >&2
      sed -n '1,120p' "$log" >&2
      rm -f "$log"
      rm -rf "$cache_dir"
      return "$status"
      ;;
  esac

  rm -f "$log"
  rm -rf "$cache_dir"
}

should_run_language() {
  local candidate="$1"

  [ "$LANGUAGE" = "all" ] || [ "$LANGUAGE" = "$candidate" ]
}

build_payloads_for_language() {
  local language="$1"

  if [ "$BUILD_PAYLOADS" != "1" ]; then
    return 0
  fi

  case "$language" in
    elixir|gleam|ruby|typescript)
      while IFS= read -r script; do
        echo "==> build ${script#$ROOT/}"
        (cd "$(dirname "$script")/.." && ./scripts/package.sh)
      done < <(find "$ROOT/$language" -path '*/scripts/package.sh' -type f | sort)
      ;;
    python)
      while IFS= read -r script; do
        echo "==> build ${script#$ROOT/}"
        (cd "$(dirname "$script")" && ./build_standalone.sh)
      done < <(find "$ROOT/python" -name build_standalone.sh -type f | sort)
      ;;
  esac
}

manifests_for_language() {
  local language="$1"

  case "$language" in
    elixir|gleam|ruby)
      find "$ROOT/$language" -path '*/dist/plushie-package.toml' -type f | sort
      ;;
    python)
      find "$ROOT/python" -path '*/dist/package/plushie-package.toml' -type f | sort
      ;;
    typescript)
      find "$ROOT/typescript" -path '*/dist/shared-launcher/plushie-package.toml' -type f | sort
      ;;
    rust)
      true
      ;;
  esac
}

smoke_language() {
  local language="$1"
  local count=0

  build_payloads_for_language "$language"

  while IFS= read -r manifest; do
    count=$((count + 1))
    local rel="${manifest#$ROOT/}"
    local demo="${rel%%/dist/*}"
    local safe="${demo//\//-}"
    local out="$ROOT/$demo/dist/package-smoke/$safe"

    echo "==> smoke $rel"
    run_package_command "$manifest" "$out"
    run_artifact_command "$out"
  done < <(manifests_for_language "$language")

  if [ "$count" -eq 0 ]; then
    echo "skip: $language - no package manifest found"
  fi
}

case "$LANGUAGE" in
  all|elixir|gleam|python|ruby|rust|typescript) ;;
  *)
    echo "usage: $0 [all|elixir|gleam|python|ruby|rust|typescript]" >&2
    exit 2
    ;;
esac

for language in elixir gleam python ruby rust typescript; do
  if should_run_language "$language"; then
    smoke_language "$language"
  fi
done
