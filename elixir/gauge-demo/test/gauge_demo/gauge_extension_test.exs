defmodule GaugeDemo.GaugeExtensionTest do
  use ExUnit.Case, async: true

  alias GaugeDemo.GaugeExtension, as: Gauge

  # -- Extension metadata -----------------------------------------------------

  describe "extension metadata" do
    test "type_names returns the gauge widget type" do
      assert Gauge.type_names() == [:gauge]
    end

    test "native_crate returns the Rust crate path" do
      assert Gauge.native_crate() == "native/gauge"
    end

    test "declares value_changed as a native widget event" do
      assert Gauge.__events__() == [:value_changed]
    end

    test "rust_constructor returns the constructor expression" do
      assert Gauge.rust_constructor() == "gauge::GaugeExtension::new()"
    end

    test "prop names include all declared props plus auto props" do
      names = Gauge.__prop_names__()
      assert :value in names
      assert :min in names
      assert :max in names
      assert :color in names
      assert :label in names
      assert :width in names
      assert :height in names
      assert :event_rate in names
      assert :a11y in names
    end
  end

  # -- Widget struct ----------------------------------------------------------

  describe "widget struct" do
    test "new/2 creates a struct with defaults" do
      widget = Gauge.new("g1")
      assert %Gauge{} = widget
      assert widget.id == "g1"
      assert widget.min == 0
      assert widget.max == 100
    end

    test "new/2 accepts custom props" do
      widget = Gauge.new("g1", value: 72, min: 10, max: 200, label: "Hot")
      assert widget.value == 72
      assert widget.min == 10
      assert widget.max == 200
      assert widget.label == "Hot"
    end

    test "new/2 rejects unknown keys" do
      assert_raise ArgumentError, ~r/unknown/, fn ->
        Gauge.new("g1", bogus: true)
      end
    end

    test "props without defaults are nil when not provided" do
      widget = Gauge.new("g1")
      assert widget.value == nil
      assert widget.width == nil
      assert widget.height == nil
    end
  end

  # -- Setter pipeline --------------------------------------------------------

  describe "setter pipeline" do
    test "setters return updated structs" do
      widget = Gauge.new("g1") |> Gauge.value(42)
      assert %Gauge{} = widget
      assert widget.value == 42
    end

    test "setters chain for pipeline composition" do
      widget =
        Gauge.new("g1")
        |> Gauge.value(50)
        |> Gauge.min(10)
        |> Gauge.max(200)
        |> Gauge.label("50%")
        |> Gauge.width(300)
        |> Gauge.height(300)

      assert widget.value == 50
      assert widget.min == 10
      assert widget.max == 200
      assert widget.label == "50%"
      assert widget.width == 300
      assert widget.height == 300
    end

    test "color setter casts named atoms" do
      widget = Gauge.new("g1") |> Gauge.color(:red)
      assert widget.color == Plushie.Type.Color.cast(:red)
    end

    test "color setter normalizes hex strings" do
      widget = Gauge.new("g1") |> Gauge.color("#FF0000")
      assert widget.color == "#ff0000"
    end

    test "with_options/2 applies multiple options at once" do
      widget = Gauge.new("g1") |> Gauge.with_options(value: 75, label: "75%")
      assert widget.value == 75
      assert widget.label == "75%"
    end
  end

  # -- Build output -----------------------------------------------------------

  describe "build/1" do
    test "converts struct to node map with correct type" do
      node = Gauge.new("g1", value: 42) |> Gauge.build()
      assert node.id == "g1"
      assert node.type == "gauge"
    end

    test "includes all set props" do
      node =
        Gauge.new("g1", value: 72, min: 0, max: 100, label: "72%", width: 200, height: 200)
        |> Gauge.build()

      assert node.props[:value] == 72
      assert node.props[:min] == 0
      assert node.props[:max] == 100
      assert node.props[:label] == "72%"
      assert node.props[:width] == 200
      assert node.props[:height] == 200
    end

    test "applies defaults in output" do
      node = Gauge.new("g1", value: 0) |> Gauge.build()
      assert node.props[:min] == 0
      assert node.props[:max] == 100
      assert node.props[:color] == Plushie.Type.Color.cast("#3498db")
    end

    test "omits nil props (no default, not set)" do
      node = Gauge.new("g1") |> Gauge.build()
      refute Map.has_key?(node.props, :width)
      refute Map.has_key?(node.props, :height)
    end

    test "gauge is a leaf widget (no children)" do
      node = Gauge.new("g1") |> Gauge.build()
      assert node.children == []
    end

    test "color default is cast in output" do
      node = Gauge.new("g1") |> Gauge.build()
      assert node.props[:color] == Plushie.Type.Color.cast("#3498db")
    end
  end

  # -- Command generation -----------------------------------------------------

  describe "command generation" do
    test "set_value produces an extension_command" do
      cmd = Gauge.set_value("temp", 42)
      assert cmd.type == :extension_command
      assert cmd.payload.node_id == "temp"
      assert cmd.payload.op == "set_value"
      assert cmd.payload.payload == %{value: 42}
    end

    test "animate_to produces an extension_command" do
      cmd = Gauge.animate_to("temp", 90.0)
      assert cmd.type == :extension_command
      assert cmd.payload.node_id == "temp"
      assert cmd.payload.op == "animate_to"
      assert cmd.payload.payload == %{value: 90.0}
    end

    test "commands target the correct node_id" do
      cmd_a = Gauge.set_value("gauge-a", 10)
      cmd_b = Gauge.set_value("gauge-b", 20)
      assert cmd_a.payload.node_id == "gauge-a"
      assert cmd_b.payload.node_id == "gauge-b"
    end

    test "command payload has the standard three-key shape" do
      cmd = Gauge.set_value("g1", 0)
      assert Map.keys(cmd.payload) |> Enum.sort() == [:node_id, :op, :payload]
    end

    test "commands enforce widget_id is binary" do
      assert_raise FunctionClauseError, fn ->
        Gauge.set_value(:not_binary, 42)
      end
    end

    test "commands enforce type guard on value param" do
      assert_raise FunctionClauseError, fn ->
        Gauge.set_value("g1", "not a number")
      end
    end
  end

  # -- A11y support -----------------------------------------------------------

  describe "a11y support" do
    test "a11y prop available without explicit declaration" do
      a11y = %{role: :meter, label: "Temperature"}

      node =
        Gauge.new("g1", value: 50, a11y: a11y)
        |> Gauge.build()

      assert %Plushie.Type.A11y{} = node.props[:a11y]
      assert node.props[:a11y].role == :meter
      assert node.props[:a11y].label == "Temperature"
    end

    test "a11y omitted from props when not set" do
      node = Gauge.new("g1") |> Gauge.build()
      refute Map.has_key?(node.props, :a11y)
    end
  end
end
