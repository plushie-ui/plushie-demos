"""Live dashboard with sparkline charts for simulated system metrics.

Demonstrates:
- Native widget extension (sparkline rendered in Rust/iced)
- Timer subscriptions for live data updates
- Render-only extension (no commands or events)

Run::

    python -m plushie run sparkline_dashboard.app:Dashboard
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass, replace

import plushie
from plushie import ui
from plushie.events import Click, TimerTick
from plushie.subscriptions import Subscription

from sparkline_dashboard.sparkline import sparkline

MAX_SAMPLES = 100


def cpu_sample(tick: int) -> float:
    """Generate a simulated CPU sample with sine-wave variation."""
    base = 30 + random.random() * 39
    wave = math.sin(tick * 0.1) * 15
    return round(base + wave, 1)


def mem_sample(tick: int) -> float:
    """Generate a simulated memory sample that oscillates between 20-100."""
    raw = 40 + random.random() * 9 + tick * 0.05
    value = (raw % 80) + 20
    return round(value, 1)


def net_sample() -> float:
    """Generate a simulated network sample (random 0-100)."""
    return round(random.random() * 100)


def _cap_samples(samples: tuple[float, ...], value: float) -> tuple[float, ...]:
    """Append a value and cap at MAX_SAMPLES."""
    return (*samples, value)[-MAX_SAMPLES:]


@dataclass(frozen=True, slots=True)
class Model:
    """Application state for the sparkline dashboard."""

    cpu_samples: tuple[float, ...] = ()
    mem_samples: tuple[float, ...] = ()
    net_samples: tuple[float, ...] = ()
    running: bool = True
    tick_count: int = 0


def _sparkline_card(
    id: str,
    label: str,
    data: tuple[float, ...],
    color: str,
    fill: bool,
) -> dict:
    """Build a sparkline card with a label, current value, and chart."""
    header_children = [
        ui.text(f"{id}_label", label, size=14, color="#666666"),
    ]
    if data:
        header_children.append(
            ui.text(f"{id}_value", str(data[-1]), size=14, color=color),
        )

    return ui.container(
        f"{id}_card",
        ui.column(
            ui.row(*header_children, spacing=8),
            sparkline(
                f"{id}_spark",
                data=data,
                color=color,
                stroke_width=2.0,
                fill=fill,
                height=60.0,
            ),
            spacing=4,
        ),
        padding=12,
    )


class Dashboard(plushie.App[Model]):
    """Sparkline dashboard app."""

    def init(self) -> Model:
        return Model()

    def update(self, model: Model, event: object) -> Model:
        match event:
            case TimerTick(tag="sample") if model.running:
                return replace(
                    model,
                    cpu_samples=_cap_samples(
                        model.cpu_samples, cpu_sample(model.tick_count)
                    ),
                    mem_samples=_cap_samples(
                        model.mem_samples, mem_sample(model.tick_count)
                    ),
                    net_samples=_cap_samples(model.net_samples, net_sample()),
                    tick_count=model.tick_count + 1,
                )

            case Click(id="toggle_running"):
                return replace(model, running=not model.running)

            case Click(id="clear"):
                return replace(
                    model,
                    cpu_samples=(),
                    mem_samples=(),
                    net_samples=(),
                    tick_count=0,
                )

            case _:
                return model

    def subscribe(self, model: Model) -> list[Subscription]:
        if model.running:
            return [Subscription.every(500, "sample")]
        return []

    def view(self, model: Model) -> dict:
        return ui.window(
            "main",
            ui.column(
                ui.text("title", "System Monitor", size=24),
                # Controls
                ui.row(
                    ui.button(
                        "toggle_running",
                        "Pause" if model.running else "Resume",
                    ),
                    ui.button("clear", "Clear"),
                    ui.text(
                        "status",
                        f"{len(model.cpu_samples)} samples",
                        size=14,
                        color="#888888",
                    ),
                    spacing=12,
                ),
                # Sparkline charts
                _sparkline_card(
                    "cpu",
                    "CPU Usage",
                    model.cpu_samples,
                    color="#4CAF50",
                    fill=True,
                ),
                _sparkline_card(
                    "mem",
                    "Memory",
                    model.mem_samples,
                    color="#2196F3",
                    fill=True,
                ),
                _sparkline_card(
                    "net",
                    "Network I/O",
                    model.net_samples,
                    color="#FF9800",
                    fill=False,
                ),
                padding=20,
                spacing=16,
            ),
            title="Sparkline Dashboard",
        )


if __name__ == "__main__":
    plushie.run(Dashboard)
