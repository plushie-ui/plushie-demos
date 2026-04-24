"""Runtime compilation of experiment source.

An experiment is a Python module that exposes a ``view()`` callable
returning a plushie node. The pad compiles source at save time via
``compile()`` + ``exec()`` and caches code objects by content hash.
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from typing import Any

_cache: dict[str, Any] = {}


@dataclass(frozen=True, slots=True)
class CompileError:
    """A compilation or execution error from an experiment."""

    message: str
    phase: str  # "compile" or "exec"


def compile_experiment(
    name: str, source: str
) -> tuple[dict[str, Any] | None, CompileError | None]:
    """Compile and execute ``source`` as an experiment module.

    Returns ``(namespace, None)`` on success, ``(None, error)`` on
    failure. ``namespace`` is the module-level dict containing the
    experiment's top-level bindings (notably ``view``).
    """
    key = hashlib.sha256(source.encode()).hexdigest()
    if key in _cache:
        return _cache[key], None

    try:
        code = compile(source, f"<experiment:{name}>", "exec")
    except SyntaxError as exc:
        return None, CompileError(message=str(exc), phase="compile")

    namespace: dict[str, Any] = {"__name__": f"experiment_{name}"}
    try:
        exec(code, namespace)
    except Exception as exc:  # noqa: BLE001 - experiments can raise anything
        return None, CompileError(message=f"{type(exc).__name__}: {exc}", phase="exec")

    _cache[key] = namespace
    return namespace, None


def call_view(namespace: dict[str, Any]) -> tuple[Any, CompileError | None]:
    """Invoke ``namespace["view"]()`` and return the rendered node."""
    view = namespace.get("view")
    if not callable(view):
        return None, CompileError(
            message="experiment must define a top-level view() callable",
            phase="exec",
        )
    try:
        return view(), None
    except Exception as exc:  # noqa: BLE001
        return None, CompileError(message=f"{type(exc).__name__}: {exc}", phase="exec")


def clear_cache() -> None:
    """Reset the compile cache. Used in tests."""
    _cache.clear()
