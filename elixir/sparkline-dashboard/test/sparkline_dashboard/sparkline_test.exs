defmodule SparklineDashboard.SparklineTest do
  use ExUnit.Case, async: true

  alias SparklineDashboard.Sparkline

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

defmodule SparklineDashboard.SparklineWidgetTest do
  # Exercises the full pipeline (Elixir -> wire protocol -> headless renderer)
  # rather than just the struct/build layer. Render-only widget: data in, pixels out.
  use Plushie.Test.WidgetCase, widget: SparklineDashboard.Sparkline

  describe "with data" do
    setup do
      init_widget("s1", data: [10.0, 20.0, 30.0, 40.0, 50.0])
    end

    test "widget appears in the rendered tree" do
      assert_exists("#s1")
    end

    test "renderer receives the correct widget type" do
      element = find!("#s1")
      assert element.type == "sparkline"
    end

    test "data prop is passed through to the renderer" do
      element = find!("#s1")
      assert element.props[:data] == [10.0, 20.0, 30.0, 40.0, 50.0]
    end

    test "default stroke_width is passed through" do
      element = find!("#s1")
      assert element.props[:stroke_width] == 2.0
    end

    test "default fill is passed through" do
      element = find!("#s1")
      assert element.props[:fill] == false
    end

    test "default height is passed through" do
      element = find!("#s1")
      assert element.props[:height] == 60.0
    end
  end

  describe "with custom props" do
    setup do
      init_widget("s2",
        data: [1.0, 2.0, 3.0],
        stroke_width: 3.0,
        fill: true,
        height: 80.0
      )
    end

    test "custom stroke_width reaches the renderer" do
      element = find!("#s2")
      assert element.props[:stroke_width] == 3.0
    end

    test "fill: true reaches the renderer" do
      element = find!("#s2")
      assert element.props[:fill] == true
    end

    test "custom height reaches the renderer" do
      element = find!("#s2")
      assert element.props[:height] == 80.0
    end
  end

  describe "empty data" do
    setup do
      init_widget("s3", data: [])
    end

    test "widget renders with empty data" do
      assert_exists("#s3")
    end
  end
end
