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

  test "has gauge widget" do
    element = find!("#temp")
    assert element.type == "gauge"
  end

  test "has history text" do
    assert_exists("#history")
  end

  test "initial tree matches snapshot" do
    assert :ok =
             Plushie.Test.assert_tree_snapshot(
               tree(),
               Path.join(["test", "snapshots", "temperature_monitor_initial.json"])
             )
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

  test "high click updates temperature after gauge confirmation" do
    click("#high")
    assert wait_for(fn -> model().temperature == 90.0 end)
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

  test "temperature follows the most recent confirmed button interaction" do
    click("#high")
    click("#reset")
    assert wait_for(fn -> model().temperature == 20.0 end)
  end

  # -- Settings ---------------------------------------------------------------

  test "settings has widget_config" do
    settings = GaugeDemo.TemperatureMonitor.settings()
    assert Keyword.has_key?(settings, :widget_config)
    assert settings[:widget_config]["gauge"]["arcWidth"] == 8
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

  defp wait_for(fun, attempts \\ 20)

  defp wait_for(fun, attempts) when attempts > 0 do
    if fun.() do
      true
    else
      Process.sleep(25)
      wait_for(fun, attempts - 1)
    end
  end

  defp wait_for(_fun, 0), do: false
end
