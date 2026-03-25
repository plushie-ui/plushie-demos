//// Integration tests for the collab demo.
////
//// Uses the plushie testing facade so tests run against whatever
//// backend PLUSHIE_TEST_BACKEND selects (mock, pooled_mock, headless).

import demo/collab
import gleam/option
import gleeunit/should
import plushie/testing
import plushie/testing/element

// ---------------------------------------------------------------------------
// init -- verify initial state
// ---------------------------------------------------------------------------

pub fn init_count_is_zero_test() {
  let ctx = testing.start(collab.app())
  let model = testing.model(ctx)
  should.equal(model.count, 0)
  testing.stop(ctx)
}

pub fn init_name_is_empty_test() {
  let ctx = testing.start(collab.app())
  should.equal(testing.model(ctx).name, "")
  testing.stop(ctx)
}

pub fn init_dark_mode_is_false_test() {
  let ctx = testing.start(collab.app())
  should.be_false(testing.model(ctx).dark_mode)
  testing.stop(ctx)
}

// ---------------------------------------------------------------------------
// view -- widgets exist
// ---------------------------------------------------------------------------

pub fn view_has_header_test() {
  let ctx = testing.start(collab.app())
  should.be_true(option.is_some(testing.find(ctx, "header")))
  testing.stop(ctx)
}

pub fn view_has_name_input_test() {
  let ctx = testing.start(collab.app())
  should.be_true(option.is_some(testing.find(ctx, "name")))
  testing.stop(ctx)
}

pub fn view_has_counter_test() {
  let ctx = testing.start(collab.app())
  should.be_true(option.is_some(testing.find(ctx, "inc")))
  should.be_true(option.is_some(testing.find(ctx, "dec")))
  should.be_true(option.is_some(testing.find(ctx, "count")))
  testing.stop(ctx)
}

pub fn view_has_theme_checkbox_test() {
  let ctx = testing.start(collab.app())
  should.be_true(option.is_some(testing.find(ctx, "theme")))
  testing.stop(ctx)
}

pub fn view_has_notes_input_test() {
  let ctx = testing.start(collab.app())
  should.be_true(option.is_some(testing.find(ctx, "notes")))
  testing.stop(ctx)
}

// ---------------------------------------------------------------------------
// view -- initial content
// ---------------------------------------------------------------------------

pub fn view_count_starts_at_zero_test() {
  let ctx = testing.start(collab.app())
  let assert option.Some(el) = testing.find(ctx, "count")
  should.equal(element.text(el), option.Some("Count: 0"))
  testing.stop(ctx)
}

// ---------------------------------------------------------------------------
// interactions -- counter
// ---------------------------------------------------------------------------

pub fn inc_increments_count_test() {
  let ctx = testing.start(collab.app())
  let ctx = testing.click(ctx, "inc")
  should.equal(testing.model(ctx).count, 1)
  testing.stop(ctx)
}

pub fn dec_decrements_count_test() {
  let ctx = testing.start(collab.app())
  let ctx = testing.click(ctx, "inc")
  let ctx = testing.click(ctx, "inc")
  let ctx = testing.click(ctx, "dec")
  should.equal(testing.model(ctx).count, 1)
  testing.stop(ctx)
}

pub fn dec_below_zero_test() {
  let ctx = testing.start(collab.app())
  let ctx = testing.click(ctx, "dec")
  should.equal(testing.model(ctx).count, -1)
  testing.stop(ctx)
}

pub fn count_text_updates_after_click_test() {
  let ctx = testing.start(collab.app())
  let ctx = testing.click(ctx, "inc")
  let ctx = testing.click(ctx, "inc")
  let assert option.Some(el) = testing.find(ctx, "count")
  should.equal(element.text(el), option.Some("Count: 2"))
  testing.stop(ctx)
}

// ---------------------------------------------------------------------------
// interactions -- text inputs
// ---------------------------------------------------------------------------

pub fn name_input_updates_model_test() {
  let ctx = testing.start(collab.app())
  let ctx = testing.type_text(ctx, "name", "Bob")
  should.equal(testing.model(ctx).name, "Bob")
  testing.stop(ctx)
}

pub fn notes_input_updates_model_test() {
  let ctx = testing.start(collab.app())
  let ctx = testing.type_text(ctx, "notes", "Meeting at 3pm")
  should.equal(testing.model(ctx).notes, "Meeting at 3pm")
  testing.stop(ctx)
}

// ---------------------------------------------------------------------------
// interactions -- theme toggle
// ---------------------------------------------------------------------------

pub fn theme_toggle_enables_dark_mode_test() {
  let ctx = testing.start(collab.app())
  should.be_false(testing.model(ctx).dark_mode)
  let ctx = testing.toggle(ctx, "theme")
  should.be_true(testing.model(ctx).dark_mode)
  testing.stop(ctx)
}

pub fn theme_toggle_back_disables_dark_mode_test() {
  let ctx = testing.start(collab.app())
  let ctx = testing.toggle(ctx, "theme")
  let ctx = testing.toggle(ctx, "theme")
  should.be_false(testing.model(ctx).dark_mode)
  testing.stop(ctx)
}

// ---------------------------------------------------------------------------
// full journey
// ---------------------------------------------------------------------------

pub fn full_journey_test() {
  let ctx = testing.start(collab.app())

  // Set name
  let ctx = testing.type_text(ctx, "name", "Alice")
  should.equal(testing.model(ctx).name, "Alice")

  // Increment twice
  let ctx = testing.click(ctx, "inc")
  let ctx = testing.click(ctx, "inc")
  should.equal(testing.model(ctx).count, 2)

  // Add notes
  let ctx = testing.type_text(ctx, "notes", "Meeting at 3pm")
  should.equal(testing.model(ctx).notes, "Meeting at 3pm")

  // Toggle dark mode
  let ctx = testing.toggle(ctx, "theme")
  should.be_true(testing.model(ctx).dark_mode)

  // Decrement
  let ctx = testing.click(ctx, "dec")
  should.equal(testing.model(ctx).count, 1)

  // All state preserved
  should.equal(testing.model(ctx).name, "Alice")
  should.equal(testing.model(ctx).notes, "Meeting at 3pm")

  testing.stop(ctx)
}
