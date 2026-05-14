#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEFAULT_PLUSHIE_PYTHON_DIR="$(cd "$SCRIPT_DIR/../../../plushie-python" 2>/dev/null && pwd || true)"
PLUSHIE_PYTHON_DIR="${PLUSHIE_PYTHON_DIR:-$DEFAULT_PLUSHIE_PYTHON_DIR}"

# shellcheck source=../../scripts/package_lib.sh
source "$ROOT_DIR/scripts/package_lib.sh"

if [ -n "$PLUSHIE_PYTHON_DIR" ] && [ -d "$PLUSHIE_PYTHON_DIR/src/plushie" ]; then
    echo "==> Installing local plushie SDK..."
    python -m pip install -e "$PLUSHIE_PYTHON_DIR"
fi

echo "==> Installing app dependencies..."
python -m pip install -e .

echo "==> Resolving plushie binary..."
if [ -n "${PLUSHIE_BINARY_PATH:-}" ]; then
    echo "    Using PLUSHIE_BINARY_PATH=$PLUSHIE_BINARY_PATH"
elif [ -n "${PLUSHIE_RUST_SOURCE_PATH:-}" ]; then
    if [ ! -f "$PLUSHIE_RUST_SOURCE_PATH/Cargo.toml" ]; then
        echo "PLUSHIE_RUST_SOURCE_PATH does not look like a Rust workspace: $PLUSHIE_RUST_SOURCE_PATH" >&2
        exit 1
    fi

    echo "    Building plushie-renderer from $PLUSHIE_RUST_SOURCE_PATH"
    (cd "$PLUSHIE_RUST_SOURCE_PATH" && cargo build --release -p plushie-renderer)
    export PLUSHIE_BINARY_PATH="$PLUSHIE_RUST_SOURCE_PATH/target/release/plushie-renderer"
else
    python -m plushie download
fi

echo "==> Finding binary path..."
BINARY=$(python -c "from plushie.binary import resolve; print(resolve())")
echo "    Binary: $BINARY"

echo "==> Staging bundled renderer..."
STAGED_RENDERER=$(python -c 'import sys; from pathlib import Path; print(Path("build/standalone/renderer") / ("plushie-renderer.exe" if sys.platform in ("win32", "cygwin") else "plushie-renderer"))')
mkdir -p "$(dirname "$STAGED_RENDERER")"
cp "$BINARY" "$STAGED_RENDERER"
chmod +x "$STAGED_RENDERER"
echo "    Bundled name: $STAGED_RENDERER"

echo "==> Installing PyInstaller..."
python -m pip install pyinstaller

echo "==> Building standalone app..."
python -m PyInstaller \
    --name "DataExplorer" \
    --add-binary "$STAGED_RENDERER:." \
    --add-data "sample_data:sample_data" \
    --hidden-import pandas \
    --hidden-import plushie \
    --collect-submodules plushie \
    --collect-submodules pandas \
    --noconfirm \
    src/data_explorer/__main__.py

echo "==> Emitting shared launcher payload..."
PACKAGE_DIR="dist/package"
PAYLOAD_ROOT="$PACKAGE_DIR/payload"
PAYLOAD_ARCHIVE="$PACKAGE_DIR/payload.tar.zst"
MANIFEST="$PACKAGE_DIR/plushie-package.toml"
PAYLOAD_RENDERER=$(python -c 'import sys; print("bin/plushie-renderer.exe" if sys.platform in ("win32", "cygwin") else "bin/plushie-renderer")')
HOST_EXE=$(python -c 'import sys; print("host/DataExplorer/DataExplorer.exe" if sys.platform in ("win32", "cygwin") else "host/DataExplorer/DataExplorer")')
TARGET="$(normalize_package_target "$(python -c 'import sys; print(sys.platform)')" "$(python -c 'import platform; print(platform.machine())')")"
APP_VERSION=$(python -c 'import tomllib; print(tomllib.load(open("pyproject.toml", "rb"))["project"]["version"])')
SDK_VERSION=$(python -c 'import plushie; print(plushie.__version__)')
RUST_VERSION=$(python -c 'from plushie.binary import PLUSHIE_RUST_VERSION; print(PLUSHIE_RUST_VERSION)')
PROTOCOL_VERSION=$(python -c 'from plushie.protocol import PROTOCOL_VERSION; print(PROTOCOL_VERSION)')

rm -rf "$PACKAGE_DIR"
mkdir -p "$PAYLOAD_ROOT/bin" "$PAYLOAD_ROOT/host"
cp "$STAGED_RENDERER" "$PAYLOAD_ROOT/$PAYLOAD_RENDERER"
chmod +x "$PAYLOAD_ROOT/$PAYLOAD_RENDERER"
cp -R "dist/DataExplorer" "$PAYLOAD_ROOT/host/DataExplorer"
find "$PAYLOAD_ROOT/host/DataExplorer" -maxdepth 2 -type f \
    \( -name "plushie-renderer" -o -name "plushie-renderer.exe" \) -delete

dereference_payload_symlinks "$PAYLOAD_ROOT"
archive_payload "$PAYLOAD_ROOT" "$PAYLOAD_ARCHIVE"
PAYLOAD_HASH="$(hash_file "$PAYLOAD_ARCHIVE")"
PAYLOAD_SIZE="$(file_size "$PAYLOAD_ARCHIVE")"

cat > "$MANIFEST" <<EOF
schema_version = 1
app_id = "dev.plushie.demos.python.data-explorer"
app_name = "Data Explorer"
app_version = "$APP_VERSION"
target = "$TARGET"

host_sdk = "python"
host_sdk_version = "$SDK_VERSION"
plushie_rust_version = "$RUST_VERSION"
protocol_version = $PROTOCOL_VERSION

renderer_path = "$PAYLOAD_RENDERER"
host_command = ["$HOST_EXE"]
working_dir = "."

[renderer]
kind = "stock"
source = "download"

[payload]
archive = "payload.tar.zst"
hash = "sha256:$PAYLOAD_HASH"
size = $PAYLOAD_SIZE
EOF

echo ""
echo "Built: dist/DataExplorer/"
echo "Run:   ./dist/DataExplorer/DataExplorer"
echo "Payload manifest: $MANIFEST"
echo "Payload archive:  $PAYLOAD_ARCHIVE"
echo "Package handoff:  cargo plushie package --manifest $MANIFEST --release"
