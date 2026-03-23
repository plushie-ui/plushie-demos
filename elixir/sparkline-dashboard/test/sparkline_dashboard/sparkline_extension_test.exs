defmodule SparklineDashboard.SparklineExtensionTest do
  use ExUnit.Case, async: true

  alias SparklineDashboard.SparklineExtension, as: Sparkline

  # -- Extension metadata -----------------------------------------------------

  describe "extension metadata" do
    test "type_names returns the sparkline widget type" do
      assert Sparkline.type_names() == [:sparkline]
    end

    test "native_crate returns the Rust crate path" do
      assert Sparkline.native_crate() == "native/sparkline"
    end

    test "rust_constructor returns the constructor expression" do
      assert Sparkline.rust_constructor() == "sparkline::SparklineExtension::new()"
    end

    test "prop names include all declared props plus auto props" do
      names = Sparkline.__prop_names__()
      assert :data in names
      assert :color in names
      assert :stroke_width in names
      assert :fill in names
      assert :height in names
      assert :event_rate in names
      assert :a11y in names
    end

    test "no commands (render-only extension)" do
      # The extension module should not export command functions.
      # Render-only extensions declare no commands.
      refute function_exported?(Sparkline, :push, 2)
      refute function_exported?(Sparkline, :set_value, 2)
    end
  end

  # -- Widget struct ----------------------------------------------------------

  describe "widget struct" do
    test "new/2 creates a struct with defaults" do
      widget = Sparkline.new("s1")
      assert %Sparkline{} = widget
      assert widget.id == "s1"
      assert widget.data == []
      assert widget.stroke_width == 2.0
      assert widget.fill == false
      assert widget.height == 60.0
    end

    test "new/2 accepts custom props" do
      widget =
        Sparkline.new("s1",
          data: [10, 20, 30],
          color: "#FF0000",
          stroke_width: 3.0,
          fill: true,
          height: 80.0
        )

      assert widget.data == [10, 20, 30]
      assert widget.stroke_width == 3.0
      assert widget.fill == true
      assert widget.height == 80.0
    end

    test "new/2 rejects unknown keys" do
      assert_raise ArgumentError, ~r/unknown/, fn ->
        Sparkline.new("s1", bogus: true)
      end
    end

    test "empty data list is the default" do
      widget = Sparkline.new("s1")
      assert widget.data == []
    end
  end

  # -- Setter pipeline --------------------------------------------------------

  describe "setter pipeline" do
    test "data setter accepts a list" do
      widget = Sparkline.new("s1") |> Sparkline.data([1, 2, 3])
      assert widget.data == [1, 2, 3]
    end

    test "fill setter toggles boolean" do
      widget = Sparkline.new("s1") |> Sparkline.fill(true)
      assert widget.fill == true
    end

    test "color setter casts named atoms" do
      widget = Sparkline.new("s1") |> Sparkline.color(:red)
      assert widget.color == Plushie.Type.Color.cast(:red)
    end

    test "setters chain for pipeline composition" do
      widget =
        Sparkline.new("s1")
        |> Sparkline.data([1.0, 2.0])
        |> Sparkline.color("#0000FF")
        |> Sparkline.stroke_width(4.0)
        |> Sparkline.fill(true)
        |> Sparkline.height(120.0)

      assert widget.data == [1.0, 2.0]
      assert widget.color == "#0000ff"
      assert widget.stroke_width == 4.0
      assert widget.fill == true
      assert widget.height == 120.0
    end

    test "with_options/2 applies multiple options at once" do
      widget = Sparkline.new("s1") |> Sparkline.with_options(fill: true, height: 100.0)
      assert widget.fill == true
      assert widget.height == 100.0
    end
  end

  # -- Build output -----------------------------------------------------------

  describe "build/1" do
    test "converts struct to node map with correct type" do
      node = Sparkline.new("s1") |> Sparkline.build()
      assert node.id == "s1"
      assert node.type == "sparkline"
    end

    test "includes all props with defaults" do
      node = Sparkline.new("s1") |> Sparkline.build()
      assert node.props[:data] == []
      assert node.props[:color] == Plushie.Type.Color.cast("#4CAF50")
      assert node.props[:stroke_width] == 2.0
      assert node.props[:fill] == false
      assert node.props[:height] == 60.0
    end

    test "includes custom props in output" do
      node =
        Sparkline.new("s1", data: [10, 20, 30], color: "#FF0000", fill: true)
        |> Sparkline.build()

      assert node.props[:data] == [10, 20, 30]
      assert node.props[:color] == Plushie.Type.Color.cast("#FF0000")
      assert node.props[:fill] == true
    end

    test "sparkline is a leaf widget (no children)" do
      node = Sparkline.new("s1") |> Sparkline.build()
      assert node.children == []
    end
  end

  # -- A11y support -----------------------------------------------------------

  describe "a11y support" do
    test "a11y prop available without explicit declaration" do
      a11y = %{role: :image, label: "CPU usage chart"}

      node =
        Sparkline.new("s1", a11y: a11y)
        |> Sparkline.build()

      assert %Plushie.Type.A11y{} = node.props[:a11y]
      assert node.props[:a11y].role == :image
      assert node.props[:a11y].label == "CPU usage chart"
    end

    test "a11y omitted from props when not set" do
      node = Sparkline.new("s1") |> Sparkline.build()
      refute Map.has_key?(node.props, :a11y)
    end
  end
end
