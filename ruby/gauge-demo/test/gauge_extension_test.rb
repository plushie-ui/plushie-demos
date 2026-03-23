# frozen_string_literal: true

require_relative "test_helper"

class GaugeExtensionTest < Minitest::Test
  # -- Extension metadata --

  def test_type_names
    assert_equal [:gauge], GaugeExtension.type_names
  end

  def test_is_native
    assert GaugeExtension.native?
  end

  def test_not_a_container
    refute GaugeExtension.container?
  end

  def test_rust_crate_path
    assert_equal "native/gauge", GaugeExtension.native_crate
  end

  def test_rust_constructor
    assert_equal "gauge::GaugeExtension::new()",
      GaugeExtension.rust_constructor_expr
  end

  # -- Props --

  def test_prop_names
    names = GaugeExtension.prop_names
    %i[value min max color label width height].each do |name|
      assert_includes names, name
    end
  end

  def test_auto_props
    names = GaugeExtension.prop_names
    assert_includes names, :a11y
    assert_includes names, :event_rate
  end

  def test_props_metadata
    props = GaugeExtension.extension_props

    value_prop = props.find { |p| p[:name] == :value }
    assert_equal :number, value_prop[:type]
    assert_equal 0, value_prop[:default]

    color_prop = props.find { |p| p[:name] == :color }
    assert_equal :color, color_prop[:type]
    assert_equal "#3498db", color_prop[:default]

    label_prop = props.find { |p| p[:name] == :label }
    assert_equal :string, label_prop[:type]
    assert_equal "", label_prop[:default]

    width_prop = props.find { |p| p[:name] == :width }
    assert_equal :length, width_prop[:type]
    assert_equal 200, width_prop[:default]
  end

  # -- Instance creation --

  def test_new_with_defaults
    gauge = GaugeExtension.new("g1")
    assert_equal "g1", gauge.id
    assert_equal 0, gauge.value
    assert_equal 0, gauge.min
    assert_equal 100, gauge.max
    assert_equal "#3498db", gauge.color
    assert_equal "", gauge.label
    assert_equal 200, gauge.width
    assert_equal 200, gauge.height
  end

  def test_new_with_custom_props
    gauge = GaugeExtension.new("g1",
      value: 75, min: 10, max: 90,
      color: "#ff0000", label: "75C")
    assert_equal 75, gauge.value
    assert_equal 10, gauge.min
    assert_equal 90, gauge.max
    assert_equal "#ff0000", gauge.color
    assert_equal "75C", gauge.label
  end

  # -- Immutable setters --

  def test_set_value_returns_copy
    original = GaugeExtension.new("g1", value: 50)
    modified = original.set_value(75)
    assert_equal 50, original.value
    assert_equal 75, modified.value
    assert_equal "g1", modified.id
  end

  def test_set_color
    gauge = GaugeExtension.new("g1")
    updated = gauge.set_color("#ff0000")
    assert_equal "#3498db", gauge.color
    assert_equal "#ff0000", updated.color
  end

  # -- Build --

  def test_build_produces_node
    gauge = GaugeExtension.new("g1", value: 42)
    node = gauge.build
    assert_instance_of Plushie::Node, node
    assert_equal "g1", node.id
    assert_equal "gauge", node.type
  end

  def test_build_includes_props
    gauge = GaugeExtension.new("g1",
      value: 42, min: 0, max: 100,
      color: "#e74c3c", label: "42C",
      width: 200, height: 200)
    node = gauge.build

    assert_equal 42, node.props[:value]
    assert_equal 0, node.props[:min]
    assert_equal 100, node.props[:max]
    assert_equal "#e74c3c", node.props[:color]
    assert_equal "42C", node.props[:label]
    assert_equal 200, node.props[:width]
    assert_equal 200, node.props[:height]
  end

  def test_build_omits_nil_auto_props
    gauge = GaugeExtension.new("g1")
    node = gauge.build
    refute node.props.key?(:a11y)
    refute node.props.key?(:event_rate)
  end

  def test_build_includes_a11y_when_set
    gauge = GaugeExtension.new("g1", a11y: {role: "meter"})
    node = gauge.build
    assert_equal({role: "meter"}, node.props[:a11y])
  end
end
