#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_PLUSHIE_ELIXIR_DIR="$(cd "$PROJECT_DIR/../../../plushie-elixir" 2>/dev/null && pwd || true)"
PLUSHIE_ELIXIR_DIR="${PLUSHIE_ELIXIR_DIR:-$DEFAULT_PLUSHIE_ELIXIR_DIR}"
RENDERER_KIND="${PLUSHIE_PACKAGE_RENDERER_KIND:-custom}"

cd "$PROJECT_DIR"

if [ -z "$PLUSHIE_ELIXIR_DIR" ] || [ ! -f "$PLUSHIE_ELIXIR_DIR/PLUSHIE_RUST_VERSION" ]; then
  echo "Set PLUSHIE_ELIXIR_DIR to a plushie-elixir checkout before packaging this demo." >&2
  exit 1
fi

export PLUSHIE_ELIXIR_DIR

MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix deps.compile --force
MIX_ENV=prod mix plushie.package GaugeDemo.TemperatureMonitor \
  --app-id dev.plushie.demos.elixir.gauge \
  --app-name "Elixir Gauge" \
  --renderer "$RENDERER_KIND" \
  --load GaugeDemo.Gauge
