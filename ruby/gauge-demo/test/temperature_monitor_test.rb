# frozen_string_literal: true

require_relative "test_helper"

class TemperatureMonitorTest < Minitest::Test
  def setup
    @app = TemperatureMonitor.new
  end

  # -- init --

  def test_init_defaults
    model = @app.init({})
    assert_equal 20.0, model.temperature
    assert_equal 20.0, model.target_temp
    assert_equal [20.0], model.history
  end

  # -- update: extension value_changed event --

  def test_value_changed_updates_temperature
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :value_changed, id: "temp", scope: [],
      data: {"value" => 90.0}
    )

    updated = @app.update(model, event)

    assert_equal 90.0, updated.temperature
  end

  def test_value_changed_appends_to_history
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :value_changed, id: "temp", scope: [],
      data: {"value" => 42.0}
    )

    updated = @app.update(model, event)

    assert_equal [20.0, 42.0], updated.history
  end

  def test_value_changed_does_not_change_target
    model = @app.init({}).with(target_temp: 75.0)
    event = Plushie::Event::Widget.new(
      type: :value_changed, id: "temp", scope: [],
      data: {"value" => 75.0}
    )

    updated = @app.update(model, event)

    assert_equal 75.0, updated.target_temp
    assert_equal 75.0, updated.temperature
  end

  def test_value_changed_caps_history
    model = @app.init({}).with(history: Array.new(50, 20.0))
    event = Plushie::Event::Widget.new(
      type: :value_changed, id: "temp", scope: [],
      data: {"value" => 99.0}
    )

    updated = @app.update(model, event)

    assert_equal 50, updated.history.length
    assert_equal 99.0, updated.history.last
  end

  # -- update: slider --

  def test_slider_updates_target_temp
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :slide, id: "target", scope: [],
      data: {"value" => 75}
    )

    updated, _command = @app.update(model, event)

    assert_equal 75, updated.target_temp
    assert_equal 20.0, updated.temperature # temperature unchanged until confirmed
  end

  def test_slider_sends_animate_to_command
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :slide, id: "target", scope: [],
      data: {"value" => 75}
    )

    _updated, command = @app.update(model, event)

    assert_equal :extension_command, command.type
    assert_equal "temp", command.payload[:node_id]
    assert_equal "animate_to", command.payload[:op]
    assert_equal({value: 75}, command.payload[:data])
  end

  def test_slider_does_not_update_temperature
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :slide, id: "target", scope: [],
      data: {"value" => 75}
    )

    updated, _command = @app.update(model, event)

    assert_equal 20.0, updated.temperature
    assert_equal [20.0], updated.history
  end

  # -- update: reset button --

  def test_reset_updates_target_only
    model = @app.init({}).with(temperature: 90.0, target_temp: 90.0)
    event = Plushie::Event::Widget.new(
      type: :click, id: "reset", scope: [], data: nil
    )

    updated, _command = @app.update(model, event)

    assert_equal 20.0, updated.target_temp
    assert_equal 90.0, updated.temperature # unchanged until value_changed
  end

  def test_reset_does_not_append_to_history
    model = @app.init({}).with(history: [20.0, 90.0])
    event = Plushie::Event::Widget.new(
      type: :click, id: "reset", scope: [], data: nil
    )

    updated, _command = @app.update(model, event)

    assert_equal [20.0, 90.0], updated.history # unchanged until value_changed
  end

  def test_reset_sends_set_value_command
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :click, id: "reset", scope: [], data: nil
    )

    _updated, command = @app.update(model, event)

    assert_equal :extension_command, command.type
    assert_equal "temp", command.payload[:node_id]
    assert_equal "set_value", command.payload[:op]
    assert_equal({value: 20.0}, command.payload[:data])
  end

  # -- update: high button --

  def test_high_updates_target_only
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :click, id: "high", scope: [], data: nil
    )

    updated, _command = @app.update(model, event)

    assert_equal 90.0, updated.target_temp
    assert_equal 20.0, updated.temperature # unchanged until value_changed
  end

  def test_high_does_not_append_to_history
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :click, id: "high", scope: [], data: nil
    )

    updated, _command = @app.update(model, event)

    assert_equal [20.0], updated.history # unchanged until value_changed
  end

  def test_high_sends_set_value_command
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :click, id: "high", scope: [], data: nil
    )

    _updated, command = @app.update(model, event)

    assert_equal :extension_command, command.type
    assert_equal "set_value", command.payload[:op]
    assert_equal({value: 90.0}, command.payload[:data])
  end

  # -- update: unknown event --

  def test_unknown_event_returns_model_unchanged
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :click, id: "nonexistent", scope: [], data: nil
    )
    updated = @app.update(model, event)
    assert_equal model, updated
  end

  # -- update: full round-trip --

  def test_high_then_value_changed_updates_temperature
    model = @app.init({})

    # Button click: sets target, sends command
    high_event = Plushie::Event::Widget.new(
      type: :click, id: "high", scope: [], data: nil
    )
    m1, _cmd = @app.update(model, high_event)
    assert_equal 90.0, m1.target_temp
    assert_equal 20.0, m1.temperature # not yet confirmed

    # Extension event: Rust confirms the value
    confirm_event = Plushie::Event::Widget.new(
      type: :value_changed, id: "temp", scope: [],
      data: {"value" => 90.0}
    )
    m2 = @app.update(m1, confirm_event)
    assert_equal 90.0, m2.temperature
    assert_equal [20.0, 90.0], m2.history
  end

  def test_reset_then_value_changed_updates_temperature
    model = @app.init({}).with(temperature: 90.0, target_temp: 90.0, history: [20.0, 90.0])

    reset_event = Plushie::Event::Widget.new(
      type: :click, id: "reset", scope: [], data: nil
    )
    m1, _cmd = @app.update(model, reset_event)
    assert_equal 20.0, m1.target_temp
    assert_equal 90.0, m1.temperature # not yet confirmed

    confirm_event = Plushie::Event::Widget.new(
      type: :value_changed, id: "temp", scope: [],
      data: {"value" => 20.0}
    )
    m2 = @app.update(m1, confirm_event)
    assert_equal 20.0, m2.temperature
    assert_equal [20.0, 90.0, 20.0], m2.history
  end

  # -- update: rapid interactions --

  def test_rapid_clicks_only_update_target
    model = @app.init({})
    high_event = Plushie::Event::Widget.new(
      type: :click, id: "high", scope: [], data: nil
    )
    reset_event = Plushie::Event::Widget.new(
      type: :click, id: "reset", scope: [], data: nil
    )

    m1, _ = @app.update(model, high_event)
    m2, _ = @app.update(m1, reset_event)
    m3, _ = @app.update(m2, high_event)

    # Temperature unchanged -- no value_changed events processed
    assert_equal 20.0, m3.temperature
    assert_equal 90.0, m3.target_temp
    assert_equal [20.0], m3.history
  end

  def test_rapid_clicks_with_confirmations
    model = @app.init({})

    # High click + confirm
    m1, _ = @app.update(model, click("high"))
    m2 = @app.update(m1, value_changed(90.0))
    assert_equal 90.0, m2.temperature
    assert_equal [20.0, 90.0], m2.history

    # Reset click + confirm
    m3, _ = @app.update(m2, click("reset"))
    m4 = @app.update(m3, value_changed(20.0))
    assert_equal 20.0, m4.temperature
    assert_equal [20.0, 90.0, 20.0], m4.history

    # High click + confirm again
    m5, _ = @app.update(m4, click("high"))
    m6 = @app.update(m5, value_changed(90.0))
    assert_equal 90.0, m6.temperature
    assert_equal [20.0, 90.0, 20.0, 90.0], m6.history
  end

  # -- view --

  def test_view_returns_window
    model = @app.init({})
    tree = @app.view(model)
    assert_equal "window", tree.type
    assert_equal "main", tree.id
  end

  def test_view_contains_gauge_widget
    model = @app.init({})
    tree = @app.view(model)

    gauge = find_node(tree, "temp")
    assert_equal "gauge", gauge.type
    assert_equal 20.0, gauge.props[:value]
    assert_equal 0, gauge.props[:min]
    assert_equal 100, gauge.props[:max]
  end

  def test_view_gauge_color_reflects_temperature
    cool_model = @app.init({})
    cool_tree = @app.view(cool_model)
    cool_gauge = find_node(cool_tree, "temp")
    assert_equal "#3498db", cool_gauge.props[:color]

    hot_model = @app.init({}).with(temperature: 90.0)
    hot_tree = @app.view(hot_model)
    hot_gauge = find_node(hot_tree, "temp")
    assert_equal "#e74c3c", hot_gauge.props[:color]
  end

  def test_view_gauge_label_shows_degrees
    model = @app.init({}).with(temperature: 42.0)
    tree = @app.view(model)
    gauge = find_node(tree, "temp")
    assert_equal "42\u00B0C", gauge.props[:label]
  end

  def test_view_status_text
    model = @app.init({})
    tree = @app.view(model)
    status = find_node(tree, "status")
    assert_equal "Status: Cool", status.props[:content]
    assert_equal "#3498db", status.props[:color]
  end

  def test_view_reading_text
    model = @app.init({})
    tree = @app.view(model)
    reading = find_node(tree, "reading")
    assert_includes reading.props[:content], "Current: 20"
    assert_includes reading.props[:content], "Target: 20"
  end

  def test_view_history_text
    model = @app.init({}).with(history: [20.0, 90.0, 20.0])
    tree = @app.view(model)
    history = find_node(tree, "history")
    assert_includes history.props[:content], "20\u00B0"
    assert_includes history.props[:content], "90\u00B0"
  end

  def test_view_slider_value_matches_target
    model = @app.init({}).with(target_temp: 75.0)
    tree = @app.view(model)
    slider_node = find_node(tree, "target")
    assert_equal 75.0, slider_node.props[:value]
  end

  private

  def click(id)
    Plushie::Event::Widget.new(type: :click, id: id, scope: [], data: nil)
  end

  def value_changed(value)
    Plushie::Event::Widget.new(
      type: :value_changed, id: "temp", scope: [],
      data: {"value" => value}
    )
  end

  def find_node(node, id)
    return node if node.id == id
    (node.children || []).each do |child|
      found = find_node(child, id)
      return found if found
    end
    nil
  end
end
