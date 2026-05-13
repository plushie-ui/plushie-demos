"""Entry point for the data explorer app."""

import os

import plushie

from data_explorer.app import DataExplorer

if __name__ == "__main__":
    if os.environ.get("PLUSHIE_SOCKET"):
        connect = getattr(plushie, "connect")
        connect(DataExplorer)
    else:
        plushie.run(DataExplorer)
