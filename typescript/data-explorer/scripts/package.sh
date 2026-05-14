#!/bin/bash
#
# Package the data explorer as a standalone executable via Node.js SEA
# and prepare a payload for the shared Plushie launcher.
#
# Produces:
#   dist/data-explorer
#   dist/shared-launcher/payload.tar.zst
#   dist/shared-launcher/plushie-package.toml
#
# Prerequisites:
#   - Node.js 20+
#   - pnpm install (for esbuild and postject)
#   - plushie binary (npx plushie download or PLUSHIE_BINARY_PATH)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
SHARED_DIR="$DIST_DIR/shared-launcher"
PAYLOAD_ROOT="$SHARED_DIR/payload-root"

cd "$PROJECT_DIR"

node_eval() {
  node --input-type=module -e "$1"
}

json_string() {
  VALUE="$1" node_eval 'console.log(JSON.stringify(process.env.VALUE ?? ""))'
}

platform_binary_name() {
  node_eval '
    const client = await import("plushie/client")
    console.log(client.platformBinaryName())
  '
}

plushie_rust_version() {
  node_eval '
    const client = await import("plushie/client")
    console.log(client.PLUSHIE_RUST_VERSION ?? client.BINARY_VERSION)
  '
}

package_field() {
  FIELD="$1" node_eval '
    const fs = await import("node:fs")
    const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"))
    console.log(pkg[process.env.FIELD])
  '
}

resolve_plushie_binary() {
  if [ -n "${PLUSHIE_BINARY_PATH:-}" ]; then
    printf '%s\n' "$PLUSHIE_BINARY_PATH"
    return
  fi

  local binary_name
  binary_name="$(platform_binary_name)"
  local binary_path="node_modules/.plushie/bin/$binary_name"
  if [ -f "$binary_path" ]; then
    printf '%s\n' "$binary_path"
    return
  fi

  echo "Error: plushie binary not found." >&2
  echo "Run 'npx plushie download' or set PLUSHIE_BINARY_PATH." >&2
  echo "Expected: $binary_path" >&2
  exit 1
}

prepare_sea_config() {
  local asset_path="${1:-}"
  local assets=""

  if [ -n "$asset_path" ]; then
    assets=",
  \"assets\": {
    \"plushie-binary\": $(json_string "$asset_path")
  }"
  fi

  cat > "$DIST_DIR/sea-config.json" << EOF
{
  "main": "dist/app.cjs",
  "output": "dist/sea-prep.blob",
  "disableExperimentalSEAWarning": true,
  "useCodeCache": true$assets
}
EOF
}

build_sea() {
  local output_path="$1"
  local asset_path="${2:-}"

  prepare_sea_config "$asset_path"
  node --experimental-sea-config "$DIST_DIR/sea-config.json"

  cp "$(command -v node)" "$output_path"

  if [ "$(uname -s)" = "Darwin" ]; then
    codesign --remove-signature "$output_path" 2>/dev/null || true
  fi

  npx postject "$output_path" NODE_SEA_BLOB "$DIST_DIR/sea-prep.blob" \
    --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2

  if [ "$(uname -s)" = "Darwin" ]; then
    codesign -s - "$output_path"
  fi

  rm -f "$DIST_DIR/sea-config.json" "$DIST_DIR/sea-prep.blob"
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f1
  else
    shasum -a 256 "$1" | cut -d ' ' -f1
  fi
}

write_shared_launcher_payload() {
  local binary_path="$1"
  local app_version="$2"
  local host_sdk_version="$3"
  local rust_version="$4"
  local target="$5"
  local renderer_name="$6"
  local host_name="$7"

  rm -rf "$SHARED_DIR"
  mkdir -p "$PAYLOAD_ROOT/bin"

  echo "Building host-only SEA for shared launcher payload..."
  build_sea "$PAYLOAD_ROOT/bin/$host_name"

  cp "$binary_path" "$PAYLOAD_ROOT/bin/$renderer_name"

  echo "Compressing shared launcher payload..."
  tar -C "$PAYLOAD_ROOT" --sort=name --mtime='UTC 1970-01-01' \
    --owner=0 --group=0 --numeric-owner -cf - . | zstd -q -19 -T0 -o "$SHARED_DIR/payload.tar.zst"

  local payload_hash
  payload_hash="$(sha256_file "$SHARED_DIR/payload.tar.zst")"
  local payload_size
  payload_size="$(wc -c < "$SHARED_DIR/payload.tar.zst" | tr -d ' ')"

  cat > "$SHARED_DIR/plushie-package.toml" << EOF
schema_version = 1
app_id = "dev.plushie.demos.typescript.data-explorer"
app_name = "Data Explorer"
app_version = $(json_string "$app_version")
target = $(json_string "$target")
host_sdk = "typescript"
host_sdk_version = $(json_string "$host_sdk_version")
plushie_rust_version = $(json_string "$rust_version")
protocol_version = 1
renderer_path = "bin/$renderer_name"
host_command = ["bin/$host_name"]
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

  rm -rf "$PAYLOAD_ROOT"
}

echo "Bundling app..."
node scripts/bundle.mjs

BINARY_PATH="$(resolve_plushie_binary)"
APP_VERSION="$(package_field version)"
HOST_SDK_VERSION="$(node_eval '
  const fs = await import("node:fs")
  const pkg = JSON.parse(fs.readFileSync("node_modules/plushie/package.json", "utf8"))
  console.log(pkg.version)
')"
RUST_VERSION="$(plushie_rust_version)"
TARGET="$(node_eval 'console.log(`${process.platform}-${process.arch}`)')"
RENDERER_NAME="$(basename "$BINARY_PATH")"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) HOST_NAME="data-explorer-host.exe" ;;
  *) HOST_NAME="data-explorer-host" ;;
esac

echo "Using binary: $BINARY_PATH"

echo "Building SEA with embedded renderer..."
build_sea "$DIST_DIR/data-explorer" "$BINARY_PATH"

write_shared_launcher_payload \
  "$BINARY_PATH" \
  "$APP_VERSION" \
  "$HOST_SDK_VERSION" \
  "$RUST_VERSION" \
  "$TARGET" \
  "$RENDERER_NAME" \
  "$HOST_NAME"

SIZE=$(du -h "$DIST_DIR/data-explorer" | cut -f1)
PAYLOAD_SIZE=$(du -h "$SHARED_DIR/payload.tar.zst" | cut -f1)
echo ""
echo "Standalone executable: $DIST_DIR/data-explorer ($SIZE)"
echo "Shared launcher payload: $SHARED_DIR/payload.tar.zst ($PAYLOAD_SIZE)"
echo "Shared launcher manifest: $SHARED_DIR/plushie-package.toml"
echo ""
echo "Run it:"
echo "  $DIST_DIR/data-explorer"
echo ""
echo "Build shared launcher:"
echo "  cargo plushie package --manifest $SHARED_DIR/plushie-package.toml --release"
