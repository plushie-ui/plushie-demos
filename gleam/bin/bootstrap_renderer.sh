#!/usr/bin/env bash

set -euo pipefail

default_source="$(cd ../../../plushie-rust 2>/dev/null && pwd || true)"

use_sibling_rust_source() {
  if [ -n "${PLUSHIE_RUST_SOURCE_PATH:-}" ]; then
    return
  fi

  if [ -n "$default_source" ] && [ -f "$default_source/Cargo.toml" ]; then
    export PLUSHIE_RUST_SOURCE_PATH="$default_source"
  fi
}

ensure_downloaded_renderer() {
  use_sibling_rust_source
  gleam run -m plushie/download -- --bin
}

ensure_built_renderer() {
  use_sibling_rust_source
  gleam run -m plushie/build -- --bin
}
