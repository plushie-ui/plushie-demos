#!/bin/bash
#
# Package the data explorer as a standalone executable via the
# TypeScript SDK-owned package command.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_PLUSHIE_TYPESCRIPT_DIR="$(cd "$PROJECT_DIR/../../../plushie-typescript" 2>/dev/null && pwd || true)"
PLUSHIE_TYPESCRIPT_DIR="${PLUSHIE_TYPESCRIPT_DIR:-$DEFAULT_PLUSHIE_TYPESCRIPT_DIR}"

cd "$PROJECT_DIR"

plushie_cmd=(npx plushie)

if [ -n "$PLUSHIE_TYPESCRIPT_DIR" ] && [ -f "$PLUSHIE_TYPESCRIPT_DIR/package.json" ]; then
  echo "Building local plushie SDK..."
  (cd "$PLUSHIE_TYPESCRIPT_DIR" && pnpm build)
  pnpm install --frozen-lockfile --force
  plushie_cmd=(node "$PLUSHIE_TYPESCRIPT_DIR/dist/cli/index.js")
fi

echo "Bundling app..."
node scripts/bundle.mjs

"${plushie_cmd[@]}" package \
  --app-id dev.plushie.demos.typescript.data-explorer \
  --app-name "Data Explorer" \
  --main dist/app.cjs \
  --sea-output dist/data-explorer \
  --output dist/shared-launcher
