import gleam/list
import gleeunit/should
import notes/model.{ListView, Note}
import plushie/command

// ---------------------------------------------------------------------------
// init
// ---------------------------------------------------------------------------

pub fn init_notes_empty_test() {
  let #(m, _) = model.init()
  should.equal(m.notes, [])
}

pub fn init_view_is_list_test() {
  let #(m, _) = model.init()
  should.equal(m.current_view, ListView)
}

pub fn init_search_empty_test() {
  let #(m, _) = model.init()
  should.equal(m.search, "")
}

pub fn init_undo_stack_empty_test() {
  let #(m, _) = model.init()
  should.equal(m.undo_stack, [])
}

pub fn init_redo_stack_empty_test() {
  let #(m, _) = model.init()
  should.equal(m.redo_stack, [])
}

pub fn init_next_id_is_one_test() {
  let #(m, _) = model.init()
  should.equal(m.next_id, 1)
}

pub fn init_returns_no_command_test() {
  let #(_, cmd) = model.init()
  should.equal(cmd, command.none())
}

// ---------------------------------------------------------------------------
// find_note
// ---------------------------------------------------------------------------

pub fn find_note_returns_matching_note_test() {
  let notes = [
    Note(id: "1", title: "A", body: ""),
    Note(id: "2", title: "B", body: ""),
  ]
  should.equal(
    model.find_note(notes, "2"),
    Ok(Note(id: "2", title: "B", body: "")),
  )
}

pub fn find_note_returns_error_when_not_found_test() {
  let notes = [Note(id: "1", title: "A", body: "")]
  should.equal(model.find_note(notes, "99"), Error(Nil))
}

pub fn find_note_empty_list_test() {
  should.equal(model.find_note([], "1"), Error(Nil))
}

// ---------------------------------------------------------------------------
// replace_note
// ---------------------------------------------------------------------------

pub fn replace_note_updates_matching_test() {
  let notes = [
    Note(id: "1", title: "Old", body: ""),
    Note(id: "2", title: "Keep", body: ""),
  ]
  let updated = Note(id: "1", title: "New", body: "changed")
  let result = model.replace_note(notes, updated)
  should.equal(result, [
    Note(id: "1", title: "New", body: "changed"),
    Note(id: "2", title: "Keep", body: ""),
  ])
}

pub fn replace_note_preserves_order_test() {
  let notes = [
    Note(id: "1", title: "A", body: ""),
    Note(id: "2", title: "B", body: ""),
    Note(id: "3", title: "C", body: ""),
  ]
  let updated = Note(id: "2", title: "B2", body: "")
  let result = model.replace_note(notes, updated)
  should.equal(list.map(result, fn(n) { n.id }), ["1", "2", "3"])
}

// ---------------------------------------------------------------------------
// push_undo
// ---------------------------------------------------------------------------

pub fn push_undo_adds_to_stack_test() {
  let #(m, _) = model.init()
  let note = Note(id: "1", title: "A", body: "")
  let m = model.push_undo(m, note)
  should.equal(m.undo_stack, [note])
}

pub fn push_undo_clears_redo_test() {
  let #(m, _) = model.init()
  let m = model.Model(..m, redo_stack: [Note(id: "x", title: "", body: "")])
  let m = model.push_undo(m, Note(id: "1", title: "", body: ""))
  should.equal(m.redo_stack, [])
}

pub fn push_undo_caps_at_fifty_test() {
  let #(m, _) = model.init()
  let note = Note(id: "1", title: "", body: "")
  let m = model.Model(..m, undo_stack: list.repeat(note, 50))
  let m = model.push_undo(m, Note(id: "new", title: "", body: ""))
  should.equal(list.length(m.undo_stack), 50)
}
