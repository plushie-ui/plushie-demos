defmodule GaugeDemo.TemperatureMonitorTest do
  use ExUnit.Case, async: true

  alias GaugeDemo.TemperatureMonitor
  alias Plushie.Event.Widget

  # -- Helpers ----------------------------------------------------------------

  defp app_init, do: TemperatureMonitor.init(%{})

  defp unwrap({model, cmd}), do: {model, cmd}
  defp unwrap(model), do: {model, nil}

  defp render_tree(model) do
    TemperatureMonitor.view(model) |> Plushie.Tree.normalize()
  end

  defp find_node(nil, _target), do: nil
  defp find_node(%{id: target} = node, target), do: node

  defp find_node(%{children: children}, target) do
    Enum.find_value(children, fn child -> find_node(child, target) end)
  end

  defp find_node(_node, _target), do: nil

  defp gauge_props(model) do
    tree = render_tree(model)
    node = find_node(tree, "temp")
    assert node != nil, "gauge node 'temp' not found in tree"
    node.props
  end

  defp value_changed(temp) do
    %Widget{type: "value_changed", id: "temp", data: %{"value" => temp}}
  end

  # -- Pure helper functions --------------------------------------------------

  describe "temperature_status/1" do
    test "cool below 40" do
      assert TemperatureMonitor.temperature_status(10) == "Cool"
      assert TemperatureMonitor.temperature_status(0) == "Cool"
      assert TemperatureMonitor.temperature_status(39) == "Cool"
    end

    test "normal from 40 to 59" do
      assert TemperatureMonitor.temperature_status(40) == "Normal"
      assert TemperatureMonitor.temperature_status(50) == "Normal"
      assert TemperatureMonitor.temperature_status(59) == "Normal"
    end

    test "warning from 60 to 79" do
      assert TemperatureMonitor.temperature_status(60) == "Warning"
      assert TemperatureMonitor.temperature_status(70) == "Warning"
      assert TemperatureMonitor.temperature_status(79) == "Warning"
    end

    test "critical at 80 and above" do
      assert TemperatureMonitor.temperature_status(80) == "Critical"
      assert TemperatureMonitor.temperature_status(90) == "Critical"
      assert TemperatureMonitor.temperature_status(100) == "Critical"
    end
  end

  describe "status_color/1" do
    test "blue for cool" do
      assert TemperatureMonitor.status_color(10) == "#3498db"
    end

    test "green for normal" do
      assert TemperatureMonitor.status_color(50) == "#27ae60"
    end

    test "orange for warning" do
      assert TemperatureMonitor.status_color(70) == "#e67e22"
    end

    test "red for critical" do
      assert TemperatureMonitor.status_color(90) == "#e74c3c"
    end
  end

  # -- Init -------------------------------------------------------------------

  describe "init/1" do
    test "initial temperature is 20" do
      model = app_init()
      assert model.temperature == 20.0
    end

    test "initial target_temp matches temperature" do
      model = app_init()
      assert model.target_temp == 20.0
    end

    test "initial history contains starting temperature" do
      model = app_init()
      assert model.history == [20.0]
    end
  end

  # -- Update: button clicks --------------------------------------------------

  describe "update/2 reset click" do
    test "sends set_value extension command" do
      {_model, cmd} = TemperatureMonitor.update(app_init(), click("reset")) |> unwrap()
      assert cmd.type == :extension_command
      assert cmd.payload.op == "set_value"
      assert cmd.payload.payload == %{value: 20.0}
    end

    test "updates target_temp to 20" do
      model = %{app_init() | target_temp: 75.0}
      {new_model, _cmd} = TemperatureMonitor.update(model, click("reset")) |> unwrap()
      assert new_model.target_temp == 20.0
    end

    test "does not change temperature (waits for value_changed event)" do
      model = %{app_init() | temperature: 90.0, target_temp: 90.0}
      {new_model, _cmd} = TemperatureMonitor.update(model, click("reset")) |> unwrap()
      assert new_model.temperature == 90.0
    end
  end

  describe "update/2 high click" do
    test "sends set_value extension command for 90" do
      {_model, cmd} = TemperatureMonitor.update(app_init(), click("high")) |> unwrap()
      assert cmd.type == :extension_command
      assert cmd.payload.op == "set_value"
      assert cmd.payload.payload == %{value: 90.0}
    end

    test "updates target_temp to 90" do
      {new_model, _cmd} = TemperatureMonitor.update(app_init(), click("high")) |> unwrap()
      assert new_model.target_temp == 90.0
    end

    test "does not change temperature (waits for value_changed event)" do
      {new_model, _cmd} = TemperatureMonitor.update(app_init(), click("high")) |> unwrap()
      assert new_model.temperature == 20.0
    end
  end

  # -- Update: slider ---------------------------------------------------------

  describe "update/2 slider" do
    test "sends animate_to extension command" do
      {_model, cmd} = TemperatureMonitor.update(app_init(), slide("target", 75.0)) |> unwrap()
      assert cmd.type == :extension_command
      assert cmd.payload.op == "animate_to"
      assert cmd.payload.payload == %{value: 75.0}
    end

    test "updates target_temp" do
      {new_model, _cmd} = TemperatureMonitor.update(app_init(), slide("target", 75.0)) |> unwrap()
      assert new_model.target_temp == 75.0
    end

    test "does not change current temperature" do
      {new_model, _cmd} = TemperatureMonitor.update(app_init(), slide("target", 75.0)) |> unwrap()
      assert new_model.temperature == 20.0
    end
  end

  # -- Update: extension events -----------------------------------------------

  describe "update/2 value_changed event" do
    test "updates temperature from Rust confirmation" do
      {model, _cmd} = TemperatureMonitor.update(app_init(), value_changed(42.0)) |> unwrap()
      assert model.temperature == 42.0
    end

    test "appends to history" do
      {model, _cmd} = TemperatureMonitor.update(app_init(), value_changed(42.0)) |> unwrap()
      assert model.history == [20.0, 42.0]
    end

    test "does not return a command" do
      {_model, cmd} = TemperatureMonitor.update(app_init(), value_changed(42.0)) |> unwrap()
      assert cmd == nil
    end

    test "history accumulates across events" do
      model = app_init()

      model =
        Enum.reduce([30.0, 50.0, 70.0], model, fn temp, acc ->
          {new_model, _} = TemperatureMonitor.update(acc, value_changed(temp)) |> unwrap()
          new_model
        end)

      assert model.history == [20.0, 30.0, 50.0, 70.0]
    end

    test "history is capped at 50 entries" do
      # Start with a model that already has 50 entries
      model = %{app_init() | history: Enum.map(1..50, &(&1 * 1.0))}
      assert length(model.history) == 50

      {model, _} = TemperatureMonitor.update(model, value_changed(99.0)) |> unwrap()
      assert length(model.history) == 50
      assert List.first(model.history) == 2.0
      assert List.last(model.history) == 99.0
    end
  end

  # -- Update: unknown events -------------------------------------------------

  describe "update/2 unknown events" do
    test "returns model unchanged for unknown click" do
      model = app_init()
      result = TemperatureMonitor.update(model, click("nonexistent"))
      assert result == model
    end

    test "returns model unchanged for unrelated event" do
      model = app_init()
      event = %Widget{type: :input, id: "something", value: "text"}
      result = TemperatureMonitor.update(model, event)
      assert result == model
    end
  end

  # -- View tree structure ----------------------------------------------------

  describe "view/1 tree structure" do
    test "root is a window with correct id" do
      tree = render_tree(app_init())
      assert tree.type == "window"
      assert tree.id == "main"
    end

    test "contains title text" do
      tree = render_tree(app_init())
      node = find_node(tree, "title")
      assert node != nil
      assert node.props[:content] == "Temperature Monitor"
    end

    test "contains gauge with extension type" do
      tree = render_tree(app_init())
      node = find_node(tree, "temp")
      assert node != nil
      # "gauge" is NOT a built-in widget type -- it only exists because
      # the Rust extension registered it via WidgetExtension::type_names
      assert node.type == "gauge"
    end

    test "contains status text" do
      tree = render_tree(app_init())
      node = find_node(tree, "status")
      assert node != nil
      assert node.props[:content] =~ "Cool"
    end

    test "contains reading text with current and target" do
      tree = render_tree(app_init())
      node = find_node(tree, "reading")
      assert node != nil
      content = node.props[:content]
      assert content =~ "20"
      assert content =~ "Target"
    end

    test "contains slider" do
      tree = render_tree(app_init())
      node = find_node(tree, "target")
      assert node != nil
      assert node.type == "slider"
    end

    test "contains reset and high buttons" do
      tree = render_tree(app_init())
      assert find_node(tree, "reset") != nil
      assert find_node(tree, "high") != nil
    end

    test "contains history text" do
      tree = render_tree(app_init())
      node = find_node(tree, "history")
      assert node != nil
      assert node.props[:content] =~ "20"
    end
  end

  # -- Wire-level gauge props -------------------------------------------------

  describe "gauge props reflect state" do
    test "initial gauge props" do
      props = gauge_props(app_init())
      assert props[:value] == 20.0
      assert props[:min] == 0
      assert props[:max] == 100
      assert props[:color] == Plushie.Type.Color.cast("#3498db")
    end

    test "gauge props after high temperature" do
      model = %{app_init() | temperature: 90.0}
      props = gauge_props(model)
      assert props[:value] == 90.0
      assert props[:color] == Plushie.Type.Color.cast("#e74c3c")
    end

    test "gauge color changes with temperature thresholds" do
      assert gauge_props(%{app_init() | temperature: 10.0})[:color] ==
               Plushie.Type.Color.cast("#3498db")

      assert gauge_props(%{app_init() | temperature: 50.0})[:color] ==
               Plushie.Type.Color.cast("#27ae60")

      assert gauge_props(%{app_init() | temperature: 70.0})[:color] ==
               Plushie.Type.Color.cast("#e67e22")

      assert gauge_props(%{app_init() | temperature: 90.0})[:color] ==
               Plushie.Type.Color.cast("#e74c3c")
    end

    test "gauge label shows degrees" do
      props = gauge_props(app_init())
      assert props[:label] == "20\u00B0C"
    end

    test "gauge label updates with temperature" do
      model = %{app_init() | temperature: 85.0}
      props = gauge_props(model)
      assert props[:label] == "85\u00B0C"
    end
  end

  # -- Stateful journey -------------------------------------------------------

  describe "stateful journey" do
    test "full interaction sequence" do
      model = app_init()

      # -- Initial state --
      assert model.temperature == 20.0
      assert model.target_temp == 20.0
      assert model.history == [20.0]

      props = gauge_props(model)
      assert props[:value] == 20.0
      assert props[:color] == Plushie.Type.Color.cast("#3498db")

      # -- Click high --
      {model, cmd} = TemperatureMonitor.update(model, click("high")) |> unwrap()
      assert cmd.type == :extension_command
      assert model.target_temp == 90.0
      assert model.temperature == 20.0

      # Simulate Rust confirming the value change
      {model, _} = TemperatureMonitor.update(model, value_changed(90.0)) |> unwrap()
      assert model.temperature == 90.0

      props = gauge_props(model)
      assert props[:value] == 90.0
      assert props[:color] == Plushie.Type.Color.cast("#e74c3c")
      assert props[:label] == "90\u00B0C"

      # -- Click reset --
      {model, cmd} = TemperatureMonitor.update(model, click("reset")) |> unwrap()
      assert cmd.type == :extension_command
      assert model.target_temp == 20.0

      {model, _} = TemperatureMonitor.update(model, value_changed(20.0)) |> unwrap()
      assert model.temperature == 20.0

      props = gauge_props(model)
      assert props[:value] == 20.0
      assert props[:color] == Plushie.Type.Color.cast("#3498db")

      # -- Slide to 75 --
      {model, cmd} = TemperatureMonitor.update(model, slide("target", 75.0)) |> unwrap()
      assert model.target_temp == 75.0
      assert model.temperature == 20.0
      assert cmd.payload.op == "animate_to"

      # -- History reflects the full sequence --
      assert model.history == [20.0, 90.0, 20.0]
    end
  end

  # -- Rapid interactions -----------------------------------------------------

  describe "rapid interactions" do
    test "rapid high/reset maintains consistency" do
      model = app_init()

      model =
        Enum.reduce(1..5, model, fn _i, acc ->
          {acc, _} = TemperatureMonitor.update(acc, click("high")) |> unwrap()
          {acc, _} = TemperatureMonitor.update(acc, value_changed(90.0)) |> unwrap()
          {acc, _} = TemperatureMonitor.update(acc, click("reset")) |> unwrap()
          {acc, _} = TemperatureMonitor.update(acc, value_changed(20.0)) |> unwrap()
          acc
        end)

      assert model.temperature == 20.0
      assert model.target_temp == 20.0

      # History alternates: 20 -> 90 -> 20 -> 90 -> ... -> 20
      assert List.first(model.history) == 20.0
      assert List.last(model.history) == 20.0

      model.history
      |> Enum.with_index()
      |> Enum.each(fn {temp, i} ->
        expected = if rem(i, 2) == 0, do: 20.0, else: 90.0
        assert temp == expected, "history[#{i}] = #{temp}, expected #{expected}"
      end)
    end

    test "each click produces the correct command" do
      model = app_init()
      commands = []

      {commands, _model} =
        Enum.reduce(1..3, {commands, model}, fn _i, {cmds, acc} ->
          {acc, cmd_high} = TemperatureMonitor.update(acc, click("high")) |> unwrap()
          {acc, cmd_reset} = TemperatureMonitor.update(acc, click("reset")) |> unwrap()
          {cmds ++ [cmd_high, cmd_reset], acc}
        end)

      commands
      |> Enum.with_index()
      |> Enum.each(fn {cmd, i} ->
        assert cmd.type == :extension_command
        assert cmd.payload.op == "set_value"

        if rem(i, 2) == 0 do
          assert cmd.payload.payload == %{value: 90.0}
        else
          assert cmd.payload.payload == %{value: 20.0}
        end
      end)
    end
  end

  # -- Settings ---------------------------------------------------------------

  describe "settings/0" do
    test "extension_config is present" do
      settings = TemperatureMonitor.settings()
      assert Keyword.has_key?(settings, :extension_config)
      assert Map.has_key?(settings[:extension_config], "gauge")
    end

    test "gauge config values" do
      cfg = TemperatureMonitor.settings()[:extension_config]["gauge"]
      assert cfg["arcWidth"] == 8
      assert cfg["tickCount"] == 10
    end
  end

  # -- Event constructors (private test helpers) ------------------------------

  defp click(id), do: %Widget{type: :click, id: id}
  defp slide(id, value), do: %Widget{type: :slide, id: id, value: value}
end
