import gauge_demo/app.{Model}
import gleam/dict
import gleam/list
import gleam/option
import gleeunit/should
import plushie/command
import plushie/event
import plushie/node.{type Node, FloatVal, StringVal}
import plushie/prop/color

// ---------------------------------------------------------------------------
// init
// ---------------------------------------------------------------------------

pub fn init_temperature_is_twenty_test() {
  let #(model, _) = app.init()
  should.equal(model.temperature, 20.0)
}

pub fn init_target_temp_is_twenty_test() {
  let #(model, _) = app.init()
  should.equal(model.target_temp, 20.0)
}

pub fn init_history_has_single_entry_test() {
  let #(model, _) = app.init()
  should.equal(model.history, [20.0])
}

pub fn init_returns_no_command_test() {
  let #(_, cmd) = app.init()
  should.equal(cmd, command.none())
}

// ---------------------------------------------------------------------------
// update -- slider
// ---------------------------------------------------------------------------

pub fn slider_updates_target_temp_test() {
  let #(model, _) = app.init()
  let event = event.WidgetSlide(id: "target", scope: [], value: 75.0)
  let #(new_model, _) = app.update(model, event)
  should.equal(new_model.target_temp, 75.0)
}

pub fn slider_does_not_change_temperature_test() {
  let #(model, _) = app.init()
  let event = event.WidgetSlide(id: "target", scope: [], value: 75.0)
  let #(new_model, _) = app.update(model, event)
  should.equal(new_model.temperature, 20.0)
}

pub fn slider_does_not_change_history_test() {
  let #(model, _) = app.init()
  let event = event.WidgetSlide(id: "target", scope: [], value: 75.0)
  let #(new_model, _) = app.update(model, event)
  should.equal(new_model.history, [20.0])
}

pub fn slider_returns_animate_to_command_test() {
  let #(model, _) = app.init()
  let event = event.WidgetSlide(id: "target", scope: [], value: 75.0)
  let #(_, cmd) = app.update(model, event)
  case cmd {
    command.ExtensionCommand(node_id:, op:, payload:) -> {
      should.equal(node_id, "temp")
      should.equal(op, "animate_to")
      should.equal(dict.get(payload, "value"), Ok(FloatVal(75.0)))
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// update -- reset button
// ---------------------------------------------------------------------------

pub fn reset_sets_temperature_to_twenty_test() {
  let model = Model(temperature: 90.0, target_temp: 90.0, history: [20.0, 90.0])
  let event = event.WidgetClick(id: "reset", scope: [])
  let #(new_model, _) = app.update(model, event)
  should.equal(new_model.temperature, 20.0)
}

pub fn reset_sets_target_temp_to_twenty_test() {
  let model = Model(temperature: 90.0, target_temp: 90.0, history: [20.0, 90.0])
  let event = event.WidgetClick(id: "reset", scope: [])
  let #(new_model, _) = app.update(model, event)
  should.equal(new_model.target_temp, 20.0)
}

pub fn reset_appends_to_history_test() {
  let model = Model(temperature: 90.0, target_temp: 90.0, history: [20.0, 90.0])
  let event = event.WidgetClick(id: "reset", scope: [])
  let #(new_model, _) = app.update(model, event)
  should.equal(new_model.history, [20.0, 90.0, 20.0])
}

pub fn reset_returns_set_value_command_test() {
  let #(model, _) = app.init()
  let event = event.WidgetClick(id: "reset", scope: [])
  let #(_, cmd) = app.update(model, event)
  case cmd {
    command.ExtensionCommand(node_id:, op:, payload:) -> {
      should.equal(node_id, "temp")
      should.equal(op, "set_value")
      should.equal(dict.get(payload, "value"), Ok(FloatVal(20.0)))
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// update -- high button
// ---------------------------------------------------------------------------

pub fn high_sets_temperature_to_ninety_test() {
  let #(model, _) = app.init()
  let event = event.WidgetClick(id: "high", scope: [])
  let #(new_model, _) = app.update(model, event)
  should.equal(new_model.temperature, 90.0)
}

pub fn high_sets_target_temp_to_ninety_test() {
  let #(model, _) = app.init()
  let event = event.WidgetClick(id: "high", scope: [])
  let #(new_model, _) = app.update(model, event)
  should.equal(new_model.target_temp, 90.0)
}

pub fn high_appends_to_history_test() {
  let #(model, _) = app.init()
  let event = event.WidgetClick(id: "high", scope: [])
  let #(new_model, _) = app.update(model, event)
  should.equal(new_model.history, [20.0, 90.0])
}

pub fn high_returns_set_value_command_test() {
  let #(model, _) = app.init()
  let event = event.WidgetClick(id: "high", scope: [])
  let #(_, cmd) = app.update(model, event)
  case cmd {
    command.ExtensionCommand(node_id:, op:, payload:) -> {
      should.equal(node_id, "temp")
      should.equal(op, "set_value")
      should.equal(dict.get(payload, "value"), Ok(FloatVal(90.0)))
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// update -- unknown events
// ---------------------------------------------------------------------------

pub fn unknown_event_returns_model_unchanged_test() {
  let #(model, _) = app.init()
  let event = event.WidgetClick(id: "nonexistent", scope: [])
  let #(new_model, _) = app.update(model, event)
  should.equal(new_model, model)
}

pub fn unknown_event_returns_no_command_test() {
  let #(model, _) = app.init()
  let event = event.WidgetClick(id: "nonexistent", scope: [])
  let #(_, cmd) = app.update(model, event)
  should.equal(cmd, command.none())
}

// ---------------------------------------------------------------------------
// view structure
// ---------------------------------------------------------------------------

pub fn view_root_is_window_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  should.equal(tree.kind, "window")
  should.equal(tree.id, "main")
}

pub fn view_window_has_title_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  should.equal(
    dict.get(tree.props, "title"),
    Ok(StringVal("Temperature Gauge")),
  )
}

pub fn view_contains_gauge_node_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  let gauge_node = find_node(tree, "temp")
  should.be_true(option.is_some(gauge_node))
}

pub fn view_gauge_has_correct_kind_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  let assert option.Some(gauge_node) = find_node(tree, "temp")
  should.equal(gauge_node.kind, "gauge")
}

pub fn view_gauge_has_initial_value_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  let assert option.Some(gauge_node) = find_node(tree, "temp")
  should.equal(dict.get(gauge_node.props, "value"), Ok(FloatVal(20.0)))
}

pub fn view_gauge_color_changes_with_temperature_test() {
  // Cool (< 40) -> blue
  let cool_model = Model(temperature: 20.0, target_temp: 20.0, history: [20.0])
  let cool_tree = app.view(cool_model)
  let assert option.Some(cool_gauge) = find_node(cool_tree, "temp")
  should.equal(dict.get(cool_gauge.props, "color"), Ok(StringVal("#3498db")))

  // Critical (>= 80) -> red
  let hot_model = Model(temperature: 90.0, target_temp: 90.0, history: [90.0])
  let hot_tree = app.view(hot_model)
  let assert option.Some(hot_gauge) = find_node(hot_tree, "temp")
  should.equal(dict.get(hot_gauge.props, "color"), Ok(StringVal("#e74c3c")))
}

pub fn view_contains_slider_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  let slider_node = find_node(tree, "target")
  should.be_true(option.is_some(slider_node))
}

pub fn view_slider_value_matches_target_temp_test() {
  let model = Model(temperature: 20.0, target_temp: 65.0, history: [20.0])
  let tree = app.view(model)
  let assert option.Some(slider_node) = find_node(tree, "target")
  should.equal(dict.get(slider_node.props, "value"), Ok(FloatVal(65.0)))
}

pub fn view_contains_reset_button_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  should.be_true(option.is_some(find_node(tree, "reset")))
}

pub fn view_contains_high_button_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  should.be_true(option.is_some(find_node(tree, "high")))
}

pub fn view_contains_status_text_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  should.be_true(option.is_some(find_node(tree, "status")))
}

pub fn view_contains_history_text_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  should.be_true(option.is_some(find_node(tree, "history")))
}

// ---------------------------------------------------------------------------
// temperature_status helper
// ---------------------------------------------------------------------------

pub fn status_critical_at_eighty_test() {
  should.equal(app.temperature_status(80.0), "Critical")
}

pub fn status_critical_above_eighty_test() {
  should.equal(app.temperature_status(95.0), "Critical")
}

pub fn status_warning_at_sixty_test() {
  should.equal(app.temperature_status(60.0), "Warning")
}

pub fn status_warning_at_seventy_nine_test() {
  should.equal(app.temperature_status(79.9), "Warning")
}

pub fn status_normal_at_forty_test() {
  should.equal(app.temperature_status(40.0), "Normal")
}

pub fn status_cool_below_forty_test() {
  should.equal(app.temperature_status(39.9), "Cool")
}

pub fn status_cool_at_zero_test() {
  should.equal(app.temperature_status(0.0), "Cool")
}

// ---------------------------------------------------------------------------
// status_color helper
// ---------------------------------------------------------------------------

pub fn color_critical_is_red_test() {
  let assert Ok(expected) = color.from_hex("#e74c3c")
  should.equal(app.status_color(90.0), expected)
}

pub fn color_warning_is_orange_test() {
  let assert Ok(expected) = color.from_hex("#e67e22")
  should.equal(app.status_color(70.0), expected)
}

pub fn color_normal_is_green_test() {
  let assert Ok(expected) = color.from_hex("#27ae60")
  should.equal(app.status_color(50.0), expected)
}

pub fn color_cool_is_blue_test() {
  let assert Ok(expected) = color.from_hex("#3498db")
  should.equal(app.status_color(20.0), expected)
}

// ---------------------------------------------------------------------------
// append_history helper
// ---------------------------------------------------------------------------

pub fn append_history_adds_value_test() {
  let result = app.append_history([10.0, 20.0], 30.0)
  should.equal(result, [10.0, 20.0, 30.0])
}

pub fn append_history_caps_at_fifty_test() {
  let history = list.repeat(1.0, 50)
  let result = app.append_history(history, 99.0)
  should.equal(list.length(result), 50)
  // Oldest entry dropped, newest appended
  should.equal(list.last(result), Ok(99.0))
}

pub fn append_history_empty_list_test() {
  let result = app.append_history([], 42.0)
  should.equal(result, [42.0])
}

// ---------------------------------------------------------------------------
// Stateful journey
// ---------------------------------------------------------------------------

pub fn full_journey_test() {
  // Start fresh
  let #(model, _) = app.init()
  should.equal(model.temperature, 20.0)
  should.equal(model.history, [20.0])

  // Click high
  let #(model, _) = app.update(model, event.WidgetClick(id: "high", scope: []))
  should.equal(model.temperature, 90.0)
  should.equal(model.history, [20.0, 90.0])

  // Slide to 55
  let #(model, _) =
    app.update(model, event.WidgetSlide(id: "target", scope: [], value: 55.0))
  should.equal(model.target_temp, 55.0)
  // Temperature unchanged by slider
  should.equal(model.temperature, 90.0)
  // History unchanged by slider
  should.equal(model.history, [20.0, 90.0])

  // Click reset
  let #(model, _) = app.update(model, event.WidgetClick(id: "reset", scope: []))
  should.equal(model.temperature, 20.0)
  should.equal(model.target_temp, 20.0)
  should.equal(model.history, [20.0, 90.0, 20.0])
}

pub fn rapid_clicks_maintain_consistency_test() {
  let #(model, _) = app.init()

  // Rapid high -> reset -> high -> reset
  let #(model, _) = app.update(model, event.WidgetClick(id: "high", scope: []))
  let #(model, _) = app.update(model, event.WidgetClick(id: "reset", scope: []))
  let #(model, _) = app.update(model, event.WidgetClick(id: "high", scope: []))
  let #(model, _) = app.update(model, event.WidgetClick(id: "reset", scope: []))

  should.equal(model.temperature, 20.0)
  should.equal(model.target_temp, 20.0)
  should.equal(model.history, [20.0, 90.0, 20.0, 90.0, 20.0])
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
