//// Integration tests for the sparkline dashboard app.

import gleam/option
import gleeunit/should
import plushie/app as plushie_app
import plushie/node.{BoolVal, ListVal, StringVal}
import plushie/testing
import plushie/testing/element
import sparkline_dashboard/app

fn dashboard_app() {
  plushie_app.simple(app.init, app.update, app.view)
  |> plushie_app.with_subscriptions(app.subscribe)
}

// ---------------------------------------------------------------------------
// init
// ---------------------------------------------------------------------------

pub fn init_samples_empty_test() {
  let session = testing.start(dashboard_app())
  let model = testing.model(session)
  should.equal(model.cpu_samples, [])
  should.equal(model.mem_samples, [])
  should.equal(model.net_samples, [])
  testing.stop(session)
}

pub fn init_running_test() {
  let session = testing.start(dashboard_app())
  should.be_true(testing.model(session).running)
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// view -- widgets exist
// ---------------------------------------------------------------------------

pub fn view_has_buttons_test() {
  let session = testing.start(dashboard_app())
  should.be_true(option.is_some(testing.find(session, "toggle_running")))
  should.be_true(option.is_some(testing.find(session, "clear")))
  testing.stop(session)
}

pub fn view_has_sparkline_nodes_test() {
  let session = testing.start(dashboard_app())
  let assert option.Some(cpu) = testing.find(session, "cpu_spark")
  should.equal(element.kind(cpu), "sparkline")
  let assert option.Some(mem) = testing.find(session, "mem_spark")
  should.equal(element.kind(mem), "sparkline")
  let assert option.Some(net) = testing.find(session, "net_spark")
  should.equal(element.kind(net), "sparkline")
  testing.stop(session)
}

pub fn view_sparkline_colors_test() {
  let session = testing.start(dashboard_app())
  let assert option.Some(cpu) = testing.find(session, "cpu_spark")
  should.equal(element.prop(cpu, "color"), option.Some(StringVal("#4caf50")))
  let assert option.Some(net) = testing.find(session, "net_spark")
  should.equal(element.prop(net, "color"), option.Some(StringVal("#ff9800")))
  testing.stop(session)
}

pub fn view_cpu_has_fill_net_does_not_test() {
  let session = testing.start(dashboard_app())
  let assert option.Some(cpu) = testing.find(session, "cpu_spark")
  should.equal(element.prop(cpu, "fill"), option.Some(BoolVal(True)))
  let assert option.Some(net) = testing.find(session, "net_spark")
  should.equal(element.prop(net, "fill"), option.Some(BoolVal(False)))
  testing.stop(session)
}

pub fn view_initial_data_is_empty_test() {
  let session = testing.start(dashboard_app())
  let assert option.Some(cpu) = testing.find(session, "cpu_spark")
  should.equal(element.prop(cpu, "data"), option.Some(ListVal([])))
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// interactions -- toggle and clear
// ---------------------------------------------------------------------------

pub fn toggle_pauses_test() {
  let session = testing.start(dashboard_app())
  should.be_true(testing.model(session).running)
  let session = testing.click(session, "toggle_running")
  should.be_false(testing.model(session).running)
  testing.stop(session)
}

pub fn toggle_resumes_test() {
  let session = testing.start(dashboard_app())
  let session = testing.click(session, "toggle_running")
  let session = testing.click(session, "toggle_running")
  should.be_true(testing.model(session).running)
  testing.stop(session)
}

pub fn toggle_label_changes_test() {
  let session = testing.start(dashboard_app())
  let assert option.Some(btn) = testing.find(session, "toggle_running")
  should.equal(element.text(btn), option.Some("Pause"))

  let session = testing.click(session, "toggle_running")
  let assert option.Some(btn) = testing.find(session, "toggle_running")
  should.equal(element.text(btn), option.Some("Resume"))
  testing.stop(session)
}

// ---------------------------------------------------------------------------
// metrics -- range validation
// ---------------------------------------------------------------------------

pub fn cpu_sample_in_range_test() {
  let v = app.cpu_sample(0)
  should.be_true(v >=. 0.0)
  should.be_true(v <=. 100.0)
}

pub fn mem_sample_in_range_test() {
  let v = app.mem_sample(0)
  should.be_true(v >=. 20.0)
  should.be_true(v <=. 100.0)
}

pub fn net_sample_in_range_test() {
  let v = app.net_sample()
  should.be_true(v >=. 0.0)
  should.be_true(v <=. 100.0)
}

// ---------------------------------------------------------------------------
// cap_samples
// ---------------------------------------------------------------------------

pub fn cap_samples_adds_value_test() {
  should.equal(app.cap_samples([1.0, 2.0], 3.0), [1.0, 2.0, 3.0])
}
