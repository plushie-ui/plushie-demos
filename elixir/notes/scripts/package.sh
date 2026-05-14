#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
PAYLOAD_DIR="$DIST_DIR/payload"
RELEASE_DIR="$PROJECT_DIR/_build/prod/rel/notes"

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

package_target() {
  local os
  local arch

  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  case "$os" in
    linux*) os="linux" ;;
    darwin*) os="darwin" ;;
    msys*|mingw*|cygwin*) os="windows" ;;
    *)
      echo "Unsupported package OS: $os" >&2
      exit 1
      ;;
  esac

  arch="$(uname -m | tr '[:upper:]' '[:lower:]')"
  case "$arch" in
    amd64|x86_64) arch="x86_64" ;;
    arm64|aarch64) arch="aarch64" ;;
    *)
      echo "Unsupported package architecture: $arch" >&2
      exit 1
      ;;
  esac

  printf '%s-%s\n' "$os" "$arch"
}

resolve_renderer() {
  if [ -n "${PLUSHIE_BINARY_PATH:-}" ]; then
    printf '%s\n' "$PLUSHIE_BINARY_PATH"
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

renderer="$(resolve_renderer)"
target="$(package_target)"

echo "Building release..."
MIX_ENV=prod mix deps.get --only prod
plushie_rust_version="${PLUSHIE_RUST_VERSION:-$(tr -d '\n' < deps/plushie/PLUSHIE_RUST_VERSION)}"
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
(cd "$PAYLOAD_DIR" && tar --zstd -cf "$DIST_DIR/payload.tar.zst" .)
payload_hash="$(hash_file "$DIST_DIR/payload.tar.zst")"

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
EOF

echo "Wrote $DIST_DIR/payload.tar.zst"
echo "Wrote $DIST_DIR/plushie-package.toml"
echo "Build launcher with:"
echo "  cargo plushie package --manifest $DIST_DIR/plushie-package.toml --release"
