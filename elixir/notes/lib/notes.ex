defmodule Notes do
  @moduledoc """
  Notes app -- pure Elixir widgets and state helpers, no Rust required.

  A full-featured notes editor demonstrating how to compose multiple
  Plushie SDK features into a real application. Everything is pure
  Elixir -- no native extensions, no custom binary build.

  ## State helpers used

  - `Plushie.Route` -- stack-based navigation between list and editor
  - `Plushie.Selection` -- multi-select notes with checkboxes
  - `Plushie.Undo` -- undo/redo for editor content with coalescing
  - `Plushie.Data` -- search across title+content, sort by date/name

  ## Custom widgets

  Three pure Elixir composite widgets (no Rust):

  - `Notes.Widgets.NoteCard` -- note list item with checkbox, title, preview
  - `Notes.Widgets.Toolbar` -- top bar with title, back button, actions
  - `Notes.Widgets.ShortcutBar` -- context-aware keyboard shortcut hints

  ## Running

      mix plushie.gui Notes.App
  """
end
