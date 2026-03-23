# Notes

Note-taking app demonstrating custom message types, multi-view routing,
undo/redo, search filtering, and keyboard shortcuts. Pure Gleam widgets
only -- no Rust extension needed, runs with the stock plushie binary.

## Prerequisites

- [Gleam](https://gleam.run/) (v1.0+)
- [Erlang/OTP](https://www.erlang.org/) (26+)
- [plushie](https://github.com/plushie-ui/plushie) renderer binary

## Setup

```bash
gleam deps download
gleam run -m plushie/download
```

## Run

```bash
gleam run -m notes
```

## Test

```bash
gleam test
```

81 tests covering the message mapping, model helpers, update logic
(navigation, create, delete, edit, undo, redo, search), view structure,
and a full user journey.

## How it works

### Custom message types

This is the only demo that uses `app.application()` with a custom `Msg`
type instead of `app.simple()` with raw `Event`. The difference matters:

```gleam
// app.simple -- matches raw events by widget ID (stringly typed)
case event {
  WidgetClick(id: "delete", ..) -> ...

// app.application -- matches typed domain messages
case msg {
  DeleteNote(id) -> ...
```

With a custom `Msg` type, the compiler tells you if you forget to handle
a message. Button clicks and keyboard shortcuts converge into the same
variant. Each action has exactly one handler in `update`.

### The on_event mapping

`msg.gleam` contains the `Msg` type (the app's vocabulary) and the
`on_event` function that maps raw UI events to messages:

```gleam
KeyPress(key: "n", modifiers: Modifiers(ctrl: True, ..), ..) -> CreateNote
WidgetClick(id: "create", ..) -> CreateNote
```

Both `Ctrl+N` and the "New" button produce `CreateNote`. The
`captured: False` guard ensures shortcuts don't fire while typing in
text fields.

### Undo/redo

The editor pushes the current note state onto an undo stack before each
edit. Undo pops the stack and pushes the current state onto the redo
stack. A new edit clears the redo stack. The undo stack is bounded at 50
entries.

### Keyboard shortcuts

A context-aware hint bar at the bottom shows available shortcuts:

**List view:** `Ctrl+N` New note, `/` Search

**Editor view:** `Esc` Back, `Ctrl+Z` Undo, `Ctrl+Shift+Z` Redo

The hint bar changes automatically when switching views.

### Project structure

```
src/
  notes.gleam               # Entry point (main)
  notes/
    msg.gleam               # Msg type + on_event mapping
    model.gleam             # Note, View, Model types + init + helpers
    app.gleam               # update, view, subscribe, app()
test/
  notes/
    msg_test.gleam          # Event-to-message mapping tests
    model_test.gleam        # Model helpers and init tests
    app_test.gleam          # Update, view, filter, journey tests
bin/
  preflight                 # CI checks (format, build, test)
```

Read the modules in order: **msg** (what can this app do?), **model**
(what does the state look like?), **app** (how does it work?).
