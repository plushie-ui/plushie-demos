# PlushiePad

Live-coding scratchpad for Plushie experiments. Write Elixir view
code in a text editor, save to compile, and see the rendered preview
side by side. Manages a library of experiment files with search,
multi-select, undo/redo, import/export, and a detachable preview
window.

Demonstrates:

- `Plushie.Undo` - undo/redo for editor content with coalescing
- `Plushie.Route` - navigation between editor and browser views
- `Plushie.Selection` - multi-select experiments for bulk delete
- `Plushie.Data` - search/filter experiment files
- `Plushie.Effect` - file dialogs (import/export) and clipboard
- Pure Elixir composite widgets (`use Plushie.Widget`)
  - `EventLog` - stateful widget with internal toggle (hide/show)
  - `FileList` - sidebar file browser with search and selection
- Canvas-based save button with gradient, hover, and pressed styles
- Multi-window support (detached preview)
- Auto-save with subscription-based timers
- Keyboard shortcuts (Ctrl+S save, Ctrl+Z undo, Ctrl+Shift+Z redo,
  Ctrl+N new, Escape dismiss errors)
- Dynamic compilation and preview of user-written view code

## Prerequisites

- [Elixir](https://elixir-lang.org/) (1.15+)
- [Erlang/OTP](https://www.erlang.org/) (26+)
- [plushie-elixir](https://github.com/plushie-ui/plushie-elixir) SDK
  (path dependency at `../../../plushie-elixir`)

## Setup

```sh
mix deps.get
mix plushie.download
```

## Run

```sh
mix plushie.gui PlushiePad
```

The editor opens with starter code. Edit, press Save (or Ctrl+S),
and the preview panel updates. Create new experiments via the name
input at the bottom, browse them in the sidebar, or detach the
preview into its own window.

A bundled counter app is also included:

```sh
mix plushie.gui PlushiePad.Hello
```

## Test

```sh
mix test
```

## Project structure

```
lib/
  plushie_pad.ex               # Main app (init/update/view/subscribe)
  plushie_pad/
    hello.ex                   # Minimal counter app (bundled example)
    event_log.ex               # Stateful widget: collapsible event log
    file_list.ex               # Stateless widget: sidebar file browser
    design.ex                  # Design tokens (spacing, font sizes, styles)
    shared.ex                  # GenServer for collaborative shared state
test/
  test_helper.exs
  pad_test.exs                 # Full app test suite
  hello_test.exs               # Counter app tests
  event_log_test.exs           # EventLog widget tests
  shared_test.exs              # Shared state GenServer tests
priv/
  experiments/                 # User-created experiment files (gitignored)
```

## How it works

### Editor and preview

The main view splits into three columns: a file sidebar, a text
editor, and a preview pane. Editing updates the source and tracks
changes with `Plushie.Undo`. Saving compiles the source via
`Code.compile_string/1`, calls the module's `view/0`, and renders
the returned tree in the preview pane. Compilation errors display
inline instead of the preview.

### File management

Experiments are stored as `.ex` files in `priv/experiments/`. The
sidebar lists them with search filtering via `Plushie.Data.query/2`.
Multi-select with checkboxes enables bulk deletion. Switching files
auto-saves the current one and resets the undo stack.

### Custom widgets

Two pure Elixir widgets built with `use Plushie.Widget`:

- **EventLog** - stateful widget with an internal `expanded` toggle.
  Shows the last 20 unhandled events in a scrollable log. Clicking
  the toggle button updates widget-internal state without going
  through the app's `update/2`.
- **FileList** - stateless composite. Renders the file list with
  search, selection checkboxes, and per-file select/delete buttons.
  All events bubble up to the app via scoped IDs.

### Canvas save button

The save button is a canvas-based widget demonstrating interactive
canvas elements: gradient fill, hover/pressed styles, cursor
changes, accessibility attributes, and click handling via scoped
canvas element events.

### Multi-window

Clicking "Detach" opens the preview in a separate window. The
`WindowEvent` for close on the detached window re-attaches the
preview to the main window.

### Auto-save

Toggling the auto-save checkbox starts a 1-second subscription
timer. When dirty, the timer fires and saves/compiles automatically.
The subscription is declared reactively in `subscribe/1` -- it only
runs when both `auto_save` and `dirty` are true.
