#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
PAYLOAD_DIR="$DIST_DIR/payload"
RELEASE_DIR="$PROJECT_DIR/_build/prod/rel/gauge_demo"
CUSTOM_RENDERER="$PROJECT_DIR/_build/plushie/package/gauge-demo-plushie"
DEFAULT_PLUSHIE_ELIXIR_DIR="$(cd "$PROJECT_DIR/../../../plushie-elixir" 2>/dev/null && pwd || true)"
PLUSHIE_ELIXIR_DIR="${PLUSHIE_ELIXIR_DIR:-$DEFAULT_PLUSHIE_ELIXIR_DIR}"

# shellcheck source=../../../scripts/package_lib.sh
source "$ROOT_DIR/scripts/package_lib.sh"

cd "$PROJECT_DIR"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command mix
require_command tar

if [ -z "$PLUSHIE_ELIXIR_DIR" ] || [ ! -f "$PLUSHIE_ELIXIR_DIR/PLUSHIE_RUST_VERSION" ]; then
  echo "Set PLUSHIE_ELIXIR_DIR to a plushie-elixir checkout before packaging this demo." >&2
  exit 1
fi

export PLUSHIE_ELIXIR_DIR

target="$(package_target)"

echo "Building custom gauge renderer..."
mkdir -p "$(dirname "$CUSTOM_RENDERER")"
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix deps.compile --force
PLUSHIE_PACKAGE_RENDERER="$CUSTOM_RENDERER" MIX_ENV=prod mix run --no-start -e '
Code.ensure_loaded!(GaugeDemo.Gauge)
Plushie.WidgetRegistry.invalidate()
Mix.Task.run("plushie.build", ["--release", "--bin-file", System.fetch_env!("PLUSHIE_PACKAGE_RENDERER")])
'
plushie_rust_version="${PLUSHIE_RUST_VERSION:-$(tr -d '\n' < "$PLUSHIE_ELIXIR_DIR/PLUSHIE_RUST_VERSION")}"

echo "Building host release..."
MIX_ENV=prod mix release --overwrite

echo "Preparing payload..."
rm -rf "$DIST_DIR"
mkdir -p "$PAYLOAD_DIR/bin" "$PAYLOAD_DIR/rel"
cp -R "$RELEASE_DIR" "$PAYLOAD_DIR/rel/gauge_demo"
cp "$CUSTOM_RENDERER" "$PAYLOAD_DIR/bin/gauge-demo-plushie"
chmod +x "$PAYLOAD_DIR/bin/gauge-demo-plushie"

cat > "$PAYLOAD_DIR/bin/connect" <<'SH'
#!/bin/sh
set -eu
DIR="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
exec "$DIR/rel/gauge_demo/bin/gauge_demo" eval "GaugeDemo.Connect.main()"
SH
chmod +x "$PAYLOAD_DIR/bin/connect"

echo "Writing archive..."
archive_payload "$PAYLOAD_DIR" "$DIST_DIR/payload.tar.zst"
payload_hash="$(hash_file "$DIST_DIR/payload.tar.zst")"
payload_size="$(file_size "$DIST_DIR/payload.tar.zst")"

cat > "$DIST_DIR/plushie-package.toml" <<EOF
schema_version = 1
app_id = "dev.plushie.demos.elixir.gauge"
app_version = "0.1.0"
target = "$target"
host_sdk = "elixir"
plushie_rust_version = "$plushie_rust_version"
protocol_version = 1
renderer_path = "bin/gauge-demo-plushie"
host_command = ["bin/connect"]
working_dir = "."
exec_env = []

[renderer]
kind = "custom"
source = "local-build"

[payload]
archive = "payload.tar.zst"
hash = "sha256:$payload_hash"
size = $payload_size
EOF

echo "Wrote $DIST_DIR/payload.tar.zst"
echo "Wrote $DIST_DIR/plushie-package.toml"
echo "Build launcher with:"
echo "  cargo plushie package --manifest $DIST_DIR/plushie-package.toml --release"
