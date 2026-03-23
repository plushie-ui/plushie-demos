# frozen_string_literal: true

require_relative "test_helper"

class TemperatureMonitorTest < Minitest::Test
  def setup
    @app = TemperatureMonitor.new
  end

  # -- init --

  def test_init_defaults
    model = @app.init({})
    assert_equal 20, model.temperature
    assert_equal 20, model.target_temp
    assert_equal [20], model.history
  end

  # -- update: slider --

  def test_slider_updates_target_temp
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :slide, id: "target", scope: [],
      data: {"value" => 75}
    )

    result = @app.update(model, event)
    updated, _command = result

    assert_equal 75, updated.target_temp
    assert_equal 20, updated.temperature  # temperature unchanged
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

  # -- update: reset button --

  def test_reset_sets_temperature_to_20
    model = @app.init({}).with(temperature: 90, target_temp: 90)
    event = Plushie::Event::Widget.new(
      type: :click, id: "reset", scope: [], data: nil
    )

    updated, _command = @app.update(model, event)

    assert_equal 20, updated.temperature
    assert_equal 20, updated.target_temp
  end

  def test_reset_appends_to_history
    model = @app.init({}).with(history: [20, 90])
    event = Plushie::Event::Widget.new(
      type: :click, id: "reset", scope: [], data: nil
    )

    updated, _command = @app.update(model, event)

    assert_equal [20, 90, 20], updated.history
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
    assert_equal({value: 20}, command.payload[:data])
  end

  # -- update: high button --

  def test_high_sets_temperature_to_90
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :click, id: "high", scope: [], data: nil
    )

    updated, _command = @app.update(model, event)

    assert_equal 90, updated.temperature
    assert_equal 90, updated.target_temp
  end

  def test_high_appends_to_history
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :click, id: "high", scope: [], data: nil
    )

    updated, _command = @app.update(model, event)

    assert_equal [20, 90], updated.history
  end

  def test_high_sends_set_value_command
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :click, id: "high", scope: [], data: nil
    )

    _updated, command = @app.update(model, event)

    assert_equal :extension_command, command.type
    assert_equal "set_value", command.payload[:op]
    assert_equal({value: 90}, command.payload[:data])
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

  # -- update: history cap --

  def test_history_caps_at_max
    model = @app.init({}).with(history: Array.new(50, 20))
    event = Plushie::Event::Widget.new(
      type: :click, id: "high", scope: [], data: nil
    )

    updated, _command = @app.update(model, event)

    assert_equal 50, updated.history.length
    assert_equal 90, updated.history.last
  end

  # -- update: rapid interactions --

  def test_rapid_high_reset_maintains_consistency
    model = @app.init({})
    high_event = Plushie::Event::Widget.new(
      type: :click, id: "high", scope: [], data: nil
    )
    reset_event = Plushie::Event::Widget.new(
      type: :click, id: "reset", scope: [], data: nil
    )

    m1, _ = @app.update(model, high_event)
    assert_equal 90, m1.temperature

    m2, _ = @app.update(m1, reset_event)
    assert_equal 20, m2.temperature

    m3, _ = @app.update(m2, high_event)
    assert_equal 90, m3.temperature
    assert_equal [20, 90, 20, 90], m3.history
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
    assert_equal 20, gauge.props[:value]
    assert_equal 0, gauge.props[:min]
    assert_equal 100, gauge.props[:max]
  end

  def test_view_gauge_color_reflects_temperature
    cool_model = @app.init({})
    cool_tree = @app.view(cool_model)
    cool_gauge = find_node(cool_tree, "temp")
    assert_equal "#3498db", cool_gauge.props[:color]

    hot_model = @app.init({}).with(temperature: 90)
    hot_tree = @app.view(hot_model)
    hot_gauge = find_node(hot_tree, "temp")
    assert_equal "#e74c3c", hot_gauge.props[:color]
  end

  def test_view_gauge_label_shows_degrees
    model = @app.init({}).with(temperature: 42)
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
    model = @app.init({}).with(history: [20, 90, 20])
    tree = @app.view(model)
    history = find_node(tree, "history")
    assert_includes history.props[:content], "20\u00B0"
    assert_includes history.props[:content], "90\u00B0"
  end

  def test_view_slider_value_matches_target
    model = @app.init({}).with(target_temp: 75)
    tree = @app.view(model)
    slider_node = find_node(tree, "target")
    assert_equal 75, slider_node.props[:value]
  end

  private

  def find_node(node, id)
    return node if node.id == id
    (node.children || []).each do |child|
      found = find_node(child, id)
      return found if found
    end
    nil
  end
end
