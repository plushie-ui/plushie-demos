#!/usr/bin/env bash
set -euo pipefail

echo "==> Downloading plushie binary..."
python -m plushie download

echo "==> Finding binary path..."
BINARY=$(python -c "from plushie.binary import resolve; print(resolve())")
echo "    Binary: $BINARY"

echo "==> Installing PyInstaller..."
pip install pyinstaller

echo "==> Building standalone app..."
pyinstaller \
    --name "DataExplorer" \
    --add-binary "$BINARY:." \
    --add-data "sample_data:sample_data" \
    --hidden-import pandas \
    --hidden-import plushie \
    --collect-submodules plushie \
    --collect-submodules pandas \
    --noconfirm \
    src/data_explorer/__main__.py

echo ""
echo "Built: dist/DataExplorer/"
echo "Run:   ./dist/DataExplorer/DataExplorer"
