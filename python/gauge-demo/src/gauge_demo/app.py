"""Temperature monitor app using a native Rust gauge extension.

Demonstrates:
- Native widget extension (gauge rendered in Rust/iced)
- Extension commands (set_value, animate_to)
- Extension events (value_changed from Rust)
- Settings with extension_config

Run::

    python -m plushie run gauge_demo.app:TemperatureMonitor
"""

from __future__ import annotations

from dataclasses import dataclass, replace
from typing import Any

import plushie
from plushie import ui
from plushie.commands import Command
from plushie.events import Click, Slide, WidgetEvent

from gauge_demo.gauge import animate_gauge_to, gauge, set_gauge_value


def temperature_status(temp: float) -> str:
    """Human-readable status for a temperature reading."""
    if temp >= 80:
        return "Critical"
    if temp >= 60:
        return "Warning"
    if temp >= 40:
        return "Normal"
    return "Cool"


def status_color(temp: float) -> str:
    """Color corresponding to the temperature status."""
    if temp >= 80:
        return "#e74c3c"
    if temp >= 60:
        return "#e67e22"
    if temp >= 40:
        return "#27ae60"
    return "#3498db"


@dataclass(frozen=True, slots=True)
class Model:
    """Application state for the temperature monitor."""

    temperature: float = 20.0
    target_temp: float = 20.0
    history: tuple[float, ...] = (20.0,)


class TemperatureMonitor(plushie.App[Model]):
    """Temperature gauge demo app."""

    def init(self) -> Model:
        return Model()

    def update(self, model: Model, event: object) -> Model | tuple[Model, Command]:
        match event:
            case WidgetEvent(kind="value_changed", id="temp", data=data):
                new_temp = float(data["value"])
                return replace(
                    model,
                    temperature=new_temp,
                    history=(*model.history, new_temp),
                )

            case Slide(id="target", value=value):
                return (
                    replace(model, target_temp=value),
                    animate_gauge_to("temp", value),
                )

            case Click(id="reset"):
                return (
                    replace(model, target_temp=20.0),
                    set_gauge_value("temp", 20.0),
                )

            case Click(id="high"):
                return (
                    replace(model, target_temp=90.0),
                    set_gauge_value("temp", 90.0),
                )

            case _:
                return model

    def view(self, model: Model) -> dict:
        temp = model.temperature
        return ui.window(
            "main",
            ui.column(
                ui.text("title", "Temperature Monitor", size=24),
                gauge(
                    "temp",
                    value=temp,
                    min=0,
                    max=100,
                    color=status_color(temp),
                    label=f"{round(temp)}\u00b0C",
                    width=200,
                    height=200,
                    event_rate=30,
                ),
                ui.text(
                    "status",
                    f"Status: {temperature_status(temp)}",
                    color=status_color(temp),
                ),
                ui.text(
                    "reading",
                    f"Current: {round(temp)}\u00b0C | Target: {round(model.target_temp)}\u00b0C",
                ),
                ui.slider("target", (0, 100), model.target_temp),
                ui.row(
                    ui.button("reset", "Reset (20\u00b0C)"),
                    ui.button("high", "High (90\u00b0C)"),
                    spacing=8,
                ),
                ui.text(
                    "history",
                    f"History: {', '.join(f'{round(t)}\u00b0' for t in model.history)}",
                    size=12,
                    color="#999999",
                ),
                padding=24,
                spacing=16,
                align_x="center",
            ),
            title="Temperature Gauge",
        )

    def settings(self) -> dict[str, Any]:
        return {
            "extension_config": {
                "gauge": {"arcWidth": 8, "tickCount": 10},
            },
        }


if __name__ == "__main__":
    plushie.run(TemperatureMonitor)
