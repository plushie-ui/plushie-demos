#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
DEFAULT_PLUSHIE_PYTHON_DIR="$(cd "$SCRIPT_DIR/../../../plushie-python" 2>/dev/null && pwd || true)"
PLUSHIE_PYTHON_DIR="${PLUSHIE_PYTHON_DIR:-$DEFAULT_PLUSHIE_PYTHON_DIR}"

if [ -n "$PLUSHIE_PYTHON_DIR" ] && [ -d "$PLUSHIE_PYTHON_DIR/src/plushie" ]; then
    echo "==> Installing local plushie SDK..."
    python -m pip install -e "$PLUSHIE_PYTHON_DIR"

    echo "==> Installing app dependencies..."
    python -m pip install "pandas>=2.0"
    python -m pip install -e . --no-deps
else
    echo "==> Installing app dependencies..."
    python -m pip install -e .
fi

echo "==> Installing PyInstaller..."
python -m pip install pyinstaller

echo "==> Building shared launcher payload..."
python -m plushie package \
    --app-id dev.plushie.demos.python.data-explorer \
    --app-name "Data Explorer" \
    --pyinstaller-entry src/data_explorer/__main__.py \
    --pyinstaller-name DataExplorer \
    --add-data "$PROJECT_DIR/sample_data:sample_data" \
    --hidden-import pandas \
    --hidden-import plushie \
    --collect-submodules plushie \
    --renderer-kind stock \

echo ""
echo "Built: dist/DataExplorer/"
echo "Run:   ./dist/DataExplorer/DataExplorer"
echo "Payload manifest: dist/package/plushie-package.toml"
echo "Payload archive:  dist/package/payload.tar.zst"
echo "Package handoff:  bin/plushie package portable --manifest dist/package/plushie-package.toml"
