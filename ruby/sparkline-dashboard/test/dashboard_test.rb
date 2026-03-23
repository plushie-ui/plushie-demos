# frozen_string_literal: true

require_relative "test_helper"

class DashboardTest < Minitest::Test
  def setup
    @app = Dashboard.new
  end

  # -- init --

  def test_init_returns_model_with_empty_samples
    model = @app.init({})
    assert_equal [], model.cpu_samples
    assert_equal [], model.mem_samples
    assert_equal [], model.net_samples
  end

  def test_init_starts_running
    model = @app.init({})
    assert_equal true, model.running
  end

  def test_init_tick_count_is_zero
    model = @app.init({})
    assert_equal 0, model.tick_count
  end

  # -- update: timer events --

  def test_timer_sample_adds_data_when_running
    model = @app.init({})
    event = Plushie::Event::Timer.new(tag: :sample, timestamp: 0)

    updated = @app.update(model, event)

    assert_equal 1, updated.cpu_samples.length
    assert_equal 1, updated.mem_samples.length
    assert_equal 1, updated.net_samples.length
    assert_equal 1, updated.tick_count
  end

  def test_timer_sample_ignores_when_paused
    model = @app.init({}).with(running: false)
    event = Plushie::Event::Timer.new(tag: :sample, timestamp: 0)

    updated = @app.update(model, event)

    assert_equal [], updated.cpu_samples
    assert_equal 0, updated.tick_count
  end

  def test_timer_sample_caps_at_max_samples
    model = @app.init({}).with(
      cpu_samples: Array.new(100, 50.0),
      mem_samples: Array.new(100, 50.0),
      net_samples: Array.new(100, 50.0)
    )
    event = Plushie::Event::Timer.new(tag: :sample, timestamp: 0)

    updated = @app.update(model, event)

    assert_equal 100, updated.cpu_samples.length
    assert_equal 100, updated.mem_samples.length
    assert_equal 100, updated.net_samples.length
  end

  def test_timer_increments_tick_count
    model = @app.init({})
    event = Plushie::Event::Timer.new(tag: :sample, timestamp: 0)

    m1 = @app.update(model, event)
    m2 = @app.update(m1, event)
    m3 = @app.update(m2, event)

    assert_equal 3, m3.tick_count
  end

  # -- update: UI events --

  def test_toggle_running_pauses
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :click, id: "toggle_running", scope: []
    )

    updated = @app.update(model, event)
    assert_equal false, updated.running
  end

  def test_toggle_running_resumes
    model = @app.init({}).with(running: false)
    event = Plushie::Event::Widget.new(
      type: :click, id: "toggle_running", scope: []
    )

    updated = @app.update(model, event)
    assert_equal true, updated.running
  end

  def test_clear_resets_samples
    model = @app.init({}).with(
      cpu_samples: [1, 2, 3],
      mem_samples: [4, 5, 6],
      net_samples: [7, 8, 9],
      tick_count: 42
    )
    event = Plushie::Event::Widget.new(
      type: :click, id: "clear", scope: []
    )

    updated = @app.update(model, event)
    assert_equal [], updated.cpu_samples
    assert_equal [], updated.mem_samples
    assert_equal [], updated.net_samples
    assert_equal 0, updated.tick_count
  end

  def test_unknown_event_returns_model_unchanged
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :click, id: "nonexistent", scope: []
    )

    updated = @app.update(model, event)
    assert_equal model, updated
  end

  # -- subscribe --

  def test_subscribe_active_when_running
    model = @app.init({})
    subs = @app.subscribe(model)

    assert_equal 1, subs.length
    assert_equal :sample, subs.first.tag
  end

  def test_subscribe_empty_when_paused
    model = @app.init({}).with(running: false)
    subs = @app.subscribe(model)

    assert_equal [], subs
  end

  # -- view --

  def test_view_returns_window_node
    model = @app.init({})
    tree = @app.view(model)

    assert_instance_of Plushie::Node, tree
    assert_equal "window", tree.type
    assert_equal "main", tree.id
  end

  def test_view_contains_sparkline_widgets
    model = @app.init({}).with(
      cpu_samples: [10, 20, 30],
      mem_samples: [40, 50, 60],
      net_samples: [70, 80, 90]
    )
    tree = @app.view(model)

    # Search for sparkline nodes in the tree
    sparklines = find_nodes(tree, "sparkline")
    assert_equal 3, sparklines.length

    ids = sparklines.map(&:id).sort
    assert_equal ["cpu_spark", "mem_spark", "net_spark"], ids
  end

  def test_view_sparkline_has_correct_props
    model = @app.init({}).with(cpu_samples: [1.0, 2.0, 3.0])
    tree = @app.view(model)

    cpu_spark = find_node(tree, "cpu_spark")
    assert_equal [1.0, 2.0, 3.0], cpu_spark.props[:data]
    assert_equal "#4CAF50", cpu_spark.props[:color]
    assert_equal true, cpu_spark.props[:fill]
  end

  def test_view_shows_pause_button_when_running
    model = @app.init({})
    tree = @app.view(model)

    btn = find_node(tree, "toggle_running")
    assert_equal "Pause", btn.props[:label]
  end

  def test_view_shows_resume_button_when_paused
    model = @app.init({}).with(running: false)
    tree = @app.view(model)

    btn = find_node(tree, "toggle_running")
    assert_equal "Resume", btn.props[:label]
  end

  def test_view_shows_sample_count
    model = @app.init({}).with(cpu_samples: Array.new(42, 0))
    tree = @app.view(model)

    status = find_node(tree, "status")
    assert_equal "42 samples", status.props[:content]
  end

  private

  # Recursive node search helpers
  def find_nodes(node, type)
    results = []
    results << node if node.type == type
    (node.children || []).each do |child|
      results.concat(find_nodes(child, type))
    end
    results
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
