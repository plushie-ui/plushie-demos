"""Main pad app: sidebar + editor + preview + toolbar + event log.

The pad follows the teaching arc in the plushie-python guides
(chapters 3 onward). Each chapter layers a new capability on top of
the previous one.
"""

from __future__ import annotations

from dataclasses import dataclass, field, replace
from typing import Any

import plushie
from plushie import Command, Subscription, ui
from plushie.events import (
    Click,
    Input,
    KeyEvent,
    Select,
    Submit,
    TimerTick,
)

from plushie_pad import compile as pad_compile
from plushie_pad import experiments as pad_experiments


@dataclass(frozen=True, slots=True)
class EventLogEntry:
    kind: str
    detail: str


@dataclass(frozen=True, slots=True)
class Model:
    experiments: tuple[pad_experiments.Experiment, ...] = ()
    selected: str | None = None
    editor_source: str = ""
    last_saved_source: str = ""
    preview_error: pad_compile.CompileError | None = None
    event_log: tuple[EventLogEntry, ...] = ()
    autosave: bool = False
    dirty: bool = False


def _ensure_default_experiment() -> None:
    if not pad_experiments.list_experiments():
        pad_experiments.save(
            "hello",
            (
                "from plushie import ui\n\n"
                "\n"
                "def view():\n"
                '    return ui.column(\n'
                '        ui.text("greeting", "Hello, Plushie!", size=24),\n'
                '        ui.button("btn", "Click Me"),\n'
                "        padding=16,\n"
                "        spacing=8,\n"
                "    )\n"
            ),
        )


class Pad(plushie.App[Model]):
    def init(self) -> Model:
        _ensure_default_experiment()
        exps = pad_experiments.list_experiments()
        selected = exps[0].name if exps else None
        source = exps[0].source if exps else ""
        return Model(
            experiments=exps,
            selected=selected,
            editor_source=source,
            last_saved_source=source,
        )

    def update(
        self, model: Model, event: Any
    ) -> Model | tuple[Model, Command | list[Command]]:
        match event:
            case Click(id=exp_id) if exp_id.startswith("select-"):
                name = exp_id.removeprefix("select-")
                exp = pad_experiments.load(name)
                if exp is None:
                    return model
                return replace(
                    model,
                    selected=exp.name,
                    editor_source=exp.source,
                    last_saved_source=exp.source,
                    dirty=False,
                    preview_error=None,
                )

            case Input(id="editor", value=source):
                return replace(
                    model,
                    editor_source=source,
                    dirty=source != model.last_saved_source,
                )

            case Click(id="save"):
                return _save(model)

            case Click(id="new"):
                return _new_experiment(model)

            case Submit(id="new-name", value=name):
                return _create_named(model, name.strip())

            case Click(id="autosave"):
                return replace(model, autosave=not model.autosave)

            case TimerTick(tag="autosave"):
                if model.autosave and model.dirty:
                    return _save(model)
                return model

            case KeyEvent(type="press", key="s", modifiers=mods) if mods.command:
                return _save(model)

            case _:
                return model

    def view(self, model: Model) -> dict[str, Any]:
        return ui.window(
            "pad",
            ui.row(
                _sidebar(model),
                _main_pane(model),
                _event_log(model),
                spacing=0,
                width="fill",
                height="fill",
            ),
            title="Plushie Pad",
            size=(1100, 700),
        )

    def subscribe(self, model: Model) -> list[Subscription]:
        subs: list[Subscription] = [Subscription.on_key_press()]
        if model.autosave:
            subs.append(Subscription.every(1500, "autosave"))
        return subs


def _save(model: Model) -> Model:
    if model.selected is None:
        return model
    exp = pad_experiments.save(model.selected, model.editor_source)
    exps = pad_experiments.list_experiments()
    return replace(
        model,
        experiments=exps,
        last_saved_source=exp.source,
        dirty=False,
        event_log=_log(model.event_log, "saved", exp.name),
    )


def _new_experiment(model: Model) -> Model:
    return replace(model, selected=None, editor_source="", dirty=True)


def _create_named(model: Model, name: str) -> Model:
    if not name:
        return model
    exp = pad_experiments.save(name, model.editor_source)
    exps = pad_experiments.list_experiments()
    return replace(
        model,
        experiments=exps,
        selected=name,
        last_saved_source=exp.source,
        dirty=False,
    )


def _log(
    log: tuple[EventLogEntry, ...], kind: str, detail: str
) -> tuple[EventLogEntry, ...]:
    entry = EventLogEntry(kind=kind, detail=detail)
    trimmed = (entry, *log)[:50]
    return trimmed


def _sidebar(model: Model) -> dict[str, Any]:
    return ui.container(
        "sidebar",
        ui.column(
            ui.text("sidebar-title", "Experiments", size=14),
            *(
                ui.button(
                    f"select-{exp.name}",
                    exp.name,
                    style="primary" if exp.name == model.selected else None,
                )
                for exp in model.experiments
            ),
            ui.rule(),
            ui.button("new", "+ New", style="secondary"),
            padding=12,
            spacing=8,
            width=220,
        ),
        width=220,
        height="fill",
    )


def _main_pane(model: Model) -> dict[str, Any]:
    return ui.column(
        _toolbar(model),
        _editor(model),
        _preview(model),
        spacing=0,
        width="fill",
        height="fill",
    )


def _toolbar(model: Model) -> dict[str, Any]:
    return ui.row(
        ui.button("save", "Save" + (" *" if model.dirty else "")),
        ui.button("autosave", "Autosave: On" if model.autosave else "Autosave: Off"),
        padding=8,
        spacing=8,
    )


def _editor(model: Model) -> dict[str, Any]:
    return ui.text_editor(
        "editor",
        model.editor_source,
        width="fill",
        height={"fill_portion": 3},
        highlight_syntax="python",
    )


def _preview(model: Model) -> dict[str, Any]:
    if model.preview_error is not None:
        return ui.container(
            "preview",
            ui.text("error", model.preview_error.message, color="#d32f2f"),
            padding=12,
            width="fill",
            height={"fill_portion": 2},
        )
    namespace, err = pad_compile.compile_experiment(
        model.selected or "unnamed", model.editor_source
    )
    if err is not None or namespace is None:
        return ui.container(
            "preview",
            ui.text("error", err.message if err else "compile failed", color="#d32f2f"),
            padding=12,
            width="fill",
            height={"fill_portion": 2},
        )
    node, call_err = pad_compile.call_view(namespace)
    if call_err is not None or node is None:
        return ui.container(
            "preview",
            ui.text(
                "error",
                call_err.message if call_err else "view() failed",
                color="#d32f2f",
            ),
            padding=12,
            width="fill",
            height={"fill_portion": 2},
        )
    return ui.container(
        "preview",
        node,
        padding=12,
        width="fill",
        height={"fill_portion": 2},
    )


def _event_log(model: Model) -> dict[str, Any]:
    return ui.container(
        "log",
        ui.column(
            ui.text("log-title", "Event log", size=14),
            *(
                ui.text(f"log-{idx}", f"{entry.kind}: {entry.detail}")
                for idx, entry in enumerate(model.event_log)
            ),
            padding=8,
            spacing=4,
        ),
        width=240,
        height="fill",
    )
