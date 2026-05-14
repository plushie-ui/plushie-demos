#!/bin/bash
#
# Package the data explorer as a standalone executable via the
# TypeScript SDK-owned package command.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "Bundling app..."
node scripts/bundle.mjs

npx plushie package \
  --app-id dev.plushie.demos.typescript.data-explorer \
  --app-name "Data Explorer" \
  --main dist/app.cjs \
  --sea-output dist/data-explorer \
  --output dist/shared-launcher
