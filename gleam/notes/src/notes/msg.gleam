//// Message type and event mapping for the notes app.
////
//// The `Msg` type is the app's vocabulary -- every action the user can
//// take is represented as a variant. The `on_event` function is the
//// single point where raw UI events (button clicks, keyboard shortcuts,
//// text input) are translated into typed domain messages.
////
//// This is the key architectural advantage of using `app.application()`
//// over `app.simple()`: the same logical action can come from multiple
//// UI triggers (a button click AND a keyboard shortcut), but `update`
//// only handles it once.

import gleam/string
import plushie/event.{type Event, KeyPress, Modifiers, WidgetClick, WidgetInput}

/// Every action the notes app can perform.
///
/// Reading this type tells you exactly what the app does, without
/// looking at any other code.
pub type Msg {
  // -- Navigation --
  /// Return to the note list.
  ShowList
  /// Open a note in the editor.
  OpenNote(id: String)

  // -- Note management --
  /// Create a new blank note and open it.
  CreateNote
  /// Delete a note by ID.
  DeleteNote(id: String)

  // -- Editor --
  /// Update the current note's title.
  EditTitle(value: String)
  /// Update the current note's body.
  EditBody(value: String)
  /// Undo the last edit in the editor.
  Undo
  /// Redo a previously undone edit.
  Redo

  // -- Search --
  /// Update the search filter text.
  SetSearch(value: String)
  /// Move keyboard focus to the search input.
  FocusSearch

  // -- Catch-all --
  /// Unhandled event; update ignores this.
  NoOp
}

/// Map a raw UI event to a domain message.
///
/// Keyboard shortcuts and widget interactions both produce the same
/// `Msg` variants. For example, `Ctrl+N` and clicking the "New" button
/// both produce `CreateNote`. The `update` function handles each
/// message exactly once regardless of its source.
///
/// The `captured: False` guard on key events ensures shortcuts don't
/// fire while the user is typing in a text field.
pub fn on_event(event: Event) -> Msg {
  case event {
    // -- Keyboard shortcuts (only when not captured by a text field) --
    KeyPress(
      key: "n",
      modifiers: Modifiers(ctrl: True, ..),
      captured: False,
      ..,
    ) -> CreateNote
    KeyPress(
      key: "z",
      modifiers: Modifiers(ctrl: True, shift: False, ..),
      captured: False,
      ..,
    ) -> Undo
    KeyPress(
      key: "z",
      modifiers: Modifiers(ctrl: True, shift: True, ..),
      captured: False,
      ..,
    ) -> Redo
    KeyPress(
      key: "/",
      captured: False,
      modifiers: Modifiers(ctrl: False, ..),
      ..,
    ) -> FocusSearch
    KeyPress(key: "Escape", captured: False, ..) -> ShowList

    // -- Button clicks --
    WidgetClick(id: "create", ..) -> CreateNote
    WidgetClick(id: "back", ..) -> ShowList
    WidgetClick(id: "undo", ..) -> Undo
    WidgetClick(id: "redo", ..) -> Redo

    // -- Text inputs --
    WidgetInput(id: "search", value:, ..) -> SetSearch(value)
    WidgetInput(id: "title", value:, ..) -> EditTitle(value)
    WidgetInput(id: "body", value:, ..) -> EditBody(value)

    // -- Dynamic widget IDs (note rows and delete buttons) --
    WidgetClick(id:, ..) -> parse_dynamic_click(id)

    _ -> NoOp
  }
}

/// Extract note IDs from dynamic widget IDs.
///
/// Note rows have IDs like "note-abc" and delete buttons like
/// "delete-abc". The prefix is stripped to get the note ID.
fn parse_dynamic_click(id: String) -> Msg {
  case string.starts_with(id, "note-") {
    True -> OpenNote(string.drop_start(id, 5))
    False ->
      case string.starts_with(id, "delete-") {
        True -> DeleteNote(string.drop_start(id, 7))
        False -> NoOp
      }
  }
}
