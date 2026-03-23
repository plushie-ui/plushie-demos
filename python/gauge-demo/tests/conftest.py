"""Shared fixtures for gauge-demo tests."""

from __future__ import annotations

import sys
from pathlib import Path

# Ensure src/ is importable without install
src = str(Path(__file__).resolve().parent.parent / "src")
if src not in sys.path:
    sys.path.insert(0, src)
