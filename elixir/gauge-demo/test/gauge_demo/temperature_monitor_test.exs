defmodule GaugeDemo.TemperatureMonitorTest do
  use Plushie.Test.Case, app: GaugeDemo.TemperatureMonitor

  # -- Init -------------------------------------------------------------------

  test "initial temperature is 20" do
    assert model().temperature == 20.0
  end

  test "initial target_temp matches temperature" do
    assert model().target_temp == 20.0
  end

  test "initial history contains starting temperature" do
    assert model().history == [20.0]
  end

  # -- View structure ---------------------------------------------------------

  test "has title" do
    assert_text("#title", "Temperature Monitor")
  end

  test "has status text" do
    assert_exists("#status")
  end

  test "has reading text" do
    assert_exists("#reading")
  end

  test "has slider" do
    assert_exists("#target")
  end

  test "has reset and high buttons" do
    assert_exists("#reset")
    assert_exists("#high")
  end

  test "has gauge extension widget" do
    element = find!("#temp")
    assert element.type == "gauge"
  end

  test "has history text" do
    assert_exists("#history")
  end

  # -- Button interactions ----------------------------------------------------

  test "reset click updates target_temp" do
    click("#high")
    assert model().target_temp == 90.0

    click("#reset")
    assert model().target_temp == 20.0
  end

  test "high click updates target_temp" do
    click("#high")
    assert model().target_temp == 90.0
  end

  test "buttons do not change temperature directly (waits for extension event)" do
    click("#high")
    # Temperature only updates when the Rust extension confirms via
    # value_changed event. Without the extension running, it stays at 20.
    assert model().temperature == 20.0
  end

  # -- Slider interaction -----------------------------------------------------

  test "slider updates target_temp" do
    slide("#target", 75.0)
    assert model().target_temp == 75.0
  end

  test "slider does not change current temperature" do
    slide("#target", 75.0)
    assert model().temperature == 20.0
  end

  # -- Unknown events ---------------------------------------------------------

  test "counter still works after unrelated interactions" do
    initial = model().temperature
    click("#high")
    click("#reset")
    assert model().temperature == initial
  end

  # -- Settings ---------------------------------------------------------------

  test "settings has extension_config" do
    settings = GaugeDemo.TemperatureMonitor.settings()
    assert Keyword.has_key?(settings, :extension_config)
    assert settings[:extension_config]["gauge"]["arcWidth"] == 8
  end

  # -- Gauge wire props -------------------------------------------------------

  test "gauge carries correct initial props" do
    gauge = find!("#temp")
    assert gauge.props[:value] == 20.0
    assert gauge.props[:min] == 0
    assert gauge.props[:max] == 100
  end

  test "gauge label shows degrees" do
    gauge = find!("#temp")
    assert gauge.props[:label] == "20\u00B0C"
  end
end
