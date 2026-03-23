//// Integration tests for the collab demo.
////
//// Uses the plushie testing facade so tests run against whatever
//// backend PLUSHIE_TEST_BACKEND selects (mock, pooled_mock, headless).

import demo/collab
import gleam/option
import gleeunit/should
import plushie/node.{BoolVal, StringVal}
import plushie/testing
import plushie/testing/element

// ---------------------------------------------------------------------------
// init -- verify initial state
// ---------------------------------------------------------------------------

pub fn init_count_is_zero_test() {
  let session = testing.start(collab.app())
  let model = testing.model(session)
  should.equal(model.count, 0)
  testing.stop(session)
}

pub fn init_name_is_empty_test() {
  let session = testing.start(collab.app())
  should.equal(testing.model(session).name, "")
  testing.stop(session)
}

pub fn init_dark_mode_is_false_test() {
  let session = testing.start(collab.app())
  should.be_false(testing.model(session).dark_mode)
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// view -- widgets exist
// ---------------------------------------------------------------------------

pub fn view_has_header_test() {
  let session = testing.start(collab.app())
  should.be_true(option.is_some(testing.find(session, "header")))
  testing.stop(session)
}

pub fn view_has_name_input_test() {
  let session = testing.start(collab.app())
  should.be_true(option.is_some(testing.find(session, "name")))
  testing.stop(session)
}

pub fn view_has_counter_test() {
  let session = testing.start(collab.app())
  should.be_true(option.is_some(testing.find(session, "inc")))
  should.be_true(option.is_some(testing.find(session, "dec")))
  should.be_true(option.is_some(testing.find(session, "count")))
  testing.stop(session)
}

pub fn view_has_theme_checkbox_test() {
  let session = testing.start(collab.app())
  should.be_true(option.is_some(testing.find(session, "theme")))
  testing.stop(session)
}

pub fn view_has_notes_input_test() {
  let session = testing.start(collab.app())
  should.be_true(option.is_some(testing.find(session, "notes")))
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// view -- initial content
// ---------------------------------------------------------------------------

pub fn view_count_starts_at_zero_test() {
  let session = testing.start(collab.app())
  let assert option.Some(el) = testing.find(session, "count")
  should.equal(element.text(el), option.Some("Count: 0"))
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// interactions -- counter
// ---------------------------------------------------------------------------

pub fn inc_increments_count_test() {
  let session = testing.start(collab.app())
  let session = testing.click(session, "inc")
  should.equal(testing.model(session).count, 1)
  testing.stop(session)
}

pub fn dec_decrements_count_test() {
  let session = testing.start(collab.app())
  let session = testing.click(session, "inc")
  let session = testing.click(session, "inc")
  let session = testing.click(session, "dec")
  should.equal(testing.model(session).count, 1)
  testing.stop(session)
}

pub fn dec_below_zero_test() {
  let session = testing.start(collab.app())
  let session = testing.click(session, "dec")
  should.equal(testing.model(session).count, -1)
  testing.stop(session)
}

pub fn count_text_updates_after_click_test() {
  let session = testing.start(collab.app())
  let session = testing.click(session, "inc")
  let session = testing.click(session, "inc")
  let assert option.Some(el) = testing.find(session, "count")
  should.equal(element.text(el), option.Some("Count: 2"))
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// interactions -- text inputs
// ---------------------------------------------------------------------------

pub fn name_input_updates_model_test() {
  let session = testing.start(collab.app())
  let session = testing.type_text(session, "name", "Bob")
  should.equal(testing.model(session).name, "Bob")
  testing.stop(session)
}

pub fn notes_input_updates_model_test() {
  let session = testing.start(collab.app())
  let session = testing.type_text(session, "notes", "Meeting at 3pm")
  should.equal(testing.model(session).notes, "Meeting at 3pm")
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// interactions -- theme toggle
// ---------------------------------------------------------------------------

pub fn theme_toggle_enables_dark_mode_test() {
  let session = testing.start(collab.app())
  should.be_false(testing.model(session).dark_mode)
  let session = testing.toggle(session, "theme")
  should.be_true(testing.model(session).dark_mode)
  testing.stop(session)
}

pub fn theme_toggle_back_disables_dark_mode_test() {
  let session = testing.start(collab.app())
  let session = testing.toggle(session, "theme")
  let session = testing.toggle(session, "theme")
  should.be_false(testing.model(session).dark_mode)
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// full journey
// ---------------------------------------------------------------------------

pub fn full_journey_test() {
  let session = testing.start(collab.app())

  // Set name
  let session = testing.type_text(session, "name", "Alice")
  should.equal(testing.model(session).name, "Alice")

  // Increment twice
  let session = testing.click(session, "inc")
  let session = testing.click(session, "inc")
  should.equal(testing.model(session).count, 2)

  // Add notes
  let session = testing.type_text(session, "notes", "Meeting at 3pm")
  should.equal(testing.model(session).notes, "Meeting at 3pm")

  // Toggle dark mode
  let session = testing.toggle(session, "theme")
  should.be_true(testing.model(session).dark_mode)

  // Decrement
  let session = testing.click(session, "dec")
  should.equal(testing.model(session).count, 1)

  // All state preserved
  should.equal(testing.model(session).name, "Alice")
  should.equal(testing.model(session).notes, "Meeting at 3pm")

  testing.stop(session)
}
