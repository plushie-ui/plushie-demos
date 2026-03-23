"""Crash test application.

Demonstrates plushie's crash resilience by providing buttons that
deliberately crash both the Python update/view layer and the Rust
renderer. A working counter proves the app keeps functioning through
all crashes.
"""

from __future__ import annotations

from dataclasses import dataclass, replace
from typing import Any

from plushie import App, ui
from plushie.events import Click

from crash_test.crasher import crasher, trigger_panic


@dataclass(frozen=True, slots=True)
class Model:
    """Application state."""

    count: int = 0
    error_count: int = 0
    last_error: str = ""
    update_crashes: int = 0
    view_crash_armed: bool = False


class CrashTestApp(App[Model]):
    """App that deliberately crashes in various ways to test recovery."""

    def init(self) -> Model:
        return Model()

    def update(self, model: Model, event: Any) -> Model | tuple[Model, Any]:
        match event:
            # -- Counter (proof of life) --
            case Click(id="inc"):
                return replace(model, count=model.count + 1)
            case Click(id="dec"):
                return replace(model, count=model.count - 1)

            # -- Python crash: update raises --
            case Click(id="crash-update"):
                raise RuntimeError("deliberate update crash")

            # -- Python crash: arm view crash --
            case Click(id="crash-view"):
                return replace(model, view_crash_armed=True)

            # -- Python crash: return None (unexpected value) --
            case Click(id="return-none"):
                return None  # type: ignore[return-value]

            # -- Rust crash: panic on render --
            case Click(id="panic-render"):
                return replace(model, view_crash_armed=False)

            # -- Rust crash: panic via command --
            case Click(id="panic-command"):
                return model, trigger_panic("crash-widget")

            case _:
                return model

    def view(self, model: Model) -> dict:
        if model.view_crash_armed:
            raise RuntimeError("deliberate view crash")

        status_text = (
            f"Errors: {model.error_count} | Last: {model.last_error or 'none'}"
        )

        return ui.window(
            "main",
            ui.column(
                # -- Header --
                ui.text("title", "Crash Test Demo", size=24),
                ui.text("status", status_text, size=12),
                ui.text("alive", "App is alive", size=14, color="#4caf50"),
                ui.rule(),
                # -- Recovery proof: working counter --
                ui.column(
                    ui.text("counter-label", "Recovery Proof Counter", size=16),
                    ui.row(
                        ui.button("dec", "-"),
                        ui.text("counter-value", str(model.count), size=20),
                        ui.button("inc", "+"),
                        spacing=10,
                        align_y="center",
                    ),
                    id="counter-section",
                    spacing=8,
                    padding=10,
                ),
                ui.rule(),
                # -- Python crash buttons --
                ui.column(
                    ui.text("py-label", "Python-side crashes", size=16),
                    ui.row(
                        ui.button("crash-update", "Crash update"),
                        ui.button("crash-view", "Crash view"),
                        ui.button("return-none", "Return None"),
                        spacing=10,
                    ),
                    id="python-crashes",
                    spacing=8,
                    padding=10,
                ),
                ui.rule(),
                # -- Rust crash buttons (need extension binary) --
                ui.column(
                    ui.text(
                        "rs-label", "Rust-side crashes (extension binary)", size=16
                    ),
                    ui.row(
                        ui.button("panic-render", "Panic render"),
                        ui.button("panic-command", "Panic command"),
                        spacing=10,
                    ),
                    id="rust-crashes",
                    spacing=8,
                    padding=10,
                ),
                ui.rule(),
                # -- Crasher widget (Rust extension, absent with stock binary) --
                crasher(
                    "crash-widget",
                    message="Crasher widget is alive",
                    panic_on_render=False,
                ),
                spacing=15,
                padding=20,
                width="fill",
            ),
            title="Crash Test",
            size=(500, 600),
        )
