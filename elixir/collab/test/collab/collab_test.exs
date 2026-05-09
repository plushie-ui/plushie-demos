defmodule CollabTest do
  use Plushie.Test.Case, app: Collab

  # -- Init -------------------------------------------------------------------

  test "name defaults to empty string" do
    assert model().name == ""
  end

  test "count defaults to 0" do
    assert model().count == 0
  end

  test "dark_mode defaults to false" do
    assert model().dark_mode == false
  end

  test "returns a Model struct" do
    assert %Collab.Model{} = model()
  end

  # -- Counter ----------------------------------------------------------------

  test "increment increases count" do
    click("#inc")
    assert model().count == 1
  end

  test "decrement decreases count" do
    click("#dec")
    assert model().count == -1
  end

  test "multiple increments accumulate" do
    click("#inc")
    click("#inc")
    click("#inc")
    assert model().count == 3
  end

  # -- Text inputs ------------------------------------------------------------

  test "name input updates name" do
    type_text("#name", "Alice")
    assert model().name == "Alice"
  end

  test "notes input updates notes" do
    type_text("#notes", "meeting at 3pm")
    assert model().notes == "meeting at 3pm"
  end

  # -- Dark mode toggle -------------------------------------------------------

  test "toggle sets dark_mode" do
    toggle("#theme")
    assert model().dark_mode == true
  end

  # -- View structure ---------------------------------------------------------

  test "has header text" do
    assert_text("#header", "Plushie Demo")
  end

  test "has name input" do
    assert_exists("#name")
  end

  test "has counter widgets" do
    assert_exists("#inc")
    assert_exists("#dec")
    assert_exists("#count")
  end

  test "has theme checkbox" do
    assert_exists("#theme")
  end

  test "has notes input" do
    assert_exists("#notes")
  end

  test "initial tree matches snapshot" do
    assert :ok =
             Plushie.Test.assert_tree_snapshot(
               tree(),
               Path.join(["test", "snapshots", "collab_initial.json"])
             )

    assert_screenshot("collab_initial")
  end

  test "count text reflects model" do
    click("#inc")
    click("#inc")
    assert_text("#count", "Count: 2")
  end

  # -- Settings ---------------------------------------------------------------

  test "has default_event_rate" do
    settings = Collab.settings()
    assert Keyword.get(settings, :default_event_rate) == 30
  end
end
