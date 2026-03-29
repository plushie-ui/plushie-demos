import crash_lab/crashable
import gleam/dict
import gleam/list
import gleeunit/should
import plushie/command
import plushie/native_widget
import plushie/node.{StringVal}

// ---------------------------------------------------------------------------
// Extension definition
// ---------------------------------------------------------------------------

pub fn def_kind_is_crash_widget_test() {
  should.equal(crashable.def.kind, "crash_widget")
}

pub fn def_has_one_prop_test() {
  should.equal(list.length(crashable.def.props), 1)
}

pub fn def_prop_is_label_test() {
  should.equal(native_widget.prop_names(crashable.def), ["label"])
}

pub fn def_has_one_command_test() {
  should.equal(native_widget.command_names(crashable.def), ["panic"])
}

pub fn def_rust_crate_test() {
  should.equal(crashable.def.rust_crate, "native/crash_widget")
}

pub fn def_validates_test() {
  native_widget.validate(crashable.def)
  |> should.be_ok()
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

pub fn crash_widget_has_correct_kind_test() {
  let node = crashable.crash_widget("c1", [])
  should.equal(node.kind, "crash_widget")
}

pub fn crash_widget_has_correct_id_test() {
  let node = crashable.crash_widget("c1", [])
  should.equal(node.id, "c1")
}

pub fn crash_widget_default_label_is_empty_test() {
  let node = crashable.crash_widget("c1", [])
  should.equal(dict.get(node.props, "label"), Ok(StringVal("")))
}

pub fn crash_widget_custom_label_test() {
  let node = crashable.crash_widget("c1", [crashable.label("Healthy")])
  should.equal(dict.get(node.props, "label"), Ok(StringVal("Healthy")))
}

pub fn crash_widget_is_leaf_test() {
  let node = crashable.crash_widget("c1", [])
  should.equal(node.children, [])
}

// ---------------------------------------------------------------------------
// Panic command
// ---------------------------------------------------------------------------

pub fn panic_command_creates_extension_command_test() {
  let cmd = crashable.panic_command("crasher")
  case cmd {
    command.WidgetCommand(node_id:, op:, payload:) -> {
      should.equal(node_id, "crasher")
      should.equal(op, "panic")
      should.equal(dict.size(payload), 0)
    }
    _ -> should.fail()
  }
}
