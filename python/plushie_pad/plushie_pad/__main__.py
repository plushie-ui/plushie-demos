"""CLI entry point: ``python -m plushie_pad``."""

from __future__ import annotations

import plushie

from plushie_pad.app import Pad


def main() -> None:
    plushie.run(Pad)


if __name__ == "__main__":
    main()
