//// Crash widget extension definition.
////
//// A minimal native widget that renders a label. Its only command,
//// `panic`, deliberately panics inside the Rust extension's
//// `handle_command`, triggering plushie's panic isolation. The
//// renderer catches the panic via `catch_unwind`, marks the
//// extension as poisoned, and replaces the widget with an error
//// placeholder. The rest of the app continues running.

import gleam/list
import gleam/result
import plushie/command.{type Command}
import plushie/extension
import plushie/node.{type Node, StringVal}

/// Extension definition for the crash widget.
pub const def = extension.ExtensionDef(
  kind: "crash_widget",
  rust_crate: "native/crash_widget",
  rust_constructor: "crash_widget::CrashExtension::new()",
  props: [extension.StringProp("label")],
  commands: [extension.CommandDef("panic", [])],
)

/// Attribute for configuring the crash widget.
pub type CrashAttr {
  Label(String)
}

/// Set the widget label.
pub fn label(text: String) -> CrashAttr {
  Label(text)
}

/// Build a crash widget node.
pub fn crash_widget(id: String, attrs: List(CrashAttr)) -> Node {
  extension.build(def, id, [
    #("label", StringVal(resolve_label(attrs))),
  ])
}

/// Send the panic command to a crash widget instance.
///
/// This will cause the Rust extension's `handle_command` to panic.
/// The renderer catches the panic and poisons the extension -- the
/// widget is replaced with an error placeholder, but the rest of
/// the app keeps running.
pub fn panic_command(node_id: String) -> Command(msg) {
  extension.command(def, node_id, "panic", [])
}

fn resolve_label(attrs: List(CrashAttr)) -> String {
  attrs
  |> list.find_map(fn(a) {
    case a {
      Label(s) -> Ok(s)
    }
  })
  |> result.unwrap("")
}
