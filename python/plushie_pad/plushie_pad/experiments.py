"""List, load, save, and delete experiments stored as .py files.

Experiments live in ``experiments/`` next to the pad source. Each
file is a self-contained Python module that exposes ``view()``.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

EXPERIMENTS_DIR = Path(__file__).resolve().parent.parent / "experiments"


@dataclass(frozen=True, slots=True)
class Experiment:
    name: str
    source: str


def list_experiments() -> tuple[Experiment, ...]:
    """Return all experiments sorted by name."""
    if not EXPERIMENTS_DIR.exists():
        return ()
    return tuple(
        Experiment(name=path.stem, source=path.read_text())
        for path in sorted(EXPERIMENTS_DIR.glob("*.py"))
    )


def load(name: str) -> Experiment | None:
    """Load a single experiment by name. Returns None if missing."""
    path = EXPERIMENTS_DIR / f"{name}.py"
    if not path.exists():
        return None
    return Experiment(name=name, source=path.read_text())


def save(name: str, source: str) -> Experiment:
    """Write an experiment to disk and return the saved record."""
    EXPERIMENTS_DIR.mkdir(parents=True, exist_ok=True)
    path = EXPERIMENTS_DIR / f"{name}.py"
    path.write_text(source)
    return Experiment(name=name, source=source)


def delete(name: str) -> bool:
    """Delete an experiment. Returns True if it existed."""
    path = EXPERIMENTS_DIR / f"{name}.py"
    if not path.exists():
        return False
    path.unlink()
    return True
