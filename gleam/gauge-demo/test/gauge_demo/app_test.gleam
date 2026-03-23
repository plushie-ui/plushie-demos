//// Integration tests for the gauge demo app.

import gauge_demo/app
import gleam/option
import gleeunit/should
import plushie/app as plushie_app
import plushie/node.{FloatVal, StringVal}
import plushie/testing
import plushie/testing/element

fn app() {
  plushie_app.simple(app.init, app.update, app.view)
}

// ---------------------------------------------------------------------------
// init
// ---------------------------------------------------------------------------

pub fn init_temperature_is_twenty_test() {
  let session = testing.start(app())
  should.equal(testing.model(session).temperature, 20.0)
  testing.stop(session)
}

pub fn init_has_gauge_widget_test() {
  let session = testing.start(app())
  let assert option.Some(el) = testing.find(session, "temp")
  should.equal(element.kind(el), "gauge")
  testing.stop(session)
}

pub fn init_has_slider_test() {
  let session = testing.start(app())
  should.be_true(option.is_some(testing.find(session, "target")))
  testing.stop(session)
}

pub fn init_has_buttons_test() {
  let session = testing.start(app())
  should.be_true(option.is_some(testing.find(session, "reset")))
  should.be_true(option.is_some(testing.find(session, "high")))
  testing.stop(session)
}

pub fn init_status_is_cool_test() {
  let session = testing.start(app())
  let assert option.Some(el) = testing.find(session, "status")
  should.equal(element.text(el), option.Some("Status: Cool"))
  testing.stop(session)
}

pub fn init_gauge_color_is_blue_test() {
  let session = testing.start(app())
  let assert option.Some(el) = testing.find(session, "temp")
  should.equal(element.prop(el, "color"), option.Some(StringVal("#3498db")))
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// interactions -- buttons
// ---------------------------------------------------------------------------

pub fn high_sets_temperature_to_ninety_test() {
  let session = testing.start(app())
  let session = testing.click(session, "high")
  should.equal(testing.model(session).temperature, 90.0)
  testing.stop(session)
}

pub fn high_changes_gauge_color_to_red_test() {
  let session = testing.start(app())
  let session = testing.click(session, "high")
  let assert option.Some(el) = testing.find(session, "temp")
  should.equal(element.prop(el, "color"), option.Some(StringVal("#e74c3c")))
  testing.stop(session)
}

pub fn reset_after_high_returns_to_twenty_test() {
  let session = testing.start(app())
  let session = testing.click(session, "high")
  let session = testing.click(session, "reset")
  should.equal(testing.model(session).temperature, 20.0)
  should.equal(testing.model(session).target_temp, 20.0)
  testing.stop(session)
}

pub fn high_appends_to_history_test() {
  let session = testing.start(app())
  let session = testing.click(session, "high")
  should.equal(testing.model(session).history, [20.0, 90.0])
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// interactions -- slider
// ---------------------------------------------------------------------------

pub fn slider_updates_target_temp_test() {
  let session = testing.start(app())
  let session = testing.slide(session, "target", 75.0)
  should.equal(testing.model(session).target_temp, 75.0)
  testing.stop(session)
}

pub fn slider_does_not_change_temperature_test() {
  let session = testing.start(app())
  let session = testing.slide(session, "target", 75.0)
  should.equal(testing.model(session).temperature, 20.0)
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// full journey
// ---------------------------------------------------------------------------

pub fn full_journey_test() {
  let session = testing.start(app())

  // Click high
  let session = testing.click(session, "high")
  should.equal(testing.model(session).temperature, 90.0)
  should.equal(testing.model(session).history, [20.0, 90.0])

  // Slide
  let session = testing.slide(session, "target", 55.0)
  should.equal(testing.model(session).target_temp, 55.0)
  should.equal(testing.model(session).temperature, 90.0)

  // Reset
  let session = testing.click(session, "reset")
  should.equal(testing.model(session).temperature, 20.0)
  should.equal(testing.model(session).history, [20.0, 90.0, 20.0])

  testing.stop(session)
}

pub fn rapid_clicks_test() {
  let session = testing.start(app())
  let session = testing.click(session, "high")
  let session = testing.click(session, "reset")
  let session = testing.click(session, "high")
  let session = testing.click(session, "reset")
  should.equal(testing.model(session).temperature, 20.0)
  should.equal(testing.model(session).history, [20.0, 90.0, 20.0, 90.0, 20.0])
  testing.stop(session)
}
