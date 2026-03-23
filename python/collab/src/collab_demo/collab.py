"""Shared collab app definition used by all demo modes.

Follows the Elm architecture: init/update/view with immutable model
updates. The same code runs in native desktop, WebSocket shared-state,
and SSH modes.

In collaborative modes (WebSocket, SSH), ``name``, ``notes``, and
``count`` are shared across all connected clients. The ``dark_mode``
toggle is per-client -- each user picks their own theme. The ``status``
field is set externally by the server adapter to show the current
connection count.
"""

from __future__ import annotations

from dataclasses import dataclass, replace
from typing import Any

from plushie import App, ui
from plushie.events import Click, Input, Toggle


@dataclass(frozen=True, slots=True)
class Model:
    """Application state for the collab demo."""

    name: str = ""
    notes: str = ""
    count: int = 0
    dark_mode: bool = False
    status: str = ""


class Collab(App[Model]):
    """Collaborative scratchpad app."""

    def init(self) -> Model:
        """Return the initial model with empty fields and running state."""
        return Model()

    def update(self, model: Model, event: Any) -> Model:
        """Handle widget events: counter, text inputs, theme toggle."""
        match event:
            case Click(id="inc"):
                return replace(model, count=model.count + 1)
            case Click(id="dec"):
                return replace(model, count=model.count - 1)
            case Input(id="name", value=value):
                return replace(model, name=value)
            case Input(id="notes", value=value):
                return replace(model, notes=value)
            case Toggle(id="theme", value=checked):
                return replace(model, dark_mode=checked)
            case _:
                return model

    def view(self, model: Model) -> dict[str, Any]:
        """Render the scratchpad UI: header, inputs, counter, theme toggle."""
        theme = "dark" if model.dark_mode else "light"

        return ui.window(
            "main",
            ui.themer(
                "theme-root",
                ui.container(
                    "bg",
                    ui.column(
                        ui.text("header", "Plushie Demo", size=24),
                        ui.text("status", model.status),
                        ui.text_input("name", model.name, placeholder="Your name"),
                        ui.row(
                            ui.button("dec", "-"),
                            ui.text("count", f"Count: {model.count}"),
                            ui.button("inc", "+"),
                            id="counter-row",
                            spacing=8,
                        ),
                        ui.checkbox("theme", model.dark_mode, label="Dark mode"),
                        ui.text_input(
                            "notes",
                            model.notes,
                            placeholder="Shared notes...",
                            width="fill",
                        ),
                        padding=20,
                        spacing=16,
                        width="fill",
                    ),
                    width="fill",
                    height="fill",
                ),
                theme=theme,
            ),
            title="Plushie Demo",
            size=[500, 450],
        )

    def settings(self) -> dict[str, Any]:
        """Rate-limit coalescable events to 30/sec."""
        return {"default_event_rate": 30}
