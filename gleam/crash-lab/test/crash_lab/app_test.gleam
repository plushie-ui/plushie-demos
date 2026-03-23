import crash_lab/app.{Model}
import gleam/dict
import gleam/list
import gleam/option
import gleeunit/should
import plushie/command
import plushie/event
import plushie/node.{type Node, StringVal}

// ---------------------------------------------------------------------------
// init
// ---------------------------------------------------------------------------

pub fn init_count_is_zero_test() {
  let #(model, _) = app.init()
  should.equal(model.count, 0)
}

pub fn init_widget_alive_test() {
  let #(model, _) = app.init()
  should.be_true(model.widget_alive)
}

pub fn init_returns_no_command_test() {
  let #(_, cmd) = app.init()
  should.equal(cmd, command.none())
}

// ---------------------------------------------------------------------------
// update -- counter
// ---------------------------------------------------------------------------

pub fn inc_increments_count_test() {
  let #(model, _) = app.init()
  let #(model, _) = app.update(model, event.WidgetClick(id: "inc", scope: []))
  should.equal(model.count, 1)
}

pub fn dec_decrements_count_test() {
  let model = Model(count: 5, widget_alive: True)
  let #(model, _) = app.update(model, event.WidgetClick(id: "dec", scope: []))
  should.equal(model.count, 4)
}

pub fn counter_returns_no_command_test() {
  let #(model, _) = app.init()
  let #(_, cmd) = app.update(model, event.WidgetClick(id: "inc", scope: []))
  should.equal(cmd, command.none())
}

// ---------------------------------------------------------------------------
// update -- panic extension
// ---------------------------------------------------------------------------

pub fn panic_extension_returns_extension_command_test() {
  let #(model, _) = app.init()
  let #(_, cmd) =
    app.update(model, event.WidgetClick(id: "panic-extension", scope: []))
  case cmd {
    command.ExtensionCommand(node_id:, op:, ..) -> {
      should.equal(node_id, "crasher")
      should.equal(op, "panic")
    }
    _ -> should.fail()
  }
}

pub fn panic_extension_does_not_mutate_model_test() {
  let model = Model(count: 42, widget_alive: True)
  let #(new_model, _) =
    app.update(model, event.WidgetClick(id: "panic-extension", scope: []))
  should.equal(new_model, model)
}

// ---------------------------------------------------------------------------
// update -- toggle widget
// ---------------------------------------------------------------------------

pub fn toggle_removes_widget_test() {
  let model = Model(count: 0, widget_alive: True)
  let #(model, _) =
    app.update(model, event.WidgetClick(id: "toggle-widget", scope: []))
  should.be_false(model.widget_alive)
}

pub fn toggle_restores_widget_test() {
  let model = Model(count: 0, widget_alive: False)
  let #(model, _) =
    app.update(model, event.WidgetClick(id: "toggle-widget", scope: []))
  should.be_true(model.widget_alive)
}

pub fn toggle_preserves_count_test() {
  let model = Model(count: 42, widget_alive: True)
  let #(model, _) =
    app.update(model, event.WidgetClick(id: "toggle-widget", scope: []))
  should.equal(model.count, 42)
}

// ---------------------------------------------------------------------------
// update -- unknown event
// ---------------------------------------------------------------------------

pub fn unknown_event_returns_model_unchanged_test() {
  let model = Model(count: 7, widget_alive: True)
  let #(new_model, _) =
    app.update(model, event.WidgetClick(id: "nonexistent", scope: []))
  should.equal(new_model, model)
}

pub fn unknown_event_returns_no_command_test() {
  let #(model, _) = app.init()
  let #(_, cmd) =
    app.update(model, event.WidgetClick(id: "nonexistent", scope: []))
  should.equal(cmd, command.none())
}

// ---------------------------------------------------------------------------
// view -- structure
// ---------------------------------------------------------------------------

pub fn view_root_is_window_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  should.equal(tree.kind, "window")
  should.equal(tree.id, "main")
}

pub fn view_has_title_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  should.equal(dict.get(tree.props, "title"), Ok(StringVal("Crash Lab")))
}

pub fn view_contains_counter_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  should.be_true(option.is_some(find_node(tree, "count")))
  should.be_true(option.is_some(find_node(tree, "inc")))
  should.be_true(option.is_some(find_node(tree, "dec")))
}

pub fn view_count_reflects_model_test() {
  let model = Model(count: 42, widget_alive: True)
  let tree = app.view(model)
  let assert option.Some(count_node) = find_node(tree, "count")
  should.equal(dict.get(count_node.props, "content"), Ok(StringVal("42")))
}

pub fn view_contains_crash_buttons_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  should.be_true(option.is_some(find_node(tree, "panic-extension")))
  should.be_true(option.is_some(find_node(tree, "toggle-widget")))
  should.be_true(option.is_some(find_node(tree, "panic-gleam")))
}

// ---------------------------------------------------------------------------
// view -- widget alive/removed
// ---------------------------------------------------------------------------

pub fn view_shows_crash_widget_when_alive_test() {
  let model = Model(count: 0, widget_alive: True)
  let tree = app.view(model)
  let assert option.Some(crasher) = find_node(tree, "crasher")
  should.equal(crasher.kind, "crash_widget")
}

pub fn view_hides_crash_widget_when_removed_test() {
  let model = Model(count: 0, widget_alive: False)
  let tree = app.view(model)
  should.be_true(option.is_none(find_node(tree, "crasher")))
}

pub fn view_shows_removed_message_when_widget_off_test() {
  let model = Model(count: 0, widget_alive: False)
  let tree = app.view(model)
  should.be_true(option.is_some(find_node(tree, "widget-removed")))
}

pub fn view_toggle_label_changes_test() {
  let alive = Model(count: 0, widget_alive: True)
  let tree = app.view(alive)
  let assert option.Some(btn) = find_node(tree, "toggle-widget")
  should.equal(dict.get(btn.props, "label"), Ok(StringVal("Remove Widget")))

  let removed = Model(count: 0, widget_alive: False)
  let tree = app.view(removed)
  let assert option.Some(btn) = find_node(tree, "toggle-widget")
  should.equal(dict.get(btn.props, "label"), Ok(StringVal("Restore Widget")))
}

// ---------------------------------------------------------------------------
// Counter survives extension panic (simulated)
// ---------------------------------------------------------------------------

pub fn counter_works_after_panic_command_test() {
  let #(model, _) = app.init()
  // Increment counter
  let #(model, _) = app.update(model, event.WidgetClick(id: "inc", scope: []))
  let #(model, _) = app.update(model, event.WidgetClick(id: "inc", scope: []))
  should.equal(model.count, 2)
  // Trigger extension panic (command returned, model unchanged)
  let #(model, _) =
    app.update(model, event.WidgetClick(id: "panic-extension", scope: []))
  should.equal(model.count, 2)
  // Counter still works
  let #(model, _) = app.update(model, event.WidgetClick(id: "inc", scope: []))
  should.equal(model.count, 3)
}

// ---------------------------------------------------------------------------
// Full recovery sequence
// ---------------------------------------------------------------------------

pub fn full_recovery_sequence_test() {
  let #(model, _) = app.init()

  // Build up some state
  let #(model, _) = app.update(model, event.WidgetClick(id: "inc", scope: []))
  let #(model, _) = app.update(model, event.WidgetClick(id: "inc", scope: []))
  let #(model, _) = app.update(model, event.WidgetClick(id: "inc", scope: []))
  should.equal(model.count, 3)
  should.be_true(model.widget_alive)

  // Trigger extension panic (model unaffected)
  let #(model, _) =
    app.update(model, event.WidgetClick(id: "panic-extension", scope: []))
  should.equal(model.count, 3)

  // Remove poisoned widget from tree
  let #(model, _) =
    app.update(model, event.WidgetClick(id: "toggle-widget", scope: []))
  should.be_false(model.widget_alive)

  // Re-add widget (fresh instance, no poison)
  let #(model, _) =
    app.update(model, event.WidgetClick(id: "toggle-widget", scope: []))
  should.be_true(model.widget_alive)

  // Counter still intact
  should.equal(model.count, 3)

  // Counter still works after full recovery
  let #(model, _) = app.update(model, event.WidgetClick(id: "inc", scope: []))
  should.equal(model.count, 4)
}

// ---------------------------------------------------------------------------
// Tree search helper
// ---------------------------------------------------------------------------

fn find_node(node: Node, target_id: String) -> option.Option(Node) {
  case node.id == target_id {
    True -> option.Some(node)
    False ->
      list.fold(node.children, option.None, fn(acc, child) {
        case acc {
          option.Some(_) -> acc
          option.None -> find_node(child, target_id)
        }
      })
  }
}
