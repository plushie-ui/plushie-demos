defmodule SparklineDashboard.DashboardTest do
  use Plushie.Test.Case, app: SparklineDashboard.Dashboard

  # -- Init -------------------------------------------------------------------

  test "starts with empty samples" do
    m = model()
    assert m.cpu_samples == []
    assert m.mem_samples == []
    assert m.net_samples == []
  end

  test "starts running" do
    assert model().running == true
  end

  test "tick count is zero" do
    assert model().tick_count == 0
  end

  # -- View structure ---------------------------------------------------------

  test "has title" do
    assert_text("#title", "System Monitor")
  end

  test "has control buttons" do
    assert_exists("#toggle_running")
    assert_exists("#clear")
  end

  test "has status text" do
    assert_exists("#status")
    assert_text("#status", "0 samples")
  end

  test "has sparkline card labels" do
    assert_exists("#cpu_card/cpu_header/cpu_label")
    assert_exists("#mem_card/mem_header/mem_label")
    assert_exists("#net_card/net_header/net_label")
  end

  test "sparkline widgets have extension type" do
    for metric <- ~w(cpu mem net) do
      element = find!("##{metric}_card/#{metric}_spark")
      assert element.type == "sparkline"
    end
  end

  test "initial tree matches snapshot" do
    assert :ok =
             Plushie.Test.assert_tree_snapshot(
               tree(),
               Path.join(["test", "snapshots", "sparkline_dashboard_initial.json"])
             )
  end

  # -- Controls ---------------------------------------------------------------

  test "toggle pauses the dashboard" do
    click("#toggle_running")
    assert model().running == false
  end

  test "toggle button shows Resume when paused" do
    click("#toggle_running")
    assert find!("#toggle_running") |> text() == "Resume"
  end

  test "toggle resumes the dashboard" do
    click("#toggle_running")
    click("#toggle_running")
    assert model().running == true
  end

  test "clear resets all samples" do
    click("#clear")
    m = model()
    assert m.cpu_samples == []
    assert m.mem_samples == []
    assert m.net_samples == []
    assert m.tick_count == 0
  end

  # -- Subscribe --------------------------------------------------------------

  test "subscribe returns timer when running" do
    subs = SparklineDashboard.Dashboard.subscribe(model())
    assert length(subs) == 1
    assert hd(subs).type == :every
    assert hd(subs).interval == 500
  end

  test "subscribe returns empty when paused" do
    click("#toggle_running")
    assert SparklineDashboard.Dashboard.subscribe(model()) == []
  end
end
