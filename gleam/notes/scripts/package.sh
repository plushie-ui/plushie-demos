#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
PAYLOAD_DIR="$DIST_DIR/payload"
SHIPMENT_DIR="$PROJECT_DIR/build/erlang-shipment"

cd "$PROJECT_DIR"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

resolve_renderer() {
  if [ -n "${PLUSHIE_BINARY_PATH:-}" ]; then
    printf '%s\n' "$PLUSHIE_BINARY_PATH"
  elif [ -x "$SHIPMENT_DIR/plushie-renderer" ]; then
    printf '%s\n' "$SHIPMENT_DIR/plushie-renderer"
  elif command -v plushie-renderer >/dev/null 2>&1; then
    command -v plushie-renderer
  elif command -v plushie >/dev/null 2>&1; then
    command -v plushie
  else
    echo "No renderer binary found. Run gleam run -m plushie/download or set PLUSHIE_BINARY_PATH." >&2
    exit 1
  fi
}

require_command gleam
require_command tar

renderer="$(resolve_renderer)"
plushie_rust_version="${PLUSHIE_RUST_VERSION:-$(awk -F '"' '/^plushie_rust_version = / { print $2 }' gleam.toml)}"

echo "Building shipment..."
gleam export erlang-shipment

echo "Preparing payload..."
rm -rf "$DIST_DIR"
mkdir -p "$PAYLOAD_DIR/bin" "$PAYLOAD_DIR/shipment"
cp -R "$SHIPMENT_DIR"/. "$PAYLOAD_DIR/shipment/"
cp "$renderer" "$PAYLOAD_DIR/bin/plushie-renderer"
chmod +x "$PAYLOAD_DIR/bin/plushie-renderer"

cat > "$PAYLOAD_DIR/bin/connect" <<'SH'
#!/bin/sh
set -eu
DIR="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
exec erl -pa "$DIR"/shipment/*/ebin -eval 'notes@connect:main().' -noshell -extra "$@"
SH
chmod +x "$PAYLOAD_DIR/bin/connect"

echo "Writing archive..."
(cd "$PAYLOAD_DIR" && tar --zstd -cf "$DIST_DIR/payload.tar.zst" .)
payload_hash="$(hash_file "$DIST_DIR/payload.tar.zst")"

cat > "$DIST_DIR/plushie-package.toml" <<EOF
schema_version = 1
app_id = "dev.plushie.demos.gleam.notes"
app_version = "0.1.0"
host_sdk = "gleam"
plushie_rust_version = "$plushie_rust_version"
protocol_version = 1
renderer_path = "bin/plushie-renderer"
host_command = ["bin/connect"]
working_dir = "."
exec_env = []

[payload]
archive = "payload.tar.zst"
hash = "sha256:$payload_hash"
EOF

echo "Wrote $DIST_DIR/payload.tar.zst"
echo "Wrote $DIST_DIR/plushie-package.toml"
echo "Build launcher with:"
echo "  cargo plushie package --manifest $DIST_DIR/plushie-package.toml --release"
