import gleam/option
import gleeunit/should
import notes/msg.{
  CreateNote, DeleteNote, EditBody, EditTitle, FocusSearch, NoOp, OpenNote, Redo,
  SetSearch, ShowList, Undo,
}
import plushie/event.{
  Click, EventTarget, Input, Key, KeyEvent, KeyPressed, Modifiers, Toggle,
  Widget,
}

// ---------------------------------------------------------------------------
// on_event - keyboard shortcuts
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
// on_event - captured keys are ignored
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
// on_event - button clicks
// ---------------------------------------------------------------------------

pub fn click_create_test() {
  should.equal(
    msg.on_event(Widget(Click(
      target: EventTarget(id: "create", window_id: "main", scope: [], full: "main#create"),
    ))),
    CreateNote,
  )
}

pub fn click_back_test() {
  should.equal(
    msg.on_event(Widget(Click(
      target: EventTarget(id: "back", window_id: "main", scope: [], full: "main#back"),
    ))),
    ShowList,
  )
}

pub fn click_undo_test() {
  should.equal(
    msg.on_event(Widget(Click(
      target: EventTarget(id: "undo", window_id: "main", scope: [], full: "main#undo"),
    ))),
    Undo,
  )
}

pub fn click_redo_test() {
  should.equal(
    msg.on_event(Widget(Click(
      target: EventTarget(id: "redo", window_id: "main", scope: [], full: "main#redo"),
    ))),
    Redo,
  )
}

// ---------------------------------------------------------------------------
// on_event - text inputs
// ---------------------------------------------------------------------------

pub fn search_input_test() {
  let e =
    Widget(Input(
      target: EventTarget(id: "search", window_id: "main", scope: [], full: "main#search"),
      value: "hello",
    ))
  should.equal(msg.on_event(e), SetSearch("hello"))
}

pub fn title_input_test() {
  let e =
    Widget(Input(
      target: EventTarget(id: "title", window_id: "main", scope: [], full: "main#title"),
      value: "My Note",
    ))
  should.equal(msg.on_event(e), EditTitle("My Note"))
}

pub fn body_input_test() {
  let e =
    Widget(Input(
      target: EventTarget(id: "body", window_id: "main", scope: [], full: "main#body"),
      value: "some text",
    ))
  should.equal(msg.on_event(e), EditBody("some text"))
}

// ---------------------------------------------------------------------------
// on_event - dynamic IDs (note rows and delete buttons)
// ---------------------------------------------------------------------------

pub fn click_note_row_opens_note_test() {
  should.equal(
    msg.on_event(Widget(Click(
      target: EventTarget(id: "note-42", window_id: "main", scope: [], full: "main#note-42"),
    ))),
    OpenNote("42"),
  )
}

pub fn click_delete_button_deletes_note_test() {
  should.equal(
    msg.on_event(Widget(Click(
      target: EventTarget(id: "delete-42", window_id: "main", scope: [], full: "main#delete-42"),
    ))),
    DeleteNote("42"),
  )
}

pub fn unknown_click_is_noop_test() {
  should.equal(
    msg.on_event(Widget(Click(
      target: EventTarget(id: "something-else", window_id: "main", scope: [], full: "main#something-else"),
    ))),
    NoOp,
  )
}

pub fn unknown_event_is_noop_test() {
  should.equal(
    msg.on_event(Widget(Toggle(
      target: EventTarget(id: "x", window_id: "main", scope: [], full: "main#x"),
      value: True,
    ))),
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
  Key(KeyEvent(
    event_type: KeyPressed,
    window_id: "",
    key:,
    modified_key: key,
    modifiers: Modifiers(
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
  ))
}
