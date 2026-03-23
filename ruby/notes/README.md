# Notes

A notes app built with [Plushie](https://github.com/plushie-ui/plushie-ruby)
demonstrating pure Ruby widgets and state helpers.

No Rust required -- every custom widget is a pure Ruby composite.

## Features

- **Route** -- list and editor views with navigation stack
- **Selection** -- multi-select notes with checkboxes
- **DataQuery** -- search and sort notes
- **Undo** -- undo/redo content changes in the editor
- **Keyboard shortcuts** -- Ctrl+N, Ctrl+Z, Ctrl+Y, Escape
- **Pure Ruby widgets** -- NoteCard, Toolbar, ShortcutBar

## Prerequisites

- Ruby 3.2+
- Plushie binary: `rake plushie:download`

No Rust toolchain needed.

## Setup

    bundle install
    rake plushie:download

## Run

    bundle exec ruby lib/notes.rb

## Test

    bundle exec rake test

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| Ctrl+N | New note |
| Ctrl+Z | Undo (in editor) |
| Ctrl+Y | Redo (in editor) |
| Escape | Back / clear selection / clear search |

Shortcuts are shown in a context-aware bar at the bottom of each view.

## Project structure

```text
lib/
  notes.rb               # The app (init, update, view) (~200 lines)
  notes/
    note.rb              # Note data struct
  widgets/
    note_card.rb         # Card for note list (pure Ruby)
    toolbar.rb           # Top bar with title and actions (pure Ruby)
    shortcut_bar.rb      # Bottom hint bar (pure Ruby)
test/
  notes_test.rb          # App tests
  widgets/
    note_card_test.rb    # NoteCard widget tests
    toolbar_test.rb      # Toolbar widget tests
    shortcut_bar_test.rb # ShortcutBar widget tests
```
