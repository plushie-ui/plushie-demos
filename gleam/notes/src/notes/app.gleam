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
import plushie/widget/text_editor

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

  ui.window("main", [ui.title("Notes"), ui.window_size(600.0, 500.0)], [
    ui.column("root", [ui.padding(padding.all(16.0)), ui.width(length.Fill)], [
      content,
      shortcut_bar(model.current_view),
    ]),
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
    [ui.spacing(12), ui.width(length.Fill)],
    list.flatten([
      [
        ui.row("list-header", [ui.spacing(8)], [
          ui.text("list-title", "Notes", [ui.font_size(24.0)]),
          ui.button_("create", "+ New"),
        ]),
        ui.text_input("search", model.search, [
          ui.placeholder("Search notes..."),
          ui.width(length.Fill),
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

  ui.row("row-" <> note.id, [ui.spacing(8), ui.width(length.Fill)], [
    ui.column("info-" <> note.id, [ui.spacing(2), ui.width(length.Fill)], [
      ui.button("note-" <> note.id, note.title, [ui.width(length.Fill)]),
      ui.text("preview-" <> note.id, preview, [
        ui.font_size(12.0),
        ui.text_color(muted),
      ]),
    ]),
    ui.button_("delete-" <> note.id, "x"),
  ])
}

fn empty_state(message: String) -> Node {
  let assert Ok(muted) = color.from_hex("#999999")
  ui.text("empty", message, [
    ui.font_size(14.0),
    ui.text_color(muted),
  ])
}

// -- Editor view -------------------------------------------------------------

fn editor_view(model: Model, note_id: String) -> Node {
  case find_note(model.notes, note_id) {
    Ok(note) -> {
      let has_undo = !list.is_empty(model.undo_stack)
      let has_redo = !list.is_empty(model.redo_stack)

      ui.column("editor-view", [ui.spacing(12), ui.width(length.Fill)], [
        ui.row("editor-header", [ui.spacing(8)], [
          ui.button_("back", "Back"),
          ui.button("undo", "Undo", [ui.disabled(!has_undo)]),
          ui.button("redo", "Redo", [ui.disabled(!has_redo)]),
        ]),
        ui.text_input("title", note.title, [
          ui.placeholder("Note title"),
          ui.width(length.Fill),
          ui.font_size(20.0),
        ]),
        text_editor.new("body", note.body)
          |> text_editor.placeholder("Start writing...")
          |> text_editor.height(length.Fill)
          |> text_editor.build(),
      ])
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
      shortcut_hint("Ctrl+N", "New note"),
      shortcut_hint("/", "Search"),
    ]
    EditorView(_) -> [
      shortcut_hint("Esc", "Back"),
      shortcut_hint("Ctrl+Z", "Undo"),
      shortcut_hint("Ctrl+Shift+Z", "Redo"),
    ]
  }

  ui.row(
    "shortcut-bar",
    [ui.spacing(16), ui.padding(padding.xy(8.0, 0.0)), ui.width(length.Fill)],
    hints,
  )
}

fn shortcut_hint(key_label: String, action: String) -> Node {
  let assert Ok(badge_bg) = color.from_hex("#f0f0f0")
  let assert Ok(hint_color) = color.from_hex("#666666")

  ui.row(key_label <> "-hint", [ui.spacing(4), ui.align_y(alignment.Center)], [
    ui.container(
      key_label <> "-badge",
      [
        ui.padding(padding.xy(2.0, 6.0)),
        ui.background(badge_bg),
      ],
      [
        ui.text(key_label <> "-key", key_label, [ui.font_size(11.0)]),
      ],
    ),
    ui.text(key_label <> "-action", action, [
      ui.font_size(11.0),
      ui.text_color(hint_color),
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
