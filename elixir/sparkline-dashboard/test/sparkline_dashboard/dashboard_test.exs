defmodule SparklineDashboard.DashboardTest do
  use ExUnit.Case, async: true

  alias SparklineDashboard.Dashboard
  alias Plushie.Event.{Timer, Widget}

  # -- Helpers ----------------------------------------------------------------

  defp app_init, do: Dashboard.init(%{})

  defp timer_event, do: %Timer{tag: :sample, timestamp: 0}

  defp click(id), do: %Widget{type: :click, id: id}

  defp render_tree(model) do
    Dashboard.view(model) |> Plushie.Tree.normalize()
  end

  defp find_node(nil, _target), do: nil
  defp find_node(%{id: target} = node, target), do: node

  defp find_node(%{children: children}, target) do
    Enum.find_value(children, fn child -> find_node(child, target) end)
  end

  defp find_node(_node, _target), do: nil

  defp sparkline_props(model, node_id) do
    tree = render_tree(model)
    node = find_node(tree, node_id)
    assert node != nil, "sparkline node '#{node_id}' not found in tree"
    node.props
  end

  # Sparkline card children are scoped under the card's column ID.
  # e.g. text("cpu_label") inside column(id: "cpu_card") gets
  # wire ID "cpu_card/cpu_label".
  defp card(metric, child), do: "#{metric}_card/#{metric}_#{child}"

  # -- Data generators --------------------------------------------------------

  describe "cpu_sample/1" do
    test "values are in valid range" do
      for tick <- 0..50 do
        val = Dashboard.cpu_sample(tick)
        assert val >= 0 and val <= 100, "cpu_sample(#{tick}) = #{val}"
      end
    end

    test "incorporates sine wave component" do
      # Generate many samples at two different ticks to see the sine offset.
      # sin(0) * 15 = 0; sin(5 * 0.1) * 15 ~ 7.2
      :rand.seed(:exsss, {1, 2, 3})
      samples_at_0 = for _ <- 1..200, do: Dashboard.cpu_sample(0)

      :rand.seed(:exsss, {1, 2, 3})
      samples_at_5 = for _ <- 1..200, do: Dashboard.cpu_sample(5)

      avg_0 = Enum.sum(samples_at_0) / length(samples_at_0)
      avg_5 = Enum.sum(samples_at_5) / length(samples_at_5)

      expected_offset = :math.sin(5 * 0.1) * 15
      assert abs(avg_5 - avg_0 - expected_offset) < 3
    end
  end

  describe "mem_sample/1" do
    test "values oscillate between 20 and 100" do
      for tick <- 0..200 do
        val = Dashboard.mem_sample(tick)
        assert val >= 20 and val <= 100, "mem_sample(#{tick}) = #{val}"
      end
    end
  end

  describe "net_sample/0" do
    test "values are in 0-100 range" do
      for _ <- 1..100 do
        val = Dashboard.net_sample()
        assert val >= 0 and val <= 100, "net_sample() = #{val}"
      end
    end
  end

  # -- Init -------------------------------------------------------------------

  describe "init/1" do
    test "starts with empty samples" do
      model = app_init()
      assert model.cpu_samples == []
      assert model.mem_samples == []
      assert model.net_samples == []
    end

    test "starts running" do
      assert app_init().running == true
    end

    test "tick count is zero" do
      assert app_init().tick_count == 0
    end
  end

  # -- Update: timer ----------------------------------------------------------

  describe "update/2 timer" do
    test "adds one sample to each metric" do
      model = Dashboard.update(app_init(), timer_event())
      assert length(model.cpu_samples) == 1
      assert length(model.mem_samples) == 1
      assert length(model.net_samples) == 1
    end

    test "increments tick count" do
      model =
        app_init()
        |> Dashboard.update(timer_event())
        |> Dashboard.update(timer_event())
        |> Dashboard.update(timer_event())

      assert model.tick_count == 3
    end

    test "ignored when paused" do
      model = %{app_init() | running: false}
      updated = Dashboard.update(model, timer_event())
      assert updated.cpu_samples == []
      assert updated.tick_count == 0
    end

    test "caps samples at 100" do
      model = %{
        app_init()
        | cpu_samples: Enum.to_list(1..100),
          mem_samples: Enum.to_list(1..100),
          net_samples: Enum.to_list(1..100)
      }

      updated = Dashboard.update(model, timer_event())
      assert length(updated.cpu_samples) == 100
      assert length(updated.mem_samples) == 100
      assert length(updated.net_samples) == 100
      # Oldest sample dropped
      assert hd(updated.cpu_samples) == 2
    end

    test "samples are numbers" do
      model = Dashboard.update(app_init(), timer_event())
      assert is_number(hd(model.cpu_samples))
      assert is_number(hd(model.mem_samples))
      assert is_number(hd(model.net_samples))
    end
  end

  # -- Update: controls -------------------------------------------------------

  describe "update/2 controls" do
    test "toggle pauses the dashboard" do
      model = Dashboard.update(app_init(), click("toggle_running"))
      assert model.running == false
    end

    test "toggle resumes the dashboard" do
      model = %{app_init() | running: false}
      updated = Dashboard.update(model, click("toggle_running"))
      assert updated.running == true
    end

    test "clear resets all samples and tick count" do
      model = %{
        app_init()
        | cpu_samples: [1, 2, 3],
          mem_samples: [4, 5, 6],
          net_samples: [7, 8, 9],
          tick_count: 42
      }

      updated = Dashboard.update(model, click("clear"))
      assert updated.cpu_samples == []
      assert updated.mem_samples == []
      assert updated.net_samples == []
      assert updated.tick_count == 0
    end

    test "clear preserves running state" do
      model = Dashboard.update(app_init(), click("clear"))
      assert model.running == true
    end
  end

  # -- Update: unknown events -------------------------------------------------

  describe "update/2 unknown events" do
    test "returns model unchanged" do
      model = app_init()
      result = Dashboard.update(model, click("nonexistent"))
      assert result == model
    end
  end

  # -- Subscribe --------------------------------------------------------------

  describe "subscribe/1" do
    test "returns timer subscription when running" do
      subs = Dashboard.subscribe(app_init())
      assert length(subs) == 1

      sub = hd(subs)
      assert sub.type == :every
      assert sub.interval == 500
      assert sub.tag == :sample
    end

    test "returns empty list when paused" do
      model = %{app_init() | running: false}
      assert Dashboard.subscribe(model) == []
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
      assert node.props[:content] == "System Monitor"
    end

    test "contains control widgets" do
      tree = render_tree(app_init())
      assert find_node(tree, "toggle_running") != nil
      assert find_node(tree, "clear") != nil
      assert find_node(tree, "status") != nil
    end

    test "contains all three sparkline widgets" do
      tree = render_tree(app_init())
      assert find_node(tree, card("cpu", "spark")) != nil
      assert find_node(tree, card("mem", "spark")) != nil
      assert find_node(tree, card("net", "spark")) != nil
    end

    test "contains sparkline labels" do
      tree = render_tree(app_init())
      assert find_node(tree, card("cpu", "label")) != nil
      assert find_node(tree, card("mem", "label")) != nil
      assert find_node(tree, card("net", "label")) != nil
    end

    test "sparkline widgets have the custom extension type" do
      tree = render_tree(app_init())

      for metric <- ~w(cpu mem net) do
        node = find_node(tree, card(metric, "spark"))
        assert node != nil, "#{metric}_spark not found"
        assert node.type == "sparkline"
      end
    end

    test "pause button shows Pause when running" do
      tree = render_tree(app_init())
      node = find_node(tree, "toggle_running")
      assert node.props[:label] == "Pause"
    end

    test "pause button shows Resume when paused" do
      model = %{app_init() | running: false}
      tree = render_tree(model)
      node = find_node(tree, "toggle_running")
      assert node.props[:label] == "Resume"
    end

    test "status shows sample count" do
      model = %{app_init() | cpu_samples: Enum.to_list(1..42)}
      tree = render_tree(model)
      node = find_node(tree, "status")
      assert node.props[:content] == "42 samples"
    end

    test "value text shown when data present" do
      model = %{app_init() | cpu_samples: [10.0, 20.0, 30.5]}
      tree = render_tree(model)
      node = find_node(tree, card("cpu", "value"))
      assert node != nil
      assert node.props[:content] == "30.5"
    end

    test "value text absent when data empty" do
      tree = render_tree(app_init())
      assert find_node(tree, card("cpu", "value")) == nil
    end
  end

  # -- Wire-level sparkline props ---------------------------------------------

  describe "sparkline props" do
    test "initial CPU sparkline props" do
      props = sparkline_props(app_init(), card("cpu", "spark"))
      assert props[:data] == []
      assert props[:color] == Plushie.Type.Color.cast("#4CAF50")
      assert props[:stroke_width] == 2.0
      assert props[:fill] == true
      assert props[:height] == 60.0
    end

    test "initial network sparkline has no fill" do
      props = sparkline_props(app_init(), card("net", "spark"))
      assert props[:color] == Plushie.Type.Color.cast("#FF9800")
      assert props[:fill] == false
    end

    test "memory sparkline color is blue" do
      props = sparkline_props(app_init(), card("mem", "spark"))
      assert props[:color] == Plushie.Type.Color.cast("#2196F3")
      assert props[:fill] == true
    end

    test "sparkline data populated after tick" do
      model = Dashboard.update(app_init(), timer_event())
      props = sparkline_props(model, card("cpu", "spark"))
      assert length(props[:data]) == 1
      assert is_number(hd(props[:data]))
    end
  end

  # -- Sequential journey -----------------------------------------------------

  describe "sequential journey" do
    test "full interaction sequence" do
      model = app_init()

      # -- Initial state --
      assert model.cpu_samples == []
      assert model.running == true
      assert model.tick_count == 0

      # -- First tick --
      model = Dashboard.update(model, timer_event())
      assert length(model.cpu_samples) == 1
      assert model.tick_count == 1

      # -- Second tick --
      model = Dashboard.update(model, timer_event())
      assert length(model.cpu_samples) == 2
      assert model.tick_count == 2

      # -- Pause --
      model = Dashboard.update(model, click("toggle_running"))
      assert model.running == false

      # -- Tick ignored while paused --
      model = Dashboard.update(model, timer_event())
      assert length(model.cpu_samples) == 2
      assert model.tick_count == 2

      # -- Resume --
      model = Dashboard.update(model, click("toggle_running"))
      assert model.running == true

      # -- Tick after resume --
      model = Dashboard.update(model, timer_event())
      assert length(model.cpu_samples) == 3
      assert model.tick_count == 3

      # -- Clear --
      model = Dashboard.update(model, click("clear"))
      assert model.cpu_samples == []
      assert model.mem_samples == []
      assert model.net_samples == []
      assert model.tick_count == 0

      # -- Wire props after clear --
      props = sparkline_props(model, card("cpu", "spark"))
      assert props[:data] == []
    end
  end

  # -- Rapid interactions -----------------------------------------------------

  describe "rapid interactions" do
    test "rapid toggles end up in correct state" do
      model =
        Enum.reduce(1..10, app_init(), fn _i, acc ->
          Dashboard.update(acc, click("toggle_running"))
        end)

      # Even number of toggles -> back to running
      assert model.running == true
    end

    test "rapid ticks then clear" do
      model =
        Enum.reduce(1..50, app_init(), fn _i, acc ->
          Dashboard.update(acc, timer_event())
        end)

      assert length(model.cpu_samples) == 50

      model = Dashboard.update(model, click("clear"))
      assert model.cpu_samples == []
      assert model.tick_count == 0
    end

    test "samples stay capped under sustained load" do
      model =
        Enum.reduce(1..120, app_init(), fn _i, acc ->
          Dashboard.update(acc, timer_event())
        end)

      assert length(model.cpu_samples) == 100
      assert length(model.mem_samples) == 100
      assert length(model.net_samples) == 100
      assert model.tick_count == 120
    end
  end
end
