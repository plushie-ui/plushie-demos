#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RENDERER_KIND="${PLUSHIE_PACKAGE_RENDERER_KIND:-custom}"

cd "$PROJECT_DIR"

gleam clean

exec gleam run -m plushie/package -- \
  --app-id dev.plushie.demos.gleam.gauge \
  --app-name "Gleam Gauge" \
  --app-version 0.1.0 \
  --connect-module gauge_demo@connect \
  --renderer-kind "$RENDERER_KIND" \
  --release \
  "$@"
