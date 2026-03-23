#!/bin/bash
#
# Package the data explorer as a standalone executable via Node.js SEA.
#
# Produces: dist/data-explorer (single file, no dependencies)
#
# Prerequisites:
#   - Node.js 20+
#   - pnpm install (for esbuild and postject)
#   - plushie binary (npx plushie download or PLUSHIE_BINARY_PATH)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"

cd "$PROJECT_DIR"

# -- Step 1: Bundle the app --------------------------------------------------

echo "Bundling app..."
node scripts/bundle.mjs

# -- Step 2: Resolve the plushie binary --------------------------------------

if [ -n "${PLUSHIE_BINARY_PATH:-}" ]; then
  BINARY_PATH="$PLUSHIE_BINARY_PATH"
elif [ -f "node_modules/.plushie/bin/plushie-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/x86_64/x86_64/;s/arm64/aarch64/;s/aarch64/aarch64/')" ]; then
  BINARY_PATH="node_modules/.plushie/bin/plushie-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/x86_64/x86_64/;s/arm64/aarch64/;s/aarch64/aarch64/')"
else
  echo "Error: plushie binary not found."
  echo "Run 'npx plushie download' or set PLUSHIE_BINARY_PATH."
  exit 1
fi

echo "Using binary: $BINARY_PATH"

# -- Step 3: Generate SEA config ---------------------------------------------

echo "Generating SEA config..."
cat > "$DIST_DIR/sea-config.json" << EOF
{
  "main": "dist/app.cjs",
  "output": "dist/sea-prep.blob",
  "disableExperimentalSEAWarning": true,
  "useCodeCache": true,
  "assets": {
    "plushie-binary": "$BINARY_PATH"
  }
}
EOF

# -- Step 4: Prepare the SEA blob --------------------------------------------

echo "Preparing SEA blob..."
node --experimental-sea-config "$DIST_DIR/sea-config.json"

# -- Step 5: Copy node binary and inject the blob ----------------------------

echo "Injecting into node binary..."
cp "$(command -v node)" "$DIST_DIR/data-explorer"

# Remove existing signature on macOS
if [ "$(uname -s)" = "Darwin" ]; then
  codesign --remove-signature "$DIST_DIR/data-explorer" 2>/dev/null || true
fi

npx postject "$DIST_DIR/data-explorer" NODE_SEA_BLOB "$DIST_DIR/sea-prep.blob" \
  --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2

# Re-sign on macOS
if [ "$(uname -s)" = "Darwin" ]; then
  codesign -s - "$DIST_DIR/data-explorer"
fi

# -- Step 6: Clean up intermediate files -------------------------------------

rm -f "$DIST_DIR/sea-config.json" "$DIST_DIR/sea-prep.blob"

# -- Done --------------------------------------------------------------------

SIZE=$(du -h "$DIST_DIR/data-explorer" | cut -f1)
echo ""
echo "Standalone executable: $DIST_DIR/data-explorer ($SIZE)"
echo ""
echo "Run it:"
echo "  $DIST_DIR/data-explorer"
