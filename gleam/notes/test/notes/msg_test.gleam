import gleam/option
import gleeunit/should
import notes/msg.{
  CreateNote, DeleteNote, EditBody, EditTitle, FocusSearch, NoOp, OpenNote, Redo,
  SetSearch, ShowList, Undo,
}
import plushie/event

// ---------------------------------------------------------------------------
// on_event -- keyboard shortcuts
// ---------------------------------------------------------------------------

pub fn ctrl_n_creates_note_test() {
  let e = key_press("n", ctrl: True, shift: False, captured: False)
  should.equal(msg.on_event(e), CreateNote)
}

pub fn ctrl_z_undoes_test() {
  let e = key_press("z", ctrl: True, shift: False, captured: False)
  should.equal(msg.on_event(e), Undo)
}

pub fn ctrl_shift_z_redoes_test() {
  let e = key_press("z", ctrl: True, shift: True, captured: False)
  should.equal(msg.on_event(e), Redo)
}

pub fn slash_focuses_search_test() {
  let e = key_press("/", ctrl: False, shift: False, captured: False)
  should.equal(msg.on_event(e), FocusSearch)
}

pub fn escape_shows_list_test() {
  let e = key_press("Escape", ctrl: False, shift: False, captured: False)
  should.equal(msg.on_event(e), ShowList)
}

// ---------------------------------------------------------------------------
// on_event -- captured keys are ignored
// ---------------------------------------------------------------------------

pub fn captured_slash_is_noop_test() {
  let e = key_press("/", ctrl: False, shift: False, captured: True)
  should.equal(msg.on_event(e), NoOp)
}

pub fn captured_escape_is_noop_test() {
  let e = key_press("Escape", ctrl: False, shift: False, captured: True)
  should.equal(msg.on_event(e), NoOp)
}

pub fn captured_ctrl_n_is_noop_test() {
  let e = key_press("n", ctrl: True, shift: False, captured: True)
  should.equal(msg.on_event(e), NoOp)
}

// ---------------------------------------------------------------------------
// on_event -- button clicks
// ---------------------------------------------------------------------------

pub fn click_create_test() {
  should.equal(
    msg.on_event(event.WidgetClick(id: "create", window_id: "main", scope: [])),
    CreateNote,
  )
}

pub fn click_back_test() {
  should.equal(
    msg.on_event(event.WidgetClick(id: "back", window_id: "main", scope: [])),
    ShowList,
  )
}

pub fn click_undo_test() {
  should.equal(
    msg.on_event(event.WidgetClick(id: "undo", window_id: "main", scope: [])),
    Undo,
  )
}

pub fn click_redo_test() {
  should.equal(
    msg.on_event(event.WidgetClick(id: "redo", window_id: "main", scope: [])),
    Redo,
  )
}

// ---------------------------------------------------------------------------
// on_event -- text inputs
// ---------------------------------------------------------------------------

pub fn search_input_test() {
  let e =
    event.WidgetInput(
      id: "search",
      window_id: "main",
      scope: [],
      value: "hello",
    )
  should.equal(msg.on_event(e), SetSearch("hello"))
}

pub fn title_input_test() {
  let e =
    event.WidgetInput(
      id: "title",
      window_id: "main",
      scope: [],
      value: "My Note",
    )
  should.equal(msg.on_event(e), EditTitle("My Note"))
}

pub fn body_input_test() {
  let e =
    event.WidgetInput(
      id: "body",
      window_id: "main",
      scope: [],
      value: "some text",
    )
  should.equal(msg.on_event(e), EditBody("some text"))
}

// ---------------------------------------------------------------------------
// on_event -- dynamic IDs (note rows and delete buttons)
// ---------------------------------------------------------------------------

pub fn click_note_row_opens_note_test() {
  should.equal(
    msg.on_event(event.WidgetClick(id: "note-42", window_id: "main", scope: [])),
    OpenNote("42"),
  )
}

pub fn click_delete_button_deletes_note_test() {
  should.equal(
    msg.on_event(
      event.WidgetClick(id: "delete-42", window_id: "main", scope: []),
    ),
    DeleteNote("42"),
  )
}

pub fn unknown_click_is_noop_test() {
  should.equal(
    msg.on_event(
      event.WidgetClick(id: "something-else", window_id: "main", scope: []),
    ),
    NoOp,
  )
}

pub fn unknown_event_is_noop_test() {
  should.equal(
    msg.on_event(event.WidgetToggle(
      id: "x",
      window_id: "main",
      scope: [],
      value: True,
    )),
    NoOp,
  )
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

fn key_press(
  key: String,
  ctrl ctrl: Bool,
  shift shift: Bool,
  captured captured: Bool,
) -> event.Event {
  event.KeyPress(
    key:,
    modified_key: key,
    modifiers: event.Modifiers(
      shift:,
      ctrl: False,
      alt: False,
      logo: False,
      command: ctrl,
    ),
    physical_key: option.None,
    location: event.Standard,
    text: option.None,
    repeat: False,
    captured:,
  )
}
