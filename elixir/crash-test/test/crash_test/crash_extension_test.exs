defmodule CrashTest.CrashExtensionTest do
  use ExUnit.Case, async: true

  alias CrashTest.CrashExtension

  describe "extension metadata" do
    test "type_names" do
      assert CrashExtension.type_names() == [:crash_widget]
    end

    test "native_crate" do
      assert CrashExtension.native_crate() == "native/crash_widget"
    end

    test "rust_constructor" do
      assert CrashExtension.rust_constructor() == "crash_widget::CrashExtension::new()"
    end
  end

  describe "widget struct" do
    test "new with default label" do
      widget = CrashExtension.new("w1")
      assert %CrashExtension{} = widget
      assert widget.label == "Widget OK"
    end

    test "new with custom label" do
      widget = CrashExtension.new("w1", label: "Custom")
      assert widget.label == "Custom"
    end

    test "build produces correct node type" do
      node = CrashExtension.new("w1") |> CrashExtension.build()
      assert node.id == "w1"
      assert node.type == "crash_widget"
      assert node.props[:label] == "Widget OK"
    end
  end

  describe "panic command" do
    test "produces an extension_command" do
      cmd = CrashExtension.panic("w1")
      assert cmd.type == :extension_command
      assert cmd.payload.node_id == "w1"
      assert cmd.payload.op == "panic"
      assert cmd.payload.payload == %{}
    end

    test "enforces widget_id is binary" do
      assert_raise FunctionClauseError, fn ->
        CrashExtension.panic(:not_binary)
      end
    end
  end
end
