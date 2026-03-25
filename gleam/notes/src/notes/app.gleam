//// Elm loop and view for the notes app.
////
//// The `update` function pattern-matches on typed `Msg` variants
//// instead of raw widget events. This means every action has one
//// handler regardless of whether it was triggered by a button click
//// or a keyboard shortcut.
////
//// The `view` function dispatches to `list_view` or `editor_view`
//// based on the current route, with a context-aware shortcut hint
//// bar at the bottom.

import gleam/int
import gleam/list
import gleam/string
import notes/model.{
  type Model, type Note, type View, EditorView, ListView, Model, Note, find_note,
  push_undo, replace_note,
}
import notes/msg.{
  type Msg, CreateNote, DeleteNote, EditBody, EditTitle, FocusSearch, NoOp,
  OpenNote, Redo, SetSearch, ShowList, Undo,
}
import plushie/app
import plushie/command.{type Command}
import plushie/node.{type Node}
import plushie/prop/alignment
import plushie/prop/color
import plushie/prop/length
import plushie/prop/padding
import plushie/subscription.{type Subscription}
import plushie/ui
import plushie/widget/button
import plushie/widget/column
import plushie/widget/container
import plushie/widget/row
import plushie/widget/text as text_opts
import plushie/widget/text_editor
import plushie/widget/text_input
import plushie/widget/window

// -- Elm loop ----------------------------------------------------------------

/// Handle a domain message. Each `Msg` variant has exactly one handler.
pub fn update(model: Model, msg: Msg) -> #(Model, Command(Msg)) {
  case msg {
    ShowList -> #(
      Model(..model, current_view: ListView, undo_stack: [], redo_stack: []),
      command.none(),
    )

    OpenNote(id) -> #(
      Model(
        ..model,
        current_view: EditorView(id),
        undo_stack: [],
        redo_stack: [],
      ),
      command.none(),
    )

    CreateNote -> {
      let id = int.to_string(model.next_id)
      let note = Note(id:, title: "Untitled", body: "")
      #(
        Model(
          ..model,
          notes: [note, ..model.notes],
          current_view: EditorView(id),
          undo_stack: [],
          redo_stack: [],
          next_id: model.next_id + 1,
        ),
        command.none(),
      )
    }

    DeleteNote(id) -> #(
      Model(..model, notes: list.filter(model.notes, fn(n) { n.id != id })),
      command.none(),
    )

    EditTitle(new_title) ->
      edit_note(model, fn(note) { Note(..note, title: new_title) })

    EditBody(new_body) ->
      edit_note(model, fn(note) { Note(..note, body: new_body) })

    Undo ->
      case model.undo_stack, current_note(model) {
        [prev, ..rest], Ok(current) -> #(
          Model(
            ..model,
            notes: replace_note(model.notes, prev),
            undo_stack: rest,
            redo_stack: [current, ..model.redo_stack],
          ),
          command.none(),
        )
        _, _ -> #(model, command.none())
      }

    Redo ->
      case model.redo_stack, current_note(model) {
        [next, ..rest], Ok(current) -> #(
          Model(
            ..model,
            notes: replace_note(model.notes, next),
            redo_stack: rest,
            undo_stack: [current, ..model.undo_stack],
          ),
          command.none(),
        )
        _, _ -> #(model, command.none())
      }

    SetSearch(term) -> #(Model(..model, search: term), command.none())

    FocusSearch -> #(model, command.Focus("search"))

    NoOp -> #(model, command.none())
  }
}

/// Subscribe to key press events for keyboard shortcuts.
pub fn subscribe(_model: Model) -> List(Subscription) {
  [subscription.on_key_press("shortcuts")]
}

/// Build the app with custom message types and key subscriptions.
pub fn app() {
  app.application(model.init, update, view, msg.on_event)
  |> app.with_subscriptions(subscribe)
}

// -- View --------------------------------------------------------------------

/// Build the UI tree. Dispatches to list or editor view based on
/// the current route, with a shortcut hint bar at the bottom.
pub fn view(model: Model) -> Node {
  let content = case model.current_view {
    ListView -> list_view(model)
    EditorView(id) -> editor_view(model, id)
  }

  ui.window("main", [window.Title("Notes"), window.Size(600.0, 500.0)], [
    ui.column(
      "root",
      [
        column.Padding(padding.all(16.0)),
        column.Width(length.Fill),
        column.Height(length.Fill),
      ],
      [
        content,
        shortcut_bar(model.current_view),
      ],
    ),
  ])
}

// -- List view ---------------------------------------------------------------

fn list_view(model: Model) -> Node {
  let visible = filter_notes(model.notes, model.search)

  let note_rows = case visible {
    [] ->
      case model.search {
        "" -> [empty_state("No notes yet. Press Ctrl+N to create one.")]
        _ -> [empty_state("No notes match your search.")]
      }
    _ -> list.map(visible, note_row)
  }

  ui.column(
    "list-view",
    [column.Spacing(12), column.Width(length.Fill)],
    list.flatten([
      [
        ui.row("list-header", [row.Spacing(8)], [
          ui.text("list-title", "Notes", [text_opts.Size(24.0)]),
          ui.button_("create", "+ New"),
        ]),
        ui.text_input("search", model.search, [
          text_input.Placeholder("Search notes..."),
          text_input.Width(length.Fill),
        ]),
      ],
      note_rows,
    ]),
  )
}

fn note_row(note: Note) -> Node {
  let preview = case string.length(note.body) > 60 {
    True -> string.slice(note.body, 0, 60) <> "..."
    False ->
      case note.body {
        "" -> "Empty note"
        body -> body
      }
  }

  let assert Ok(muted) = color.from_hex("#888888")

  ui.row("row-" <> note.id, [row.Spacing(8), row.Width(length.Fill)], [
    ui.column(
      "info-" <> note.id,
      [column.Spacing(2), column.Width(length.Fill)],
      [
        ui.button("note-" <> note.id, note.title, [button.Width(length.Fill)]),
        ui.text("preview-" <> note.id, preview, [
          text_opts.Size(12.0),
          text_opts.Color(muted),
        ]),
      ],
    ),
    ui.button_("delete-" <> note.id, "x"),
  ])
}

fn empty_state(message: String) -> Node {
  let assert Ok(muted) = color.from_hex("#999999")
  ui.text("empty", message, [
    text_opts.Size(14.0),
    text_opts.Color(muted),
  ])
}

// -- Editor view -------------------------------------------------------------

fn editor_view(model: Model, note_id: String) -> Node {
  case find_note(model.notes, note_id) {
    Ok(note) -> {
      let has_undo = !list.is_empty(model.undo_stack)
      let has_redo = !list.is_empty(model.redo_stack)

      ui.column(
        "editor-view",
        [
          column.Spacing(12),
          column.Width(length.Fill),
          column.Height(length.Fill),
        ],
        [
          ui.row("editor-header", [row.Spacing(8)], [
            ui.button_("back", "Back"),
            ui.button("undo", "Undo", [button.Disabled(!has_undo)]),
            ui.button("redo", "Redo", [button.Disabled(!has_redo)]),
          ]),
          ui.text_input("title", note.title, [
            text_input.Placeholder("Note title"),
            text_input.Width(length.Fill),
            text_input.Size(20.0),
          ]),
          text_editor.new("body", note.body)
            |> text_editor.placeholder("Start writing...")
            |> text_editor.height(length.Fill)
            |> text_editor.build(),
        ],
      )
    }
    Error(_) ->
      // Note was deleted -- show fallback (shouldn't happen in normal flow)
      ui.text_("editor-missing", "Note not found.")
  }
}

// -- Shortcut bar ------------------------------------------------------------

fn shortcut_bar(current_view: View) -> Node {
  let hints = case current_view {
    ListView -> [
      shortcut_hint("ctrl-n", "Ctrl+N", "New note"),
      shortcut_hint("slash", "/", "Search"),
    ]
    EditorView(_) -> [
      shortcut_hint("esc", "Esc", "Back"),
      shortcut_hint("ctrl-z", "Ctrl+Z", "Undo"),
      shortcut_hint("ctrl-shift-z", "Ctrl+Shift+Z", "Redo"),
    ]
  }

  ui.row(
    "shortcut-bar",
    [row.Spacing(16), row.Padding(padding.xy(8.0, 0.0)), row.Width(length.Fill)],
    hints,
  )
}

fn shortcut_hint(id: String, key_label: String, action: String) -> Node {
  let assert Ok(badge_bg) = color.from_hex("#f0f0f0")
  let assert Ok(hint_color) = color.from_hex("#666666")

  ui.row(id <> "-hint", [row.Spacing(4), row.AlignY(alignment.Center)], [
    ui.container(
      id <> "-badge",
      [
        container.Padding(padding.xy(2.0, 6.0)),
        container.BgColor(badge_bg),
      ],
      [
        ui.text(id <> "-key", key_label, [text_opts.Size(11.0)]),
      ],
    ),
    ui.text(id <> "-action", action, [
      text_opts.Size(11.0),
      text_opts.Color(hint_color),
    ]),
  ])
}

// -- Helpers -----------------------------------------------------------------

/// Filter notes by search term (case-insensitive title match).
pub fn filter_notes(notes: List(Note), search: String) -> List(Note) {
  case search {
    "" -> notes
    term -> {
      let lower = string.lowercase(term)
      list.filter(notes, fn(note) {
        string.contains(string.lowercase(note.title), lower)
      })
    }
  }
}

/// Get the note currently being edited, if in editor view.
fn current_note(model: Model) -> Result(Note, Nil) {
  case model.current_view {
    EditorView(id) -> find_note(model.notes, id)
    ListView -> Error(Nil)
  }
}

/// Edit the current note: push to undo, apply the transform, clear redo.
fn edit_note(
  model: Model,
  transform: fn(Note) -> Note,
) -> #(Model, Command(Msg)) {
  case current_note(model) {
    Ok(note) -> {
      let updated = transform(note)
      let model = push_undo(model, note)
      #(
        Model(..model, notes: replace_note(model.notes, updated)),
        command.none(),
      )
    }
    Error(_) -> #(model, command.none())
  }
}
