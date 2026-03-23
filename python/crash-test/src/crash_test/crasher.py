"""Crasher extension definition and builder functions.

Defines the native crasher widget: a simple widget that can be told to
panic on render or via command, exercising the renderer's crash recovery.
"""

from __future__ import annotations

from plushie.commands import Command
from plushie.extension import (
    CommandDef,
    ExtensionDef,
    PropDef,
    build_command,
    build_node,
)

crasher_def = ExtensionDef(
    kind="crasher",
    rust_crate="native/crasher",
    rust_constructor="crasher::CrasherExtension::new()",
    props=[
        PropDef("message", "string"),
        PropDef("panic_on_render", "bool"),
    ],
    commands=[
        CommandDef("panic"),
    ],
)


def crasher(
    id: str,
    *,
    message: str = "Crasher widget (alive)",
    panic_on_render: bool = False,
) -> dict:
    """Build a crasher widget node.

    Args:
        id: Unique widget identifier.
        message: Display message when not panicking.
        panic_on_render: If True, the Rust side panics during render.
    """
    props: dict = {
        "message": message,
        "panic_on_render": panic_on_render,
    }
    return build_node(crasher_def, id, props)


def trigger_panic(node_id: str) -> Command:
    """Send a panic command to the crasher widget."""
    return build_command(crasher_def, node_id, "panic")
