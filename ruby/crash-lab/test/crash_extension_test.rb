# frozen_string_literal: true

require_relative "test_helper"

class CrashExtensionTest < Minitest::Test
  def test_type_names
    assert_equal [:crash_widget], CrashExtension.type_names
  end

  def test_is_native
    assert CrashExtension.native?
  end

  def test_rust_crate_path
    assert_equal "native/crash_widget", CrashExtension.native_crate
  end

  def test_rust_constructor
    assert_equal "crash_widget::CrashExtension::new()",
      CrashExtension.rust_constructor_expr
  end

  def test_prop_names
    names = CrashExtension.prop_names
    assert_includes names, :label
    assert_includes names, :a11y
    assert_includes names, :event_rate
  end

  def test_command_declared
    commands = CrashExtension.instance_variable_get(:@_widget_commands)
    names = commands.map { |c| c[:name] }
    assert_includes names, :panic
  end

  def test_new_with_defaults
    widget = CrashExtension.new("w1")
    assert_equal "w1", widget.id
    assert_equal "", widget.label
  end

  def test_new_with_label
    widget = CrashExtension.new("w1", label: "healthy")
    assert_equal "healthy", widget.label
  end

  def test_build_produces_node
    widget = CrashExtension.new("w1", label: "test")
    node = widget.build
    assert_instance_of Plushie::Node, node
    assert_equal "w1", node.id
    assert_equal "crash_widget", node.type
    assert_equal "test", node.props[:label]
  end
end
