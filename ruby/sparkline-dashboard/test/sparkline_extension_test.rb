# frozen_string_literal: true

require_relative "test_helper"

class SparklineExtensionTest < Minitest::Test
  def test_type_names
    assert_equal [:sparkline], SparklineExtension.type_names
  end

  def test_is_native
    assert SparklineExtension.native?
  end

  def test_rust_crate_path
    assert_equal "native/sparkline", SparklineExtension.native_crate
  end

  def test_rust_constructor
    assert_equal "sparkline::SparklineExtension::new()",
      SparklineExtension.rust_constructor_expr
  end

  def test_prop_names_include_all_declared_props
    names = SparklineExtension.prop_names
    assert_includes names, :data
    assert_includes names, :color
    assert_includes names, :stroke_width
    assert_includes names, :fill
    assert_includes names, :height
  end

  def test_prop_names_include_auto_added_props
    names = SparklineExtension.prop_names
    assert_includes names, :a11y
    assert_includes names, :event_rate
  end

  def test_widget_props_metadata
    props = SparklineExtension.widget_props
    data_prop = props.find { |p| p[:name] == :data }
    assert_equal :any, data_prop[:type]
    assert_equal [], data_prop[:default]

    color_prop = props.find { |p| p[:name] == :color }
    assert_equal :color, color_prop[:type]
    assert_equal "#4CAF50", color_prop[:default]
  end

  def test_new_with_defaults
    spark = SparklineExtension.new("test-1")
    assert_equal "test-1", spark.id
    assert_equal [], spark.data
    assert_equal "#4CAF50", spark.color
    assert_equal 2.0, spark.stroke_width
    assert_equal false, spark.fill
    assert_equal 60.0, spark.height
  end

  def test_new_with_custom_props
    spark = SparklineExtension.new("s1",
      data: [1, 2, 3],
      color: "#FF0000",
      stroke_width: 3.0,
      fill: true,
      height: 80.0)
    assert_equal [1, 2, 3], spark.data
    assert_equal "#FF0000", spark.color
    assert_equal 3.0, spark.stroke_width
    assert_equal true, spark.fill
    assert_equal 80.0, spark.height
  end

  def test_set_returns_modified_copy
    original = SparklineExtension.new("s1", color: "#FF0000")
    modified = original.set_color("#00FF00")

    assert_equal "#FF0000", original.color
    assert_equal "#00FF00", modified.color
    assert_equal "s1", modified.id
  end

  def test_set_data
    spark = SparklineExtension.new("s1")
    updated = spark.set_data([10, 20, 30])
    assert_equal [], spark.data
    assert_equal [10, 20, 30], updated.data
  end

  def test_set_fill
    spark = SparklineExtension.new("s1")
    updated = spark.set_fill(true)
    assert_equal false, spark.fill
    assert_equal true, updated.fill
  end

  def test_build_produces_node
    spark = SparklineExtension.new("s1", data: [1, 2, 3], color: "#FF0000")
    node = spark.build

    assert_instance_of Plushie::Node, node
    assert_equal "s1", node.id
    assert_equal "sparkline", node.type
  end

  def test_build_includes_props_in_node
    spark = SparklineExtension.new("s1",
      data: [10, 20],
      color: "#FF0000",
      fill: true,
      stroke_width: 3.0,
      height: 80.0)
    node = spark.build

    assert_equal [10, 20], node.props[:data]
    assert_equal "#FF0000", node.props[:color]
    assert_equal true, node.props[:fill]
    assert_equal 3.0, node.props[:stroke_width]
    assert_equal 80.0, node.props[:height]
  end

  def test_build_omits_nil_props
    spark = SparklineExtension.new("s1")
    node = spark.build

    refute node.props.key?(:a11y)
    refute node.props.key?(:event_rate)
  end

  def test_a11y_prop
    spark = SparklineExtension.new("s1", a11y: {role: "img", label: "CPU chart"})
    assert_equal({role: "img", label: "CPU chart"}, spark.a11y)

    node = spark.build
    assert_equal({role: "img", label: "CPU chart"}, node.props[:a11y])
  end

  def test_event_rate_prop
    spark = SparklineExtension.new("s1", event_rate: 30)
    assert_equal 30, spark.event_rate

    node = spark.build
    assert_equal 30, node.props[:event_rate]
  end

  def test_not_a_container
    refute SparklineExtension.container?
  end
end
