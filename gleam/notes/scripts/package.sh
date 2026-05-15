#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

gleam clean

exec gleam run -m plushie/package -- \
  --app-id dev.plushie.demos.gleam.notes \
  --app-name "Gleam Notes" \
  --app-version 0.1.0 \
  --connect-module notes@connect \
  --renderer-kind stock \
  --strict-tools \
  "$@"
