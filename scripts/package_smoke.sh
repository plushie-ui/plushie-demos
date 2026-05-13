#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LANGUAGE="${1:-all}"
SMOKE_TIMEOUT="${PACKAGE_SMOKE_TIMEOUT:-10}"
BUILD_PAYLOADS="${PACKAGE_SMOKE_BUILD:-0}"

run_package_command() {
  local manifest="$1"
  local out="$2"

  if ! command -v cargo >/dev/null 2>&1; then
    echo "skip: package smoke - cargo is unavailable; install Rust or set up cargo-plushie" >&2
    return 0
  fi

  if [ -n "${PLUSHIE_RUST_SOURCE_PATH:-}" ] && [ -f "$PLUSHIE_RUST_SOURCE_PATH/Cargo.toml" ]; then
    (
      cd "$PLUSHIE_RUST_SOURCE_PATH"
      cargo run -q -p cargo-plushie -- package \
        --manifest "$manifest" \
        --smoke \
        --smoke-timeout "$SMOKE_TIMEOUT" \
        --out "$out"
    )
  else
    cargo plushie package \
      --manifest "$manifest" \
      --smoke \
      --smoke-timeout "$SMOKE_TIMEOUT" \
      --out "$out"
  fi
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
