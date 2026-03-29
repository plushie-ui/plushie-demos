import gleam/dict
import gleam/list
import gleeunit/should
import plushie/native_widget
import plushie/node.{BoolVal, FloatVal, ListVal, StringVal}
import plushie/prop/color
import sparkline_dashboard/sparkline

// ---------------------------------------------------------------------------
// Extension definition
// ---------------------------------------------------------------------------

pub fn def_kind_is_sparkline_test() {
  should.equal(sparkline.def.kind, "sparkline")
}

pub fn def_has_five_props_test() {
  should.equal(list.length(sparkline.def.props), 5)
}

pub fn def_prop_names_test() {
  let names = native_widget.prop_names(sparkline.def)
  should.equal(names, ["data", "color", "stroke_width", "fill", "height"])
}

pub fn def_has_no_commands_test() {
  let names = native_widget.command_names(sparkline.def)
  should.equal(names, [])
}

pub fn def_rust_crate_test() {
  should.equal(sparkline.def.rust_crate, "native/sparkline")
}

pub fn def_rust_constructor_test() {
  should.equal(
    sparkline.def.rust_constructor,
    "sparkline::SparklineExtension::new()",
  )
}

pub fn def_validates_successfully_test() {
  native_widget.validate(sparkline.def)
  |> should.be_ok()
}

// ---------------------------------------------------------------------------
// Widget builder -- basic output
// ---------------------------------------------------------------------------

pub fn sparkline_creates_node_with_correct_kind_test() {
  let node = sparkline.sparkline("s1", [1.0, 2.0, 3.0], [])
  should.equal(node.kind, "sparkline")
}

pub fn sparkline_creates_node_with_correct_id_test() {
  let node = sparkline.sparkline("s1", [1.0], [])
  should.equal(node.id, "s1")
}

pub fn sparkline_node_is_leaf_test() {
  let node = sparkline.sparkline("s1", [], [])
  should.equal(node.children, [])
}

pub fn sparkline_node_has_all_five_props_test() {
  let node = sparkline.sparkline("s1", [], [])
  should.equal(dict.size(node.props), 5)
}

// ---------------------------------------------------------------------------
// Widget builder -- data encoding
// ---------------------------------------------------------------------------

pub fn sparkline_encodes_data_as_list_val_test() {
  let node = sparkline.sparkline("s1", [10.0, 20.0, 30.0], [])
  should.equal(
    dict.get(node.props, "data"),
    Ok(ListVal([FloatVal(10.0), FloatVal(20.0), FloatVal(30.0)])),
  )
}

pub fn sparkline_empty_data_encodes_as_empty_list_test() {
  let node = sparkline.sparkline("s1", [], [])
  should.equal(dict.get(node.props, "data"), Ok(ListVal([])))
}

pub fn sparkline_single_point_data_test() {
  let node = sparkline.sparkline("s1", [42.0], [])
  should.equal(dict.get(node.props, "data"), Ok(ListVal([FloatVal(42.0)])))
}

// ---------------------------------------------------------------------------
// Widget builder -- defaults
// ---------------------------------------------------------------------------

pub fn sparkline_default_color_is_green_test() {
  let node = sparkline.sparkline("s1", [], [])
  should.equal(dict.get(node.props, "color"), Ok(StringVal("#4caf50")))
}

pub fn sparkline_default_stroke_width_test() {
  let node = sparkline.sparkline("s1", [], [])
  should.equal(dict.get(node.props, "stroke_width"), Ok(FloatVal(2.0)))
}

pub fn sparkline_default_fill_is_false_test() {
  let node = sparkline.sparkline("s1", [], [])
  should.equal(dict.get(node.props, "fill"), Ok(BoolVal(False)))
}

pub fn sparkline_default_height_test() {
  let node = sparkline.sparkline("s1", [], [])
  should.equal(dict.get(node.props, "height"), Ok(FloatVal(60.0)))
}

// ---------------------------------------------------------------------------
// Widget builder -- explicit attrs
// ---------------------------------------------------------------------------

pub fn sparkline_custom_color_test() {
  let assert Ok(blue) = color.from_hex("#2196F3")
  let node = sparkline.sparkline("s1", [], [sparkline.color(blue)])
  should.equal(dict.get(node.props, "color"), Ok(StringVal("#2196f3")))
}

pub fn sparkline_custom_stroke_width_test() {
  let node = sparkline.sparkline("s1", [], [sparkline.stroke_width(3.5)])
  should.equal(dict.get(node.props, "stroke_width"), Ok(FloatVal(3.5)))
}

pub fn sparkline_fill_enabled_test() {
  let node = sparkline.sparkline("s1", [], [sparkline.fill(True)])
  should.equal(dict.get(node.props, "fill"), Ok(BoolVal(True)))
}

pub fn sparkline_custom_height_test() {
  let node = sparkline.sparkline("s1", [], [sparkline.height(120.0)])
  should.equal(dict.get(node.props, "height"), Ok(FloatVal(120.0)))
}

pub fn sparkline_all_attrs_test() {
  let assert Ok(orange) = color.from_hex("#FF9800")
  let node =
    sparkline.sparkline("s1", [1.0, 2.0], [
      sparkline.color(orange),
      sparkline.stroke_width(4.0),
      sparkline.fill(True),
      sparkline.height(80.0),
    ])
  should.equal(node.kind, "sparkline")
  should.equal(dict.get(node.props, "color"), Ok(StringVal("#ff9800")))
  should.equal(dict.get(node.props, "stroke_width"), Ok(FloatVal(4.0)))
  should.equal(dict.get(node.props, "fill"), Ok(BoolVal(True)))
  should.equal(dict.get(node.props, "height"), Ok(FloatVal(80.0)))
  should.equal(
    dict.get(node.props, "data"),
    Ok(ListVal([FloatVal(1.0), FloatVal(2.0)])),
  )
}
