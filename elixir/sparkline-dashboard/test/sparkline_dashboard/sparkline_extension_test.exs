defmodule SparklineDashboard.SparklineExtensionTest do
  use ExUnit.Case, async: true

  alias SparklineDashboard.SparklineExtension, as: Sparkline

  test "type_names" do
    assert Sparkline.type_names() == [:sparkline]
  end

  test "native_crate" do
    assert Sparkline.native_crate() == "native/sparkline"
  end

  test "no commands (render-only)" do
    refute function_exported?(Sparkline, :push, 2)
  end

  test "new with defaults" do
    widget = Sparkline.new("s1")
    assert widget.data == []
    assert widget.stroke_width == 2.0
    assert widget.fill == false
    assert widget.height == 60.0
  end

  test "build produces correct node type" do
    node = Sparkline.new("s1") |> Sparkline.build()
    assert node.type == "sparkline"
  end
end
