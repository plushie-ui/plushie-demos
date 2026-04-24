# Plushie Pad (Python)

A live Python experiment editor. The pad dogfoods the Plushie
Python SDK: type code in the editor, hit save, and the pad compiles
and renders the result in the preview pane. Each experiment is a
Python module exposing `view()`.

## Why runtime compilation works in Python

`compile(source, "<experiment>", "exec")` plus `exec(code, ns)` is
standard library. No FFI or external toolchain. The pad caches
compiled code objects by content hash so unchanged experiments do
not recompile.

Experiments import the public SDK:

```python
from plushie import ui

def view():
    return ui.column(
        ui.text("greeting", "Hello, Plushie!", size=24),
        ui.button("btn", "Click Me"),
        padding=16,
        spacing=8,
    )
```

## Layout

```
plushie_pad/
  __init__.py
  __main__.py          # python -m plushie_pad entry point
  app.py               # main Elm loop (model, update, view, subscribe)
  compile.py           # compile() + exec() wrapper with caching
  experiments.py       # list, load, save, delete on experiments/
experiments/
  hello.py             # starter experiment
tests/
  test_app.py          # AppFixture-driven pad tests
pyproject.toml
preflight              # local CI mirror
```

## Running

```bash
pip install -e .
python -m plushie download
python -m plushie_pad
```

## Status

Work in progress. The source here lays out the pad's architecture
as described in the plushie-python guides. Some helpers
(`state.begin_transaction` for nested edits, `text_editor.placeholder`
styling) may require minor SDK iteration; see
`~/plushie-python-docs/callouts.md` and
`~/projects/plushie-sdk-parity/follow-up.md` for known gaps.

The pad will build once the SDK fills in what the guides assume. In
the meantime it serves as a reference for guide authors: the file
layout and module boundaries match what the guides teach.
