#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

source ../scripts/demo_env.sh
set_default_plushie_demo_env "$PROJECT_DIR"
remove_legacy_renderer_link

MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix deps.compile --force
MIX_ENV=prod mix plushie.download
MIX_ENV=prod mix plushie.package Notes.App \
  --app-id dev.plushie.demos.elixir.notes \
  --app-name "Elixir Notes" \
  --renderer stock \
  --strict-tools
