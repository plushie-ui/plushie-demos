//// Data model for the notes app.
////
//// The model is a flat record with no nesting beyond the note list.
//// This keeps `update` simple -- every field is directly accessible
//// via record update syntax.

import gleam/list
import notes/msg.{type Msg}
import plushie/command.{type Command}

/// A single note.
pub type Note {
  Note(
    /// Unique identifier (monotonic integer as string).
    id: String,
    /// Note title, shown in the list view.
    title: String,
    /// Note body, edited in the editor view.
    body: String,
  )
}

/// Which view is currently displayed.
pub type View {
  /// The note list with search.
  ListView
  /// Editing a specific note.
  EditorView(note_id: String)
}

/// Application state.
pub type Model {
  Model(
    /// All notes, newest first.
    notes: List(Note),
    /// Current view (list or editor).
    current_view: View,
    /// Search filter text (empty = show all).
    search: String,
    /// Previous note states for undo (most recent first).
    undo_stack: List(Note),
    /// Undone note states for redo (most recent first).
    redo_stack: List(Note),
    /// Monotonic counter for generating unique note IDs.
    next_id: Int,
  )
}

const max_undo = 50

/// Initial state: no notes, list view, empty search.
pub fn init() -> #(Model, Command(Msg)) {
  #(
    Model(
      notes: [],
      current_view: ListView,
      search: "",
      undo_stack: [],
      redo_stack: [],
      next_id: 1,
    ),
    command.none(),
  )
}

// -- Note helpers ------------------------------------------------------------

/// Find a note by ID.
pub fn find_note(notes: List(Note), id: String) -> Result(Note, Nil) {
  list.find(notes, fn(n) { n.id == id })
}

/// Replace a note in the list (matched by ID).
pub fn replace_note(notes: List(Note), updated: Note) -> List(Note) {
  list.map(notes, fn(n) {
    case n.id == updated.id {
      True -> updated
      False -> n
    }
  })
}

/// Push a note onto the undo stack, capping at `max_undo` entries.
pub fn push_undo(model: Model, note: Note) -> Model {
  let stack = [note, ..model.undo_stack]
  let bounded = list.take(stack, max_undo)
  Model(..model, undo_stack: bounded, redo_stack: [])
}
