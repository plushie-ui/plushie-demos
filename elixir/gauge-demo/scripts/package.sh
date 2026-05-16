#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RENDERER_KIND="${PLUSHIE_PACKAGE_RENDERER_KIND:-custom}"

cd "$PROJECT_DIR"

source ../scripts/demo_env.sh
set_default_plushie_demo_env "$PROJECT_DIR"
remove_legacy_renderer_link

MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix deps.compile --force
sync_managed_plushie_tools
MIX_ENV=prod mix plushie.package GaugeDemo.TemperatureMonitor \
  --app-id dev.plushie.demos.elixir.gauge \
  --app-name "Elixir Gauge" \
  --renderer "$RENDERER_KIND" \
  --strict-tools \
  --load GaugeDemo.Gauge
