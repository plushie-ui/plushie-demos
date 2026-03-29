import gauge_demo/gauge
import gleam/dict
import gleam/list
import gleeunit/should
import plushie/command
import plushie/native_widget
import plushie/node.{FloatVal, StringVal}
import plushie/prop/color
import plushie/prop/length.{Fixed}

// ---------------------------------------------------------------------------
// Extension definition
// ---------------------------------------------------------------------------

pub fn def_kind_is_gauge_test() {
  should.equal(gauge.def.kind, "gauge")
}

pub fn def_has_seven_props_test() {
  should.equal(list.length(gauge.def.props), 7)
}

pub fn def_prop_names_test() {
  let names = native_widget.prop_names(gauge.def)
  should.equal(names, [
    "value", "min", "max", "color", "label", "width", "height",
  ])
}

pub fn def_has_two_commands_test() {
  let names = native_widget.command_names(gauge.def)
  should.equal(names, ["set_value", "animate_to"])
}

pub fn def_rust_crate_test() {
  should.equal(gauge.def.rust_crate, "native/gauge")
}

pub fn def_rust_constructor_test() {
  should.equal(gauge.def.rust_constructor, "gauge::GaugeExtension::new()")
}

pub fn def_validates_successfully_test() {
  native_widget.validate(gauge.def)
  |> should.be_ok()
}

// ---------------------------------------------------------------------------
// Widget builder -- basic output
// ---------------------------------------------------------------------------

pub fn gauge_creates_node_with_correct_kind_test() {
  let node = build_gauge_with_all_attrs()
  should.equal(node.kind, "gauge")
}

pub fn gauge_creates_node_with_correct_id_test() {
  let node = build_gauge_with_all_attrs()
  should.equal(node.id, "g1")
}

pub fn gauge_node_is_leaf_test() {
  let node = build_gauge_with_all_attrs()
  should.equal(node.children, [])
}

pub fn gauge_node_has_all_seven_props_test() {
  let node = build_gauge_with_all_attrs()
  should.equal(dict.size(node.props), 7)
}

// ---------------------------------------------------------------------------
// Widget builder -- explicit props
// ---------------------------------------------------------------------------

pub fn gauge_node_has_value_prop_test() {
  let node = build_gauge_with_all_attrs()
  should.equal(dict.get(node.props, "value"), Ok(FloatVal(42.0)))
}

pub fn gauge_node_has_min_prop_test() {
  let node = build_gauge_with_all_attrs()
  should.equal(dict.get(node.props, "min"), Ok(FloatVal(10.0)))
}

pub fn gauge_node_has_max_prop_test() {
  let node = build_gauge_with_all_attrs()
  should.equal(dict.get(node.props, "max"), Ok(FloatVal(200.0)))
}

pub fn gauge_node_has_color_prop_test() {
  let node = build_gauge_with_all_attrs()
  should.equal(dict.get(node.props, "color"), Ok(StringVal("#e74c3c")))
}

pub fn gauge_node_has_label_prop_test() {
  let node = build_gauge_with_all_attrs()
  should.equal(dict.get(node.props, "label"), Ok(StringVal("42\u{00B0}C")))
}

pub fn gauge_node_has_width_prop_test() {
  let node = build_gauge_with_all_attrs()
  should.equal(dict.get(node.props, "width"), Ok(FloatVal(300.0)))
}

pub fn gauge_node_has_height_prop_test() {
  let node = build_gauge_with_all_attrs()
  should.equal(dict.get(node.props, "height"), Ok(FloatVal(300.0)))
}

// ---------------------------------------------------------------------------
// Widget builder -- defaults
// ---------------------------------------------------------------------------

pub fn gauge_default_min_is_zero_test() {
  let node = gauge.gauge("g2", 50.0, [])
  should.equal(dict.get(node.props, "min"), Ok(FloatVal(0.0)))
}

pub fn gauge_default_max_is_hundred_test() {
  let node = gauge.gauge("g2", 50.0, [])
  should.equal(dict.get(node.props, "max"), Ok(FloatVal(100.0)))
}

pub fn gauge_default_label_is_empty_test() {
  let node = gauge.gauge("g2", 50.0, [])
  should.equal(dict.get(node.props, "label"), Ok(StringVal("")))
}

pub fn gauge_default_width_is_200_test() {
  let node = gauge.gauge("g2", 50.0, [])
  should.equal(dict.get(node.props, "width"), Ok(FloatVal(200.0)))
}

pub fn gauge_default_height_is_200_test() {
  let node = gauge.gauge("g2", 50.0, [])
  should.equal(dict.get(node.props, "height"), Ok(FloatVal(200.0)))
}

pub fn gauge_default_color_is_blue_test() {
  let node = gauge.gauge("g2", 50.0, [])
  should.equal(dict.get(node.props, "color"), Ok(StringVal("#3498db")))
}

pub fn gauge_minimal_still_has_all_props_test() {
  let node = gauge.gauge("g2", 50.0, [])
  should.equal(dict.size(node.props), 7)
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

pub fn set_value_creates_extension_command_test() {
  let cmd = gauge.set_value("temp", 90.0)
  case cmd {
    command.WidgetCommand(node_id:, op:, payload:) -> {
      should.equal(node_id, "temp")
      should.equal(op, "set_value")
      should.equal(dict.get(payload, "value"), Ok(FloatVal(90.0)))
    }
    _ -> should.fail()
  }
}

pub fn animate_to_creates_extension_command_test() {
  let cmd = gauge.animate_to("temp", 75.0)
  case cmd {
    command.WidgetCommand(node_id:, op:, payload:) -> {
      should.equal(node_id, "temp")
      should.equal(op, "animate_to")
      should.equal(dict.get(payload, "value"), Ok(FloatVal(75.0)))
    }
    _ -> should.fail()
  }
}

pub fn set_value_payload_has_single_entry_test() {
  let cmd = gauge.set_value("temp", 50.0)
  case cmd {
    command.WidgetCommand(payload:, ..) ->
      should.equal(dict.size(payload), 1)
    _ -> should.fail()
  }
}

pub fn animate_to_payload_has_single_entry_test() {
  let cmd = gauge.animate_to("temp", 50.0)
  case cmd {
    command.WidgetCommand(payload:, ..) ->
      should.equal(dict.size(payload), 1)
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn build_gauge_with_all_attrs() {
  let assert Ok(red) = color.from_hex("#e74c3c")
  gauge.gauge("g1", 42.0, [
    gauge.min(10.0),
    gauge.max(200.0),
    gauge.color(red),
    gauge.label("42\u{00B0}C"),
    gauge.width(Fixed(300.0)),
    gauge.height(Fixed(300.0)),
  ])
}
