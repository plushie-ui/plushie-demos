import gleam/dict
import gleam/list
import gleam/option
import gleeunit/should
import notes/app
import notes/model.{type Model, EditorView, ListView, Model, Note}
import notes/msg
import plushie/command
import plushie/node.{type Node, StringVal}
import plushie/subscription

// ---------------------------------------------------------------------------
// update -- navigation
// ---------------------------------------------------------------------------

pub fn show_list_navigates_to_list_view_test() {
  let m = model_with_note_open()
  let #(m, _) = app.update(m, msg.ShowList)
  should.equal(m.current_view, ListView)
}

pub fn show_list_clears_undo_redo_test() {
  let m =
    Model(
      ..model_with_note_open(),
      undo_stack: [Note(id: "1", title: "old", body: "")],
      redo_stack: [Note(id: "1", title: "older", body: "")],
    )
  let #(m, _) = app.update(m, msg.ShowList)
  should.equal(m.undo_stack, [])
  should.equal(m.redo_stack, [])
}

pub fn open_note_navigates_to_editor_test() {
  let #(m, _) = model.init()
  let m = Model(..m, notes: [Note(id: "1", title: "A", body: "")])
  let #(m, _) = app.update(m, msg.OpenNote("1"))
  should.equal(m.current_view, EditorView("1"))
}

pub fn open_note_clears_undo_redo_test() {
  let m = model_with_note_open()
  let m = Model(..m, undo_stack: [Note(id: "1", title: "old", body: "")])
  let #(m, _) = app.update(m, msg.OpenNote("1"))
  should.equal(m.undo_stack, [])
  should.equal(m.redo_stack, [])
}

// ---------------------------------------------------------------------------
// update -- create / delete
// ---------------------------------------------------------------------------

pub fn create_note_adds_to_list_test() {
  let #(m, _) = model.init()
  let #(m, _) = app.update(m, msg.CreateNote)
  should.equal(list.length(m.notes), 1)
}

pub fn create_note_opens_editor_test() {
  let #(m, _) = model.init()
  let #(m, _) = app.update(m, msg.CreateNote)
  should.equal(m.current_view, EditorView("1"))
}

pub fn create_note_increments_next_id_test() {
  let #(m, _) = model.init()
  let #(m, _) = app.update(m, msg.CreateNote)
  should.equal(m.next_id, 2)
  let #(m, _) = app.update(m, msg.CreateNote)
  should.equal(m.next_id, 3)
}

pub fn create_note_has_default_title_test() {
  let #(m, _) = model.init()
  let #(m, _) = app.update(m, msg.CreateNote)
  let assert [note] = m.notes
  should.equal(note.title, "Untitled")
}

pub fn delete_note_removes_from_list_test() {
  let m =
    Model(..empty_model(), notes: [
      Note(id: "1", title: "A", body: ""),
      Note(id: "2", title: "B", body: ""),
    ])
  let #(m, _) = app.update(m, msg.DeleteNote("1"))
  should.equal(list.length(m.notes), 1)
  should.equal(
    model.find_note(m.notes, "2"),
    Ok(Note(id: "2", title: "B", body: "")),
  )
}

pub fn delete_note_preserves_other_notes_test() {
  let m =
    Model(..empty_model(), notes: [
      Note(id: "1", title: "A", body: ""),
      Note(id: "2", title: "B", body: ""),
      Note(id: "3", title: "C", body: ""),
    ])
  let #(m, _) = app.update(m, msg.DeleteNote("2"))
  should.equal(list.map(m.notes, fn(n) { n.id }), ["1", "3"])
}

// ---------------------------------------------------------------------------
// update -- editing
// ---------------------------------------------------------------------------

pub fn edit_title_updates_note_test() {
  let m = model_with_note_open()
  let #(m, _) = app.update(m, msg.EditTitle("New Title"))
  let assert Ok(note) = model.find_note(m.notes, "1")
  should.equal(note.title, "New Title")
}

pub fn edit_title_pushes_to_undo_test() {
  let m = model_with_note_open()
  let #(m, _) = app.update(m, msg.EditTitle("New Title"))
  should.equal(list.length(m.undo_stack), 1)
}

pub fn edit_title_clears_redo_test() {
  let m =
    Model(..model_with_note_open(), redo_stack: [
      Note(id: "1", title: "future", body: ""),
    ])
  let #(m, _) = app.update(m, msg.EditTitle("New"))
  should.equal(m.redo_stack, [])
}

pub fn edit_body_updates_note_test() {
  let m = model_with_note_open()
  let #(m, _) = app.update(m, msg.EditBody("Hello world"))
  let assert Ok(note) = model.find_note(m.notes, "1")
  should.equal(note.body, "Hello world")
}

pub fn edit_body_pushes_to_undo_test() {
  let m = model_with_note_open()
  let #(m, _) = app.update(m, msg.EditBody("text"))
  should.equal(list.length(m.undo_stack), 1)
}

pub fn edit_in_list_view_is_noop_test() {
  let m = Model(..model_with_note_open(), current_view: ListView)
  let #(new_m, _) = app.update(m, msg.EditTitle("should not change"))
  should.equal(new_m.notes, m.notes)
}

// ---------------------------------------------------------------------------
// update -- undo / redo
// ---------------------------------------------------------------------------

pub fn undo_restores_previous_state_test() {
  let m = model_with_note_open()
  let #(m, _) = app.update(m, msg.EditTitle("v2"))
  let #(m, _) = app.update(m, msg.Undo)
  let assert Ok(note) = model.find_note(m.notes, "1")
  should.equal(note.title, "Test Note")
}

pub fn undo_pushes_current_to_redo_test() {
  let m = model_with_note_open()
  let #(m, _) = app.update(m, msg.EditTitle("v2"))
  let #(m, _) = app.update(m, msg.Undo)
  should.equal(list.length(m.redo_stack), 1)
}

pub fn undo_with_empty_stack_is_noop_test() {
  let m = model_with_note_open()
  let #(new_m, _) = app.update(m, msg.Undo)
  should.equal(new_m.notes, m.notes)
}

pub fn redo_restores_undone_state_test() {
  let m = model_with_note_open()
  let #(m, _) = app.update(m, msg.EditTitle("v2"))
  let #(m, _) = app.update(m, msg.Undo)
  let #(m, _) = app.update(m, msg.Redo)
  let assert Ok(note) = model.find_note(m.notes, "1")
  should.equal(note.title, "v2")
}

pub fn redo_with_empty_stack_is_noop_test() {
  let m = model_with_note_open()
  let #(new_m, _) = app.update(m, msg.Redo)
  should.equal(new_m.notes, m.notes)
}

pub fn undo_redo_roundtrip_test() {
  let m = model_with_note_open()
  // Edit -> undo -> redo -> same as after edit
  let #(m, _) = app.update(m, msg.EditTitle("changed"))
  let #(m, _) = app.update(m, msg.Undo)
  let #(m, _) = app.update(m, msg.Redo)
  let assert Ok(note) = model.find_note(m.notes, "1")
  should.equal(note.title, "changed")
}

pub fn new_edit_clears_redo_test() {
  let m = model_with_note_open()
  let #(m, _) = app.update(m, msg.EditTitle("v2"))
  let #(m, _) = app.update(m, msg.Undo)
  should.be_true(m.redo_stack != [])
  // New edit should clear redo
  let #(m, _) = app.update(m, msg.EditTitle("v3"))
  should.equal(m.redo_stack, [])
}

// ---------------------------------------------------------------------------
// update -- search
// ---------------------------------------------------------------------------

pub fn set_search_updates_search_test() {
  let #(m, _) = model.init()
  let #(m, _) = app.update(m, msg.SetSearch("hello"))
  should.equal(m.search, "hello")
}

pub fn focus_search_returns_focus_command_test() {
  let #(m, _) = model.init()
  let #(_, cmd) = app.update(m, msg.FocusSearch)
  should.equal(cmd, command.Focus("search"))
}

pub fn noop_returns_model_unchanged_test() {
  let #(m, _) = model.init()
  let #(new_m, _) = app.update(m, msg.NoOp)
  should.equal(new_m, m)
}

// ---------------------------------------------------------------------------
// subscribe
// ---------------------------------------------------------------------------

pub fn subscribe_returns_key_press_subscription_test() {
  let #(m, _) = model.init()
  let subs = app.subscribe(m)
  should.equal(subs, [subscription.on_key_press("shortcuts")])
}

// ---------------------------------------------------------------------------
// view -- structure
// ---------------------------------------------------------------------------

pub fn view_root_is_window_test() {
  let #(m, _) = model.init()
  let tree = app.view(m)
  should.equal(tree.kind, "window")
  should.equal(tree.id, "main")
}

pub fn view_window_has_title_test() {
  let #(m, _) = model.init()
  let tree = app.view(m)
  should.equal(dict.get(tree.props, "title"), Ok(StringVal("Notes")))
}

// -- list view --

pub fn list_view_contains_create_button_test() {
  let #(m, _) = model.init()
  let tree = app.view(m)
  should.be_true(option.is_some(find_node(tree, "create")))
}

pub fn list_view_contains_search_input_test() {
  let #(m, _) = model.init()
  let tree = app.view(m)
  should.be_true(option.is_some(find_node(tree, "search")))
}

pub fn list_view_shows_empty_state_test() {
  let #(m, _) = model.init()
  let tree = app.view(m)
  should.be_true(option.is_some(find_node(tree, "empty")))
}

pub fn list_view_shows_note_rows_test() {
  let m =
    Model(..empty_model(), notes: [
      Note(id: "1", title: "A", body: ""),
      Note(id: "2", title: "B", body: ""),
    ])
  let tree = app.view(m)
  should.be_true(option.is_some(find_node(tree, "note-1")))
  should.be_true(option.is_some(find_node(tree, "note-2")))
}

pub fn list_view_shows_delete_buttons_test() {
  let m = Model(..empty_model(), notes: [Note(id: "1", title: "A", body: "")])
  let tree = app.view(m)
  should.be_true(option.is_some(find_node(tree, "delete-1")))
}

// -- editor view --

pub fn editor_view_contains_back_button_test() {
  let m = model_with_note_open()
  let tree = app.view(m)
  should.be_true(option.is_some(find_node(tree, "back")))
}

pub fn editor_view_contains_undo_redo_buttons_test() {
  let m = model_with_note_open()
  let tree = app.view(m)
  should.be_true(option.is_some(find_node(tree, "undo")))
  should.be_true(option.is_some(find_node(tree, "redo")))
}

pub fn editor_view_contains_title_input_test() {
  let m = model_with_note_open()
  let tree = app.view(m)
  let assert option.Some(title) = find_node(tree, "title")
  should.equal(dict.get(title.props, "value"), Ok(StringVal("Test Note")))
}

pub fn editor_view_contains_body_editor_test() {
  let m = model_with_note_open()
  let tree = app.view(m)
  should.be_true(option.is_some(find_node(tree, "body")))
}

// -- shortcut bar --

pub fn shortcut_bar_present_in_list_view_test() {
  let #(m, _) = model.init()
  let tree = app.view(m)
  should.be_true(option.is_some(find_node(tree, "shortcut-bar")))
}

pub fn shortcut_bar_present_in_editor_view_test() {
  let m = model_with_note_open()
  let tree = app.view(m)
  should.be_true(option.is_some(find_node(tree, "shortcut-bar")))
}

pub fn list_shortcuts_show_ctrl_n_test() {
  let #(m, _) = model.init()
  let tree = app.view(m)
  should.be_true(option.is_some(find_node(tree, "Ctrl+N-hint")))
}

pub fn editor_shortcuts_show_ctrl_z_test() {
  let m = model_with_note_open()
  let tree = app.view(m)
  should.be_true(option.is_some(find_node(tree, "Ctrl+Z-hint")))
}

// ---------------------------------------------------------------------------
// filter_notes
// ---------------------------------------------------------------------------

pub fn filter_notes_empty_search_returns_all_test() {
  let notes = [
    Note(id: "1", title: "Abc", body: ""),
    Note(id: "2", title: "Def", body: ""),
  ]
  should.equal(app.filter_notes(notes, ""), notes)
}

pub fn filter_notes_matches_title_test() {
  let notes = [
    Note(id: "1", title: "Abc", body: ""),
    Note(id: "2", title: "Def", body: ""),
  ]
  let result = app.filter_notes(notes, "ab")
  should.equal(list.length(result), 1)
  should.equal(
    {
      let assert [n] = result
      n.id
    },
    "1",
  )
}

pub fn filter_notes_case_insensitive_test() {
  let notes = [Note(id: "1", title: "Hello World", body: "")]
  should.equal(app.filter_notes(notes, "HELLO"), notes)
}

pub fn filter_notes_no_match_returns_empty_test() {
  let notes = [Note(id: "1", title: "Abc", body: "")]
  should.equal(app.filter_notes(notes, "xyz"), [])
}

// ---------------------------------------------------------------------------
// Full journey
// ---------------------------------------------------------------------------

pub fn full_journey_test() {
  // Start with empty list
  let #(m, _) = model.init()
  should.equal(m.current_view, ListView)
  should.equal(m.notes, [])

  // Create a note
  let #(m, _) = app.update(m, msg.CreateNote)
  should.equal(m.current_view, EditorView("1"))
  should.equal(list.length(m.notes), 1)

  // Edit title and body
  let #(m, _) = app.update(m, msg.EditTitle("Shopping"))
  let #(m, _) = app.update(m, msg.EditBody("Milk, eggs"))

  // Undo body edit
  let #(m, _) = app.update(m, msg.Undo)
  let assert Ok(note) = model.find_note(m.notes, "1")
  should.equal(note.body, "")
  should.equal(note.title, "Shopping")

  // Redo body edit
  let #(m, _) = app.update(m, msg.Redo)
  let assert Ok(note) = model.find_note(m.notes, "1")
  should.equal(note.body, "Milk, eggs")

  // Go back to list
  let #(m, _) = app.update(m, msg.ShowList)
  should.equal(m.current_view, ListView)

  // Create another note
  let #(m, _) = app.update(m, msg.CreateNote)
  should.equal(list.length(m.notes), 2)

  // Go back and delete the first note
  let #(m, _) = app.update(m, msg.ShowList)
  let #(m, _) = app.update(m, msg.DeleteNote("1"))
  should.equal(list.length(m.notes), 1)
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn empty_model() -> Model {
  let #(m, _) = model.init()
  m
}

fn model_with_note_open() -> Model {
  Model(
    notes: [Note(id: "1", title: "Test Note", body: "Some content")],
    current_view: EditorView("1"),
    search: "",
    undo_stack: [],
    redo_stack: [],
    next_id: 2,
  )
}

fn find_node(node: Node, target_id: String) -> option.Option(Node) {
  case node.id == target_id {
    True -> option.Some(node)
    False ->
      list.fold(node.children, option.None, fn(acc, child) {
        case acc {
          option.Some(_) -> acc
          option.None -> find_node(child, target_id)
        }
      })
  }
}
