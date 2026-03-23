# Notes

Notes app demonstrating pure Elixir widgets and state helpers. No
Rust extensions, no custom binary -- everything is Elixir.

Demonstrates:

- `Plushie.Route` -- stack-based navigation between list and editor
- `Plushie.Selection` -- multi-select notes with checkboxes
- `Plushie.Undo` -- undo/redo for editor content with coalescing
- `Plushie.Data` -- search across title+content, sort by date/name
- Pure Elixir composite widgets (`use Plushie.Extension, :widget`)
- Keyboard shortcuts with a context-aware hint bar
- Pattern matching in `update/2` as a routing table

See also the [Ruby](../../ruby/notes/) version of this demo.

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
mix plushie.gui Notes.App
```

## Test

```sh
mix test
```

86 tests covering the app logic, all three widgets, navigation,
CRUD, undo/redo, search/sort, keyboard shortcuts, and view tree
structure.

## Project structure

```
lib/
  notes.ex                     # Top-level module docs
  notes/
    app.ex                     # Plushie.App (init/update/view/subscribe)
    note.ex                    # Note struct
    widgets/
      note_card.ex             # Composite: note list item with checkbox
      toolbar.ex               # Composite: top bar with title + actions
      shortcut_bar.ex          # Composite: keyboard shortcut hints
test/
  test_helper.exs
  notes/
    app_test.exs               # Full app test suite
    note_test.exs              # Note struct tests
    widgets/
      note_card_test.exs       # NoteCard widget tests
      toolbar_test.exs         # Toolbar widget tests
      shortcut_bar_test.exs    # ShortcutBar widget tests
```

## How it works

### Two views

The app has two routes: `/list` (note list with search, sort,
multi-select) and `/editor` (title + content editing with undo).
`Plushie.Route` manages the navigation stack with params.

### State helpers

Each helper is a pure data structure -- no processes, no side effects.
They compose naturally in the model:

- **Route**: `push("/editor", %{note_id: id})` / `pop()` / `current()`
- **Selection**: `toggle(sel, id)` / `selected?(sel, id)` / `clear(sel)`
- **Undo**: `new(content)` / `apply(undo, command)` / `undo(u)` / `redo(u)`
- **Data**: `query(records, search: ..., sort: ...)`

### Custom widgets

Three pure Elixir composites built with `use Plushie.Extension, :widget`.
Each declares props and implements `render/2`:

- **Toolbar** -- title, optional back button, dynamic action buttons
- **NoteCard** -- checkbox for selection, button for opening, preview text
- **ShortcutBar** -- context-aware hints with key/action visual distinction

No Rust, no binary rebuild. These work with any precompiled binary.

### Keyboard shortcuts

Subscribed via `Plushie.Subscription.on_key_press/1`. The shortcut bar
at the bottom of each view shows what's available in context:

- **List view**: `Ctrl+N` new
- **List view (items selected)**: `Esc` deselect, `Ctrl+N` new
- **Editor**: `Esc` back, `Ctrl+Z` undo (when available),
  `Ctrl+Y` redo (when available)

Escape is context-dependent: in the editor it navigates back, in the
list it clears selection (if any) then search (if any).
