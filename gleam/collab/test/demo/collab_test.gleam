import demo/collab.{Model}
import gleam/dict
import gleam/list
import gleam/option
import gleeunit/should
import plushie/command
import plushie/event
import plushie/node.{type Node, BoolVal, StringVal}

// ---------------------------------------------------------------------------
// init
// ---------------------------------------------------------------------------

pub fn init_name_is_empty_test() {
  let #(model, _) = collab.init()
  should.equal(model.name, "")
}

pub fn init_notes_is_empty_test() {
  let #(model, _) = collab.init()
  should.equal(model.notes, "")
}

pub fn init_count_is_zero_test() {
  let #(model, _) = collab.init()
  should.equal(model.count, 0)
}

pub fn init_dark_mode_is_false_test() {
  let #(model, _) = collab.init()
  should.be_false(model.dark_mode)
}

pub fn init_status_is_empty_test() {
  let #(model, _) = collab.init()
  should.equal(model.status, "")
}

pub fn init_returns_no_command_test() {
  let #(_, cmd) = collab.init()
  should.equal(cmd, command.none())
}

// ---------------------------------------------------------------------------
// update -- counter
// ---------------------------------------------------------------------------

pub fn inc_increments_count_test() {
  let #(model, _) = collab.init()
  let #(model, _) =
    collab.update(model, event.WidgetClick(id: "inc", scope: []))
  should.equal(model.count, 1)
}

pub fn dec_decrements_count_test() {
  let model = Model(name: "", notes: "", count: 5, dark_mode: False, status: "")
  let #(model, _) =
    collab.update(model, event.WidgetClick(id: "dec", scope: []))
  should.equal(model.count, 4)
}

pub fn inc_preserves_other_fields_test() {
  let model =
    Model(
      name: "Alice",
      notes: "hello",
      count: 0,
      dark_mode: True,
      status: "1 connected",
    )
  let #(model, _) =
    collab.update(model, event.WidgetClick(id: "inc", scope: []))
  should.equal(model.name, "Alice")
  should.equal(model.notes, "hello")
  should.be_true(model.dark_mode)
  should.equal(model.status, "1 connected")
  should.equal(model.count, 1)
}

pub fn dec_below_zero_test() {
  let #(model, _) = collab.init()
  let #(model, _) =
    collab.update(model, event.WidgetClick(id: "dec", scope: []))
  should.equal(model.count, -1)
}

pub fn counter_returns_no_command_test() {
  let #(model, _) = collab.init()
  let #(_, cmd) = collab.update(model, event.WidgetClick(id: "inc", scope: []))
  should.equal(cmd, command.none())
}

// ---------------------------------------------------------------------------
// update -- text inputs
// ---------------------------------------------------------------------------

pub fn name_input_updates_name_test() {
  let #(model, _) = collab.init()
  let #(model, _) =
    collab.update(model, event.WidgetInput(id: "name", scope: [], value: "Bob"))
  should.equal(model.name, "Bob")
}

pub fn name_input_preserves_other_fields_test() {
  let model =
    Model(name: "", notes: "stuff", count: 3, dark_mode: False, status: "ok")
  let #(model, _) =
    collab.update(model, event.WidgetInput(id: "name", scope: [], value: "Eve"))
  should.equal(model.notes, "stuff")
  should.equal(model.count, 3)
  should.equal(model.status, "ok")
}

pub fn notes_input_updates_notes_test() {
  let #(model, _) = collab.init()
  let #(model, _) =
    collab.update(
      model,
      event.WidgetInput(id: "notes", scope: [], value: "Meeting at 3pm"),
    )
  should.equal(model.notes, "Meeting at 3pm")
}

pub fn notes_input_preserves_other_fields_test() {
  let model =
    Model(
      name: "Carol",
      notes: "",
      count: 7,
      dark_mode: True,
      status: "2 connected",
    )
  let #(model, _) =
    collab.update(
      model,
      event.WidgetInput(id: "notes", scope: [], value: "new note"),
    )
  should.equal(model.name, "Carol")
  should.equal(model.count, 7)
  should.be_true(model.dark_mode)
}

pub fn text_input_returns_no_command_test() {
  let #(model, _) = collab.init()
  let #(_, cmd) =
    collab.update(model, event.WidgetInput(id: "name", scope: [], value: "x"))
  should.equal(cmd, command.none())
}

// ---------------------------------------------------------------------------
// update -- theme toggle
// ---------------------------------------------------------------------------

pub fn theme_toggle_enables_dark_mode_test() {
  let #(model, _) = collab.init()
  should.be_false(model.dark_mode)
  let #(model, _) =
    collab.update(
      model,
      event.WidgetToggle(id: "theme", scope: [], value: True),
    )
  should.be_true(model.dark_mode)
}

pub fn theme_toggle_disables_dark_mode_test() {
  let model = Model(name: "", notes: "", count: 0, dark_mode: True, status: "")
  let #(model, _) =
    collab.update(
      model,
      event.WidgetToggle(id: "theme", scope: [], value: False),
    )
  should.be_false(model.dark_mode)
}

pub fn theme_toggle_preserves_other_fields_test() {
  let model =
    Model(
      name: "Dan",
      notes: "hi",
      count: 42,
      dark_mode: False,
      status: "3 connected",
    )
  let #(model, _) =
    collab.update(
      model,
      event.WidgetToggle(id: "theme", scope: [], value: True),
    )
  should.equal(model.name, "Dan")
  should.equal(model.notes, "hi")
  should.equal(model.count, 42)
  should.equal(model.status, "3 connected")
}

pub fn theme_toggle_returns_no_command_test() {
  let #(model, _) = collab.init()
  let #(_, cmd) =
    collab.update(
      model,
      event.WidgetToggle(id: "theme", scope: [], value: True),
    )
  should.equal(cmd, command.none())
}

// ---------------------------------------------------------------------------
// update -- unknown events
// ---------------------------------------------------------------------------

pub fn unknown_click_returns_model_unchanged_test() {
  let model =
    Model(
      name: "test",
      notes: "note",
      count: 5,
      dark_mode: True,
      status: "1 connected",
    )
  let #(new_model, _) =
    collab.update(model, event.WidgetClick(id: "nonexistent", scope: []))
  should.equal(new_model, model)
}

pub fn unknown_event_returns_no_command_test() {
  let #(model, _) = collab.init()
  let #(_, cmd) =
    collab.update(model, event.WidgetClick(id: "nonexistent", scope: []))
  should.equal(cmd, command.none())
}

// ---------------------------------------------------------------------------
// view -- structure
// ---------------------------------------------------------------------------

pub fn view_root_is_window_test() {
  let #(model, _) = collab.init()
  let tree = collab.view(model)
  should.equal(tree.kind, "window")
  should.equal(tree.id, "main")
}

pub fn view_window_has_title_test() {
  let #(model, _) = collab.init()
  let tree = collab.view(model)
  should.equal(dict.get(tree.props, "title"), Ok(StringVal("Plushie Demo")))
}

pub fn view_contains_header_text_test() {
  let #(model, _) = collab.init()
  let tree = collab.view(model)
  should.be_true(option.is_some(find_node(tree, "header")))
}

pub fn view_contains_name_input_test() {
  let #(model, _) = collab.init()
  let tree = collab.view(model)
  should.be_true(option.is_some(find_node(tree, "name")))
}

pub fn view_contains_notes_input_test() {
  let #(model, _) = collab.init()
  let tree = collab.view(model)
  should.be_true(option.is_some(find_node(tree, "notes")))
}

pub fn view_contains_inc_button_test() {
  let #(model, _) = collab.init()
  let tree = collab.view(model)
  should.be_true(option.is_some(find_node(tree, "inc")))
}

pub fn view_contains_dec_button_test() {
  let #(model, _) = collab.init()
  let tree = collab.view(model)
  should.be_true(option.is_some(find_node(tree, "dec")))
}

pub fn view_contains_count_text_test() {
  let #(model, _) = collab.init()
  let tree = collab.view(model)
  should.be_true(option.is_some(find_node(tree, "count")))
}

pub fn view_contains_theme_checkbox_test() {
  let #(model, _) = collab.init()
  let tree = collab.view(model)
  should.be_true(option.is_some(find_node(tree, "theme")))
}

pub fn view_contains_status_text_test() {
  let #(model, _) = collab.init()
  let tree = collab.view(model)
  should.be_true(option.is_some(find_node(tree, "status")))
}

// ---------------------------------------------------------------------------
// view -- content reflects model
// ---------------------------------------------------------------------------

pub fn view_count_text_reflects_model_test() {
  let model =
    Model(name: "", notes: "", count: 42, dark_mode: False, status: "")
  let tree = collab.view(model)
  let assert option.Some(count_node) = find_node(tree, "count")
  should.equal(
    dict.get(count_node.props, "content"),
    Ok(StringVal("Count: 42")),
  )
}

pub fn view_name_input_value_reflects_model_test() {
  let model =
    Model(name: "Alice", notes: "", count: 0, dark_mode: False, status: "")
  let tree = collab.view(model)
  let assert option.Some(name_node) = find_node(tree, "name")
  should.equal(dict.get(name_node.props, "value"), Ok(StringVal("Alice")))
}

pub fn view_notes_input_value_reflects_model_test() {
  let model =
    Model(name: "", notes: "some notes", count: 0, dark_mode: False, status: "")
  let tree = collab.view(model)
  let assert option.Some(notes_node) = find_node(tree, "notes")
  should.equal(dict.get(notes_node.props, "value"), Ok(StringVal("some notes")))
}

pub fn view_status_text_reflects_model_test() {
  let model =
    Model(
      name: "",
      notes: "",
      count: 0,
      dark_mode: False,
      status: "3 connected",
    )
  let tree = collab.view(model)
  let assert option.Some(status_node) = find_node(tree, "status")
  should.equal(
    dict.get(status_node.props, "content"),
    Ok(StringVal("3 connected")),
  )
}

pub fn view_checkbox_reflects_dark_mode_false_test() {
  let model = Model(name: "", notes: "", count: 0, dark_mode: False, status: "")
  let tree = collab.view(model)
  let assert option.Some(theme_node) = find_node(tree, "theme")
  should.equal(dict.get(theme_node.props, "is_toggled"), Ok(BoolVal(False)))
}

pub fn view_checkbox_reflects_dark_mode_true_test() {
  let model = Model(name: "", notes: "", count: 0, dark_mode: True, status: "")
  let tree = collab.view(model)
  let assert option.Some(theme_node) = find_node(tree, "theme")
  should.equal(dict.get(theme_node.props, "is_toggled"), Ok(BoolVal(True)))
}

// ---------------------------------------------------------------------------
// view -- theming
// ---------------------------------------------------------------------------

pub fn view_themer_uses_light_when_not_dark_test() {
  let model = Model(name: "", notes: "", count: 0, dark_mode: False, status: "")
  let tree = collab.view(model)
  let assert option.Some(themer_node) = find_node(tree, "theme-root")
  should.equal(dict.get(themer_node.props, "theme"), Ok(StringVal("light")))
}

pub fn view_themer_uses_dark_when_dark_test() {
  let model = Model(name: "", notes: "", count: 0, dark_mode: True, status: "")
  let tree = collab.view(model)
  let assert option.Some(themer_node) = find_node(tree, "theme-root")
  should.equal(dict.get(themer_node.props, "theme"), Ok(StringVal("dark")))
}

// ---------------------------------------------------------------------------
// Full journey
// ---------------------------------------------------------------------------

pub fn full_journey_test() {
  // Start fresh
  let #(model, _) = collab.init()
  should.equal(model.count, 0)
  should.equal(model.name, "")

  // Set name
  let #(model, _) =
    collab.update(
      model,
      event.WidgetInput(id: "name", scope: [], value: "Alice"),
    )
  should.equal(model.name, "Alice")

  // Increment twice
  let #(model, _) =
    collab.update(model, event.WidgetClick(id: "inc", scope: []))
  let #(model, _) =
    collab.update(model, event.WidgetClick(id: "inc", scope: []))
  should.equal(model.count, 2)

  // Add notes
  let #(model, _) =
    collab.update(
      model,
      event.WidgetInput(id: "notes", scope: [], value: "Meeting at 3pm"),
    )
  should.equal(model.notes, "Meeting at 3pm")

  // Toggle dark mode
  let #(model, _) =
    collab.update(
      model,
      event.WidgetToggle(id: "theme", scope: [], value: True),
    )
  should.be_true(model.dark_mode)

  // Decrement
  let #(model, _) =
    collab.update(model, event.WidgetClick(id: "dec", scope: []))
  should.equal(model.count, 1)

  // All state preserved
  should.equal(model.name, "Alice")
  should.equal(model.notes, "Meeting at 3pm")
  should.be_true(model.dark_mode)
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
