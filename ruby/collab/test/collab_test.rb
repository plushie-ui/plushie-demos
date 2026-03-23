# frozen_string_literal: true

require_relative "test_helper"

class CollabTest < Minitest::Test
  def setup
    @app = Collab.new
  end

  # -- init --

  def test_init_returns_empty_model
    model = @app.init({})
    assert_equal "", model.name
    assert_equal "", model.notes
    assert_equal 0, model.count
    assert_equal false, model.dark_mode
    assert_equal "", model.status
  end

  # -- update: counter --

  def test_increment
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :click, id: "inc", scope: [], data: nil
    )
    updated = @app.update(model, event)
    assert_equal 1, updated.count
  end

  def test_decrement
    model = @app.init({}).with(count: 5)
    event = Plushie::Event::Widget.new(
      type: :click, id: "dec", scope: [], data: nil
    )
    updated = @app.update(model, event)
    assert_equal 4, updated.count
  end

  # -- update: text inputs --

  def test_name_input
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :input, id: "name", scope: [],
      data: {"value" => "Alice"}
    )
    updated = @app.update(model, event)
    assert_equal "Alice", updated.name
  end

  def test_notes_input
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :input, id: "notes", scope: [],
      data: {"value" => "Hello world"}
    )
    updated = @app.update(model, event)
    assert_equal "Hello world", updated.notes
  end

  # -- update: dark mode --

  def test_toggle_dark_mode_on
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :toggle, id: "theme", scope: [],
      data: {"value" => true}
    )
    updated = @app.update(model, event)
    assert_equal true, updated.dark_mode
  end

  def test_toggle_dark_mode_off
    model = @app.init({}).with(dark_mode: true)
    event = Plushie::Event::Widget.new(
      type: :toggle, id: "theme", scope: [],
      data: {"value" => false}
    )
    updated = @app.update(model, event)
    assert_equal false, updated.dark_mode
  end

  # -- update: unknown events --

  def test_unknown_event_returns_model_unchanged
    model = @app.init({})
    event = Plushie::Event::Widget.new(
      type: :click, id: "nonexistent", scope: [], data: nil
    )
    updated = @app.update(model, event)
    assert_equal model, updated
  end

  # -- update preserves unrelated fields --

  def test_increment_preserves_name
    model = @app.init({}).with(name: "Bob")
    event = Plushie::Event::Widget.new(
      type: :click, id: "inc", scope: [], data: nil
    )
    updated = @app.update(model, event)
    assert_equal "Bob", updated.name
    assert_equal 1, updated.count
  end

  # -- view --

  def test_view_returns_window
    model = @app.init({})
    tree = @app.view(model)
    assert_equal "window", tree.type
    assert_equal "main", tree.id
  end

  def test_view_contains_counter
    model = @app.init({}).with(count: 42)
    tree = @app.view(model)
    count_node = find_node(tree, "count")
    assert_includes count_node.props[:content], "42"
  end

  def test_view_contains_name_input
    model = @app.init({}).with(name: "Alice")
    tree = @app.view(model)
    name_node = find_node(tree, "name")
    assert_equal "Alice", name_node.props[:value]
  end

  def test_view_contains_dark_mode_checkbox
    model = @app.init({}).with(dark_mode: true)
    tree = @app.view(model)
    theme_node = find_node(tree, "theme")
    assert_equal true, theme_node.props[:checked]
  end

  def test_view_shows_status_when_set
    model = @app.init({}).with(status: "3 connected")
    tree = @app.view(model)
    status_node = find_node(tree, "status")
    assert_equal "3 connected", status_node.props[:content]
  end

  def test_view_hides_status_when_empty
    model = @app.init({})
    tree = @app.view(model)
    status_node = find_node(tree, "status")
    assert_nil status_node
  end

  # -- view: tree structure --

  def test_view_contains_all_expected_widgets
    model = @app.init({}).with(status: "1 connected")
    tree = @app.view(model)

    %w[header status name counter_row dec count inc theme notes].each do |id|
      assert find_node(tree, id), "expected widget ##{id} in tree"
    end
  end

  def test_view_counter_row_has_buttons_and_count
    model = @app.init({}).with(count: 7)
    tree = @app.view(model)

    row = find_node(tree, "counter_row")
    child_ids = row.children.map(&:id)
    assert_equal %w[dec count inc], child_ids
  end

  def test_view_notes_input_shows_value
    model = @app.init({}).with(notes: "Remember the milk")
    tree = @app.view(model)
    notes_node = find_node(tree, "notes")
    assert_equal "Remember the milk", notes_node.props[:value]
  end

  def test_view_themer_uses_dark_theme
    model = @app.init({}).with(dark_mode: true)
    tree = @app.view(model)
    themer_node = find_node(tree, "theme_root")
    assert_equal "dark", themer_node.props[:theme]
  end

  def test_view_themer_uses_light_theme
    model = @app.init({})
    tree = @app.view(model)
    themer_node = find_node(tree, "theme_root")
    assert_equal "light", themer_node.props[:theme]
  end

  def test_view_header_text
    model = @app.init({})
    tree = @app.view(model)
    header = find_node(tree, "header")
    assert_equal "Plushie Demo", header.props[:content]
  end

  # -- update: field isolation --

  def test_name_input_preserves_count
    model = @app.init({}).with(count: 10)
    event = Plushie::Event::Widget.new(
      type: :input, id: "name", scope: [],
      data: {"value" => "Bob"}
    )
    updated = @app.update(model, event)
    assert_equal "Bob", updated.name
    assert_equal 10, updated.count
  end

  def test_toggle_preserves_notes
    model = @app.init({}).with(notes: "Keep this")
    event = Plushie::Event::Widget.new(
      type: :toggle, id: "theme", scope: [],
      data: {"value" => true}
    )
    updated = @app.update(model, event)
    assert_equal true, updated.dark_mode
    assert_equal "Keep this", updated.notes
  end

  # -- settings --

  def test_settings_event_rate
    assert_equal({default_event_rate: 30}, @app.settings)
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
