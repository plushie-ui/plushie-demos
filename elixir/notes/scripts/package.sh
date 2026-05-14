#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
PAYLOAD_DIR="$DIST_DIR/payload"
RELEASE_DIR="$PROJECT_DIR/_build/prod/rel/notes"
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

resolve_renderer() {
  if [ -n "${PLUSHIE_BINARY_PATH:-}" ]; then
    if [ ! -x "$PLUSHIE_BINARY_PATH" ]; then
      echo "PLUSHIE_BINARY_PATH is not executable: $PLUSHIE_BINARY_PATH" >&2
      exit 1
    fi

    printf '%s\n' "$PLUSHIE_BINARY_PATH"
  elif [ -n "${PLUSHIE_RUST_SOURCE_PATH:-}" ]; then
    if [ ! -f "$PLUSHIE_RUST_SOURCE_PATH/Cargo.toml" ]; then
      echo "PLUSHIE_RUST_SOURCE_PATH does not look like a Rust workspace: $PLUSHIE_RUST_SOURCE_PATH" >&2
      exit 1
    fi

    require_command cargo
    echo "Building plushie-renderer from $PLUSHIE_RUST_SOURCE_PATH" >&2
    (cd "$PLUSHIE_RUST_SOURCE_PATH" && cargo build --release -p plushie-renderer)
    printf '%s\n' "$PLUSHIE_RUST_SOURCE_PATH/target/release/plushie-renderer"
  elif [ -x "$PROJECT_DIR/_build/plushie/bin/plushie-renderer" ]; then
    printf '%s\n' "$PROJECT_DIR/_build/plushie/bin/plushie-renderer"
  elif command -v plushie-renderer >/dev/null 2>&1; then
    command -v plushie-renderer
  elif command -v plushie >/dev/null 2>&1; then
    command -v plushie
  else
    echo "No renderer binary found. Run mix plushie.download or set PLUSHIE_BINARY_PATH." >&2
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

renderer="$(resolve_renderer)"
target="$(package_target)"

echo "Building release..."
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix deps.compile --force
plushie_rust_version="${PLUSHIE_RUST_VERSION:-$(tr -d '\n' < "$PLUSHIE_ELIXIR_DIR/PLUSHIE_RUST_VERSION")}"
MIX_ENV=prod mix release --overwrite

echo "Preparing payload..."
rm -rf "$DIST_DIR"
mkdir -p "$PAYLOAD_DIR/bin" "$PAYLOAD_DIR/rel"
cp -R "$RELEASE_DIR" "$PAYLOAD_DIR/rel/notes"
cp "$renderer" "$PAYLOAD_DIR/bin/plushie-renderer"
chmod +x "$PAYLOAD_DIR/bin/plushie-renderer"

cat > "$PAYLOAD_DIR/bin/connect" <<'SH'
#!/bin/sh
set -eu
DIR="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
exec "$DIR/rel/notes/bin/notes" eval "Notes.Connect.main()"
SH
chmod +x "$PAYLOAD_DIR/bin/connect"

echo "Writing archive..."
archive_payload "$PAYLOAD_DIR" "$DIST_DIR/payload.tar.zst"
payload_hash="$(hash_file "$DIST_DIR/payload.tar.zst")"
payload_size="$(file_size "$DIST_DIR/payload.tar.zst")"

cat > "$DIST_DIR/plushie-package.toml" <<EOF
schema_version = 1
app_id = "dev.plushie.demos.elixir.notes"
app_version = "0.1.0"
target = "$target"
host_sdk = "elixir"
plushie_rust_version = "$plushie_rust_version"
protocol_version = 1
renderer_path = "bin/plushie-renderer"
host_command = ["bin/connect"]
working_dir = "."
exec_env = []

[renderer]
kind = "stock"
source = "local-resolve"

[payload]
archive = "payload.tar.zst"
hash = "sha256:$payload_hash"
size = $payload_size
EOF

echo "Wrote $DIST_DIR/payload.tar.zst"
echo "Wrote $DIST_DIR/plushie-package.toml"
echo "Build launcher with:"
echo "  cargo plushie package --manifest $DIST_DIR/plushie-package.toml --release"
