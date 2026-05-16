# Notes

A notes app built with [Plushie](https://github.com/plushie-ui/plushie-ruby)
demonstrating pure Ruby widgets and state helpers.

No Rust required; every custom widget is a pure Ruby composite.

## Features

- **Route** - list and editor views with navigation stack
- **Selection** - multi-select notes with checkboxes
- **DataQuery** - search and sort notes
- **Undo** - undo/redo content changes in the editor
- **Keyboard shortcuts** - Ctrl+N, Ctrl+Z, Ctrl+Y, Escape
- **Pure Ruby widgets** - NoteCard, Toolbar, ShortcutBar

## Prerequisites

- Ruby 3.2+
- Plushie binary: `rake plushie:download`

No Rust toolchain needed.

## Setup

    bundle install
    rake plushie:download

## Run

    bundle exec ruby lib/notes.rb

Renderer-parent startup for embedding and debug proofs:

    plushie-renderer --listen --exec-bin bundle --exec-arg exec --exec-arg ruby --exec-arg bin/connect

## Test

    bundle exec rake test

## Standalone package

The practical first Ruby path in this repo is a directory-runtime
payload: the active Ruby prefix, runtime gems, app files, and renderer
are assembled into one payload for the shared launcher. Tebako is a later
candidate once a project config and native-extension story are settled;
it is not required for this demo.

Build the payload and package manifest:

    PLUSHIE_BINARY_PATH=/path/to/plushie-renderer ./scripts/package.sh

The script is a thin wrapper around `Plushie::Package`, provided by the
Ruby SDK. It writes `dist/payload.tar.zst` and
`dist/plushie-package.toml`. Build the standalone launcher with the
strict tool gate:

    bin/plushie package portable --manifest dist/plushie-package.toml

`just package-postcheck` validates the manifest and launcher
extraction/cache behavior. `just package-release-check` is the strict
release-oriented proof that also runs the generated host-first launcher
under display support and writes a report with the payload archive size
from the manifest and the generated executable size. The SDK helper
dereferences runtime symlinks before archiving and rejects symlinks,
hard links, and special files.

This is a prototype runtime bundle, not a minimized Ruby distribution.
It copies the active Ruby prefix and then installs production gems into
the payload. Obvious pruning is intentionally limited to dependency
groups and local SDK repository metadata so the demo does not remove
runtime files, native extensions, licenses, or notices that the active
Ruby installation may need.

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
