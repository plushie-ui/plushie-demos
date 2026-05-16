#!/usr/bin/env bash

set -euo pipefail

set_default_plushie_demo_env() {
  local project_dir="$1"
  local default_sdk
  local default_source

  default_sdk="$(cd "$project_dir/../../../plushie-elixir" 2>/dev/null && pwd || true)"
  default_source="$(cd "$project_dir/../../../plushie-rust" 2>/dev/null && pwd || true)"

  if [ -z "${PLUSHIE_ELIXIR_DIR:-}" ] && [ -n "$default_sdk" ] && [ -f "$default_sdk/mix.exs" ]; then
    export PLUSHIE_ELIXIR_DIR="$default_sdk"
  fi

  if [ -z "${PLUSHIE_ELIXIR_DIR:-}" ] || [ ! -f "$PLUSHIE_ELIXIR_DIR/mix.exs" ]; then
    echo "Set PLUSHIE_ELIXIR_DIR to a plushie-elixir checkout before running this script." >&2
    exit 1
  fi

  if [ -z "${PLUSHIE_RUST_SOURCE_PATH:-}" ] && [ -n "$default_source" ] && [ -f "$default_source/Cargo.toml" ]; then
    export PLUSHIE_RUST_SOURCE_PATH="$default_source"
  fi
}

sync_managed_plushie_tools() {
  local required_version

  required_version="$(<"$PLUSHIE_ELIXIR_DIR/PLUSHIE_RUST_VERSION")"

  if [ -x "bin/plushie" ]; then
    bin/plushie tools sync --required-version "$required_version"
    return
  fi

  if [ -n "${PLUSHIE_RUST_SOURCE_PATH:-}" ] && [ -f "$PLUSHIE_RUST_SOURCE_PATH/Cargo.toml" ]; then
    cargo run \
      --manifest-path "$PLUSHIE_RUST_SOURCE_PATH/Cargo.toml" \
      -p cargo-plushie \
      --bin plushie \
      --release \
      -- \
      tools sync \
      --required-version "$required_version"
    return
  fi

  echo "Managed Plushie tools are missing. Run mix plushie.download in a pure demo, or set PLUSHIE_RUST_SOURCE_PATH to a plushie-rust checkout so this script can sync bin/plushie and bin/plushie-launcher." >&2
  exit 1
}

remove_legacy_renderer_link() {
  local renderer_path="bin/plushie-renderer"
  local target=""

  if [ ! -L "$renderer_path" ]; then
    return
  fi

  target="$(readlink "$renderer_path" || true)"

  case "$target" in
    _build/*|build/*|*/_build/*|*/build/*)
      rm -f "$renderer_path"
      ;;
  esac
}
