#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_PLUSHIE_PYTHON_DIR="$(cd "$SCRIPT_DIR/../../../plushie-python" 2>/dev/null && pwd || true)"
PLUSHIE_PYTHON_DIR="${PLUSHIE_PYTHON_DIR:-$DEFAULT_PLUSHIE_PYTHON_DIR}"

if [ -n "$PLUSHIE_PYTHON_DIR" ] && [ -d "$PLUSHIE_PYTHON_DIR/src/plushie" ]; then
    echo "==> Installing local plushie SDK..."
    python -m pip install -e "$PLUSHIE_PYTHON_DIR"
fi

echo "==> Downloading plushie binary..."
if [ -z "${PLUSHIE_BINARY_PATH:-}" ]; then
    python -m plushie download
else
    echo "    Using PLUSHIE_BINARY_PATH=$PLUSHIE_BINARY_PATH"
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
TARGET=$(python - <<'PY'
import platform
import sys

os_map = {
    "linux": "linux",
    "darwin": "darwin",
    "win32": "windows",
    "cygwin": "windows",
}
arch_map = {
    "x86_64": "x86_64",
    "amd64": "x86_64",
    "aarch64": "aarch64",
    "arm64": "aarch64",
}

os_name = os_map.get(sys.platform)
arch = arch_map.get(platform.machine().lower())
if os_name is None:
    raise SystemExit(f"Unsupported package OS: {sys.platform}")
if arch is None:
    raise SystemExit(f"Unsupported package architecture: {platform.machine()}")

print(f"{os_name}-{arch}")
PY
)
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

(cd "$PAYLOAD_ROOT" && tar --dereference --hard-dereference --zstd -cf "../payload.tar.zst" .)
PAYLOAD_HASH=$(python -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$PAYLOAD_ARCHIVE")
PAYLOAD_SIZE=$(python -c 'import os, sys; print(os.path.getsize(sys.argv[1]))' "$PAYLOAD_ARCHIVE")

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
