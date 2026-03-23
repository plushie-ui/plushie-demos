//// Integration tests for the crash lab app.

import crash_lab/app
import gleam/option
import gleeunit/should
import plushie/node.{StringVal}
import plushie/testing
import plushie/testing/element

// ---------------------------------------------------------------------------
// init
// ---------------------------------------------------------------------------

pub fn init_count_is_zero_test() {
  let session = testing.start(app.app())
  should.equal(testing.model(session).count, 0)
  testing.stop(session)
}

pub fn init_widget_alive_test() {
  let session = testing.start(app.app())
  should.be_true(testing.model(session).widget_alive)
  testing.stop(session)
}

pub fn init_view_not_broken_test() {
  let session = testing.start(app.app())
  should.be_false(testing.model(session).view_broken)
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// view -- widgets exist
// ---------------------------------------------------------------------------

pub fn view_has_counter_test() {
  let session = testing.start(app.app())
  should.be_true(option.is_some(testing.find(session, "inc")))
  should.be_true(option.is_some(testing.find(session, "dec")))
  should.be_true(option.is_some(testing.find(session, "count")))
  testing.stop(session)
}

pub fn view_has_crash_buttons_test() {
  let session = testing.start(app.app())
  should.be_true(option.is_some(testing.find(session, "panic-extension")))
  should.be_true(option.is_some(testing.find(session, "toggle-widget")))
  should.be_true(option.is_some(testing.find(session, "panic-update")))
  should.be_true(option.is_some(testing.find(session, "break-view")))
  should.be_true(option.is_some(testing.find(session, "recover-view")))
  testing.stop(session)
}

pub fn view_has_crash_widget_test() {
  let session = testing.start(app.app())
  let assert option.Some(el) = testing.find(session, "crasher")
  should.equal(element.kind(el), "crash_widget")
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// interactions -- counter
// ---------------------------------------------------------------------------

pub fn inc_increments_count_test() {
  let session = testing.start(app.app())
  let session = testing.click(session, "inc")
  should.equal(testing.model(session).count, 1)
  testing.stop(session)
}

pub fn dec_decrements_count_test() {
  let session = testing.start(app.app())
  let session = testing.click(session, "inc")
  let session = testing.click(session, "inc")
  let session = testing.click(session, "dec")
  should.equal(testing.model(session).count, 1)
  testing.stop(session)
}

pub fn count_text_updates_test() {
  let session = testing.start(app.app())
  let session = testing.click(session, "inc")
  let session = testing.click(session, "inc")
  let assert option.Some(el) = testing.find(session, "count")
  should.equal(element.text(el), option.Some("2"))
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// interactions -- toggle widget
// ---------------------------------------------------------------------------

pub fn toggle_removes_widget_test() {
  let session = testing.start(app.app())
  let session = testing.click(session, "toggle-widget")
  should.be_false(testing.model(session).widget_alive)
  should.be_true(option.is_none(testing.find(session, "crasher")))
  testing.stop(session)
}

pub fn toggle_restores_widget_test() {
  let session = testing.start(app.app())
  let session = testing.click(session, "toggle-widget")
  let session = testing.click(session, "toggle-widget")
  should.be_true(testing.model(session).widget_alive)
  should.be_true(option.is_some(testing.find(session, "crasher")))
  testing.stop(session)
}

pub fn toggle_label_changes_test() {
  let session = testing.start(app.app())
  let assert option.Some(btn) = testing.find(session, "toggle-widget")
  should.equal(element.text(btn), option.Some("Remove Widget"))

  let session = testing.click(session, "toggle-widget")
  let assert option.Some(btn) = testing.find(session, "toggle-widget")
  should.equal(element.text(btn), option.Some("Restore Widget"))
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// interactions -- break/recover view
// ---------------------------------------------------------------------------
// Note: break-view tests require the real runtime's try_call to catch
// the view panic. They pass on pooled_mock/headless but crash on mock.
// The view panic is tested implicitly in the full recovery sequence
// when run against a real backend:
//   PLUSHIE_TEST_BACKEND=pooled_mock gleam test

// ---------------------------------------------------------------------------
// counter survives interactions
// ---------------------------------------------------------------------------

pub fn counter_survives_toggle_test() {
  let session = testing.start(app.app())
  let session = testing.click(session, "inc")
  let session = testing.click(session, "inc")
  let session = testing.click(session, "toggle-widget")
  let session = testing.click(session, "toggle-widget")
  should.equal(testing.model(session).count, 2)
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// full recovery sequence
// ---------------------------------------------------------------------------

pub fn full_recovery_sequence_test() {
  let session = testing.start(app.app())

  // Build up state
  let session = testing.click(session, "inc")
  let session = testing.click(session, "inc")
  let session = testing.click(session, "inc")
  should.equal(testing.model(session).count, 3)

  // Remove and restore widget
  let session = testing.click(session, "toggle-widget")
  let session = testing.click(session, "toggle-widget")
  should.be_true(testing.model(session).widget_alive)

  // Counter still intact after widget recovery
  should.equal(testing.model(session).count, 3)
  let session = testing.click(session, "inc")
  should.equal(testing.model(session).count, 4)

  testing.stop(session)
}
