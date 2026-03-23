# frozen_string_literal: true

require_relative "test_helper"

class CrashLabTest < Minitest::Test
  def setup
    @app = CrashLab.new
  end

  # -- init --

  def test_init_defaults
    model = @app.init({})
    assert_equal 0, model.count
    assert_equal true, model.extension_alive
    assert_equal false, model.view_broken
  end

  # -- counter --

  def test_count_increments
    model = @app.init({})
    m1 = @app.update(model, click("count"))
    assert_equal 1, m1.count
    m2 = @app.update(m1, click("count"))
    assert_equal 2, m2.count
  end

  # -- extension panic --

  def test_panic_ext_sends_extension_command
    model = @app.init({})
    _updated, command = @app.update(model, click("panic_ext"))

    assert_equal :extension_command, command.type
    assert_equal "crasher", command.payload[:node_id]
    assert_equal "panic", command.payload[:op]
  end

  def test_panic_ext_does_not_change_model
    model = @app.init({}).with(count: 5)
    updated, _command = @app.update(model, click("panic_ext"))

    assert_equal 5, updated.count
    assert_equal true, updated.extension_alive
  end

  # -- toggle extension --

  def test_toggle_ext_removes_extension
    model = @app.init({})
    updated = @app.update(model, click("toggle_ext"))
    assert_equal false, updated.extension_alive
  end

  def test_toggle_ext_restores_extension
    model = @app.init({}).with(extension_alive: false)
    updated = @app.update(model, click("toggle_ext"))
    assert_equal true, updated.extension_alive
  end

  # -- raise in update --

  def test_raise_update_raises_runtime_error
    model = @app.init({})
    assert_raises(RuntimeError) { @app.update(model, click("raise_update")) }
  end

  def test_raise_update_error_message
    model = @app.init({})
    err = assert_raises(RuntimeError) { @app.update(model, click("raise_update")) }
    assert_equal "intentional error in update handler", err.message
  end

  def test_counter_works_after_update_error_would_be_caught
    # Simulates the runtime behavior: the error is caught externally,
    # model is preserved, and subsequent events work normally.
    model = @app.init({}).with(count: 3)
    # The runtime would catch this and preserve model:
    assert_raises(RuntimeError) { @app.update(model, click("raise_update")) }
    # Next event works on the preserved model:
    updated = @app.update(model, click("count"))
    assert_equal 4, updated.count
  end

  # -- raise in view --

  def test_raise_view_sets_flag
    model = @app.init({})
    updated = @app.update(model, click("raise_view"))
    assert_equal true, updated.view_broken
  end

  def test_view_raises_when_broken
    model = @app.init({}).with(view_broken: true)
    err = assert_raises(RuntimeError) { @app.view(model) }
    assert_equal "intentional error in view", err.message
  end

  def test_view_succeeds_when_not_broken
    model = @app.init({})
    tree = @app.view(model)
    assert_instance_of Plushie::Node, tree
  end

  # -- recover --

  def test_recover_clears_view_broken
    model = @app.init({}).with(view_broken: true)
    updated = @app.update(model, click("recover"))
    assert_equal false, updated.view_broken
  end

  def test_view_works_after_recover
    model = @app.init({}).with(view_broken: true)
    recovered = @app.update(model, click("recover"))
    tree = @app.view(recovered)
    assert_instance_of Plushie::Node, tree
    assert_equal "window", tree.type
  end

  # -- full recovery sequence --

  def test_view_error_and_recovery_sequence
    model = @app.init({}).with(count: 5)

    # Break the view
    m1 = @app.update(model, click("raise_view"))
    assert_equal true, m1.view_broken
    assert_raises(RuntimeError) { @app.view(m1) }

    # Counter still works (update is fine)
    m2 = @app.update(m1, click("count"))
    assert_equal 6, m2.count
    assert_equal true, m2.view_broken # still broken
    assert_raises(RuntimeError) { @app.view(m2) }

    # Recover
    m3 = @app.update(m2, click("recover"))
    assert_equal false, m3.view_broken
    assert_equal 6, m3.count # count preserved through the whole sequence
    tree = @app.view(m3)
    assert_equal "window", tree.type
  end

  # -- unknown event --

  def test_unknown_event_returns_model_unchanged
    model = @app.init({})
    updated = @app.update(model, click("nonexistent"))
    assert_equal model, updated
  end

  # -- view structure --

  def test_view_contains_counter
    model = @app.init({}).with(count: 42)
    tree = @app.view(model)
    clicks_node = find_node(tree, "clicks")
    assert_includes clicks_node.props[:content], "42"
  end

  def test_view_contains_crash_widget_when_alive
    model = @app.init({})
    tree = @app.view(model)
    crasher = find_node(tree, "crasher")
    assert_equal "crash_widget", crasher.type
  end

  def test_view_hides_crash_widget_when_removed
    model = @app.init({}).with(extension_alive: false)
    tree = @app.view(model)
    crasher = find_node(tree, "crasher")
    assert_nil crasher
  end

  def test_view_shows_restore_button_when_removed
    model = @app.init({}).with(extension_alive: false)
    tree = @app.view(model)
    toggle = find_node(tree, "toggle_ext")
    assert_equal "Restore Extension", toggle.props[:label]
  end

  def test_view_shows_remove_button_when_alive
    model = @app.init({}).with(extension_alive: true)
    tree = @app.view(model)
    toggle = find_node(tree, "toggle_ext")
    assert_equal "Remove from Tree", toggle.props[:label]
  end

  def test_view_contains_recover_button
    model = @app.init({})
    tree = @app.view(model)
    recover = find_node(tree, "recover")
    assert_equal "Recover View", recover.props[:label]
  end

  def test_view_contains_footer
    model = @app.init({})
    tree = @app.view(model)
    footer = find_node(tree, "footer")
    assert_includes footer.props[:content], "rendered successfully"
  end

  # -- extension toggle recovery cycle --

  def test_remove_and_restore_extension
    model = @app.init({})

    # Extension is present
    tree1 = @app.view(model)
    assert find_node(tree1, "crasher")

    # Remove it
    m1 = @app.update(model, click("toggle_ext"))
    tree2 = @app.view(m1)
    refute find_node(tree2, "crasher")

    # Restore it
    m2 = @app.update(m1, click("toggle_ext"))
    tree3 = @app.view(m2)
    assert find_node(tree3, "crasher")
  end

  private

  def click(id)
    Plushie::Event::Widget.new(type: :click, id: id, scope: [], data: nil)
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
