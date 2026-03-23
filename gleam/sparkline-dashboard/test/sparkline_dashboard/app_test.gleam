import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleeunit/should
import plushie/command
import plushie/event
import plushie/node.{type Node, BoolVal, FloatVal, ListVal, StringVal}
import plushie/subscription
import sparkline_dashboard/app.{Model}

// ---------------------------------------------------------------------------
// init
// ---------------------------------------------------------------------------

pub fn init_cpu_samples_empty_test() {
  let #(model, _) = app.init()
  should.equal(model.cpu_samples, [])
}

pub fn init_mem_samples_empty_test() {
  let #(model, _) = app.init()
  should.equal(model.mem_samples, [])
}

pub fn init_net_samples_empty_test() {
  let #(model, _) = app.init()
  should.equal(model.net_samples, [])
}

pub fn init_running_is_true_test() {
  let #(model, _) = app.init()
  should.be_true(model.running)
}

pub fn init_tick_count_is_zero_test() {
  let #(model, _) = app.init()
  should.equal(model.tick_count, 0)
}

pub fn init_returns_no_command_test() {
  let #(_, cmd) = app.init()
  should.equal(cmd, command.none())
}

// ---------------------------------------------------------------------------
// update -- timer
// ---------------------------------------------------------------------------

pub fn timer_adds_one_sample_per_tick_test() {
  let #(model, _) = app.init()
  let event = event.TimerTick(tag: "sample", timestamp: 0)
  let #(model, _) = app.update(model, event)
  should.equal(list.length(model.cpu_samples), 1)
  should.equal(list.length(model.mem_samples), 1)
  should.equal(list.length(model.net_samples), 1)
}

pub fn timer_increments_tick_count_test() {
  let #(model, _) = app.init()
  let event = event.TimerTick(tag: "sample", timestamp: 0)
  let #(model, _) = app.update(model, event)
  should.equal(model.tick_count, 1)
  let #(model, _) = app.update(model, event)
  should.equal(model.tick_count, 2)
  let #(model, _) = app.update(model, event)
  should.equal(model.tick_count, 3)
}

pub fn timer_ignored_when_paused_test() {
  let #(model, _) = app.init()
  let model = Model(..model, running: False)
  let event = event.TimerTick(tag: "sample", timestamp: 0)
  let #(model, _) = app.update(model, event)
  should.equal(list.length(model.cpu_samples), 0)
  should.equal(model.tick_count, 0)
}

pub fn timer_returns_no_command_test() {
  let #(model, _) = app.init()
  let event = event.TimerTick(tag: "sample", timestamp: 0)
  let #(_, cmd) = app.update(model, event)
  should.equal(cmd, command.none())
}

// ---------------------------------------------------------------------------
// update -- toggle running
// ---------------------------------------------------------------------------

pub fn toggle_pauses_when_running_test() {
  let #(model, _) = app.init()
  should.be_true(model.running)
  let event = event.WidgetClick(id: "toggle_running", scope: [])
  let #(model, _) = app.update(model, event)
  should.be_false(model.running)
}

pub fn toggle_resumes_when_paused_test() {
  let model =
    Model(
      cpu_samples: [],
      mem_samples: [],
      net_samples: [],
      running: False,
      tick_count: 0,
    )
  let event = event.WidgetClick(id: "toggle_running", scope: [])
  let #(model, _) = app.update(model, event)
  should.be_true(model.running)
}

pub fn toggle_preserves_samples_test() {
  let model =
    Model(
      cpu_samples: [50.0],
      mem_samples: [60.0],
      net_samples: [70.0],
      running: True,
      tick_count: 1,
    )
  let event = event.WidgetClick(id: "toggle_running", scope: [])
  let #(model, _) = app.update(model, event)
  should.equal(model.cpu_samples, [50.0])
  should.equal(model.tick_count, 1)
}

// ---------------------------------------------------------------------------
// update -- clear
// ---------------------------------------------------------------------------

pub fn clear_resets_all_samples_test() {
  let model =
    Model(
      cpu_samples: [1.0, 2.0],
      mem_samples: [3.0, 4.0],
      net_samples: [5.0, 6.0],
      running: True,
      tick_count: 5,
    )
  let event = event.WidgetClick(id: "clear", scope: [])
  let #(model, _) = app.update(model, event)
  should.equal(model.cpu_samples, [])
  should.equal(model.mem_samples, [])
  should.equal(model.net_samples, [])
  should.equal(model.tick_count, 0)
}

pub fn clear_preserves_running_state_test() {
  let model =
    Model(
      cpu_samples: [1.0],
      mem_samples: [],
      net_samples: [],
      running: False,
      tick_count: 1,
    )
  let event = event.WidgetClick(id: "clear", scope: [])
  let #(model, _) = app.update(model, event)
  should.be_false(model.running)
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
// subscribe
// ---------------------------------------------------------------------------

pub fn subscribe_returns_timer_when_running_test() {
  let #(model, _) = app.init()
  let subs = app.subscribe(model)
  should.equal(subs, [subscription.every(500, "sample")])
}

pub fn subscribe_returns_empty_when_paused_test() {
  let model =
    Model(
      cpu_samples: [],
      mem_samples: [],
      net_samples: [],
      running: False,
      tick_count: 0,
    )
  let subs = app.subscribe(model)
  should.equal(subs, [])
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
    Ok(StringVal("Sparkline Dashboard")),
  )
}

pub fn view_contains_three_sparkline_nodes_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  should.be_true(option.is_some(find_node(tree, "cpu_spark")))
  should.be_true(option.is_some(find_node(tree, "mem_spark")))
  should.be_true(option.is_some(find_node(tree, "net_spark")))
}

pub fn view_sparkline_nodes_have_correct_kind_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  let assert option.Some(cpu) = find_node(tree, "cpu_spark")
  should.equal(cpu.kind, "sparkline")
  let assert option.Some(mem) = find_node(tree, "mem_spark")
  should.equal(mem.kind, "sparkline")
  let assert option.Some(net) = find_node(tree, "net_spark")
  should.equal(net.kind, "sparkline")
}

pub fn view_sparkline_initial_data_is_empty_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  let assert option.Some(cpu) = find_node(tree, "cpu_spark")
  should.equal(dict.get(cpu.props, "data"), Ok(ListVal([])))
}

pub fn view_sparkline_colors_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  let assert option.Some(cpu) = find_node(tree, "cpu_spark")
  should.equal(dict.get(cpu.props, "color"), Ok(StringVal("#4caf50")))
  let assert option.Some(mem) = find_node(tree, "mem_spark")
  should.equal(dict.get(mem.props, "color"), Ok(StringVal("#2196f3")))
  let assert option.Some(net) = find_node(tree, "net_spark")
  should.equal(dict.get(net.props, "color"), Ok(StringVal("#ff9800")))
}

pub fn view_cpu_and_mem_have_fill_net_does_not_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  let assert option.Some(cpu) = find_node(tree, "cpu_spark")
  should.equal(dict.get(cpu.props, "fill"), Ok(BoolVal(True)))
  let assert option.Some(mem) = find_node(tree, "mem_spark")
  should.equal(dict.get(mem.props, "fill"), Ok(BoolVal(True)))
  let assert option.Some(net) = find_node(tree, "net_spark")
  should.equal(dict.get(net.props, "fill"), Ok(BoolVal(False)))
}

pub fn view_contains_toggle_button_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  should.be_true(option.is_some(find_node(tree, "toggle_running")))
}

pub fn view_contains_clear_button_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  should.be_true(option.is_some(find_node(tree, "clear")))
}

pub fn view_contains_status_text_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  should.be_true(option.is_some(find_node(tree, "status")))
}

pub fn view_toggle_label_changes_with_running_state_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  let assert option.Some(btn) = find_node(tree, "toggle_running")
  should.equal(dict.get(btn.props, "label"), Ok(StringVal("Pause")))

  let paused_model = Model(..model, running: False)
  let tree = app.view(paused_model)
  let assert option.Some(btn) = find_node(tree, "toggle_running")
  should.equal(dict.get(btn.props, "label"), Ok(StringVal("Resume")))
}

pub fn view_sparkline_data_reflects_model_test() {
  let model =
    Model(
      cpu_samples: [10.0, 20.0, 30.0],
      mem_samples: [40.0, 50.0],
      net_samples: [60.0],
      running: True,
      tick_count: 3,
    )
  let tree = app.view(model)
  let assert option.Some(cpu) = find_node(tree, "cpu_spark")
  should.equal(
    dict.get(cpu.props, "data"),
    Ok(ListVal([FloatVal(10.0), FloatVal(20.0), FloatVal(30.0)])),
  )
}

pub fn view_value_text_shows_last_sample_test() {
  let model =
    Model(
      cpu_samples: [10.0, 20.0, 75.0],
      mem_samples: [40.0],
      net_samples: [90.0],
      running: True,
      tick_count: 3,
    )
  let tree = app.view(model)
  // CPU last value is 75.0 -> "75%"
  let assert option.Some(cpu_value) = find_node(tree, "cpu_value")
  should.equal(dict.get(cpu_value.props, "content"), Ok(StringVal("75%")))
}

pub fn view_value_text_absent_when_data_empty_test() {
  let #(model, _) = app.init()
  let tree = app.view(model)
  // No data -> no value text nodes
  should.be_true(option.is_none(find_node(tree, "cpu_value")))
  should.be_true(option.is_none(find_node(tree, "mem_value")))
  should.be_true(option.is_none(find_node(tree, "net_value")))
}

// ---------------------------------------------------------------------------
// Metrics -- range validation
// ---------------------------------------------------------------------------

pub fn cpu_sample_in_expected_range_test() {
  // Run several samples, all should be 0-100
  int.range(from: 0, to: 49, with: Nil, run: fn(_, tick) {
    let v = app.cpu_sample(tick)
    should.be_true(v >=. 0.0)
    should.be_true(v <=. 100.0)
  })
}

pub fn mem_sample_in_expected_range_test() {
  int.range(from: 0, to: 49, with: Nil, run: fn(_, tick) {
    let v = app.mem_sample(tick)
    should.be_true(v >=. 20.0)
    should.be_true(v <=. 100.0)
  })
}

pub fn net_sample_in_expected_range_test() {
  int.range(from: 0, to: 49, with: Nil, run: fn(_, _) {
    let v = app.net_sample()
    should.be_true(v >=. 0.0)
    should.be_true(v <=. 100.0)
  })
}

// ---------------------------------------------------------------------------
// cap_samples
// ---------------------------------------------------------------------------

pub fn cap_samples_adds_value_test() {
  let result = app.cap_samples([1.0, 2.0], 3.0)
  should.equal(result, [1.0, 2.0, 3.0])
}

pub fn cap_samples_at_hundred_test() {
  let history = list.repeat(1.0, 100)
  let result = app.cap_samples(history, 99.0)
  should.equal(list.length(result), 100)
  should.equal(list.last(result), Ok(99.0))
}

pub fn cap_samples_empty_list_test() {
  let result = app.cap_samples([], 42.0)
  should.equal(result, [42.0])
}

// ---------------------------------------------------------------------------
// Full journey
// ---------------------------------------------------------------------------

pub fn full_journey_test() {
  // Start fresh
  let #(model, _) = app.init()
  should.be_true(model.running)
  should.equal(model.tick_count, 0)

  // Tick twice
  let tick = event.TimerTick(tag: "sample", timestamp: 0)
  let #(model, _) = app.update(model, tick)
  let #(model, _) = app.update(model, tick)
  should.equal(list.length(model.cpu_samples), 2)
  should.equal(model.tick_count, 2)

  // Pause
  let toggle = event.WidgetClick(id: "toggle_running", scope: [])
  let #(model, _) = app.update(model, toggle)
  should.be_false(model.running)

  // Timer ignored while paused
  let #(model, _) = app.update(model, tick)
  should.equal(list.length(model.cpu_samples), 2)
  should.equal(model.tick_count, 2)

  // Resume
  let #(model, _) = app.update(model, toggle)
  should.be_true(model.running)

  // Tick again
  let #(model, _) = app.update(model, tick)
  should.equal(list.length(model.cpu_samples), 3)
  should.equal(model.tick_count, 3)

  // Clear
  let clear = event.WidgetClick(id: "clear", scope: [])
  let #(model, _) = app.update(model, clear)
  should.equal(model.cpu_samples, [])
  should.equal(model.tick_count, 0)
  should.be_true(model.running)
}

pub fn sample_capping_at_hundred_test() {
  let #(model, _) = app.init()
  let tick = event.TimerTick(tag: "sample", timestamp: 0)

  // Fire 105 ticks
  let model =
    int.range(from: 1, to: 106, with: model, run: fn(m, _) {
      let #(m, _) = app.update(m, tick)
      m
    })

  should.equal(list.length(model.cpu_samples), 100)
  should.equal(list.length(model.mem_samples), 100)
  should.equal(list.length(model.net_samples), 100)
  should.equal(model.tick_count, 105)
}

pub fn rapid_toggle_maintains_consistency_test() {
  let #(model, _) = app.init()
  let toggle = event.WidgetClick(id: "toggle_running", scope: [])

  // Rapid toggle: running -> paused -> running -> paused
  let #(model, _) = app.update(model, toggle)
  should.be_false(model.running)
  let #(model, _) = app.update(model, toggle)
  should.be_true(model.running)
  let #(model, _) = app.update(model, toggle)
  should.be_false(model.running)
  let #(model, _) = app.update(model, toggle)
  should.be_true(model.running)
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
