defmodule CrashTest.CrashWidgetTest do
  use ExUnit.Case, async: true

  alias CrashTest.CrashWidget

  describe "widget metadata" do
    test "type_names" do
      assert CrashWidget.type_names() == [:crash_widget]
    end

    test "native_crate" do
      assert CrashWidget.native_crate() == "native/crash_widget"
    end

    test "rust_constructor" do
      assert CrashWidget.rust_constructor() == "crash_widget::CrashExtension::new()"
    end
  end

  describe "widget struct" do
    test "new with default label" do
      widget = CrashWidget.new("w1")
      assert %CrashWidget{} = widget
      assert widget.label == "Widget OK"
    end

    test "new with custom label" do
      widget = CrashWidget.new("w1", label: "Custom")
      assert widget.label == "Custom"
    end

    test "build produces correct node type" do
      node = CrashWidget.new("w1") |> CrashWidget.build()
      assert node.id == "w1"
      assert node.type == "crash_widget"
      assert node.props[:label] == "Widget OK"
    end
  end

  describe "panic command" do
    test "produces a widget command" do
      cmd = CrashWidget.panic("w1")
      assert cmd.type == :command
      assert cmd.payload.id == "w1"
      assert cmd.payload.family == "panic"
      assert cmd.payload.value == nil
    end

    test "enforces widget_id is binary" do
      assert_raise FunctionClauseError, fn ->
        CrashWidget.panic(:not_binary)
      end
    end
  end
end
