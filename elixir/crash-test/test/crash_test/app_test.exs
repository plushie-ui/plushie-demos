defmodule CrashTest.AppTest do
  use Plushie.Test.Case, app: CrashTest.App

  # -- Init -------------------------------------------------------------------

  test "starts with count at zero" do
    assert model().count == 0
  end

  test "crash_view starts false" do
    assert model().crash_view == false
  end

  # -- Counter (proof of life) ------------------------------------------------

  test "increment" do
    click("#inc")
    assert model().count == 1
  end

  test "decrement" do
    click("#dec")
    assert model().count == -1
  end

  test "multiple increments accumulate" do
    click("#inc")
    click("#inc")
    click("#inc")
    assert model().count == 3
  end

  # -- View structure ---------------------------------------------------------

  test "has title" do
    assert_text("#title", "Crash Test")
  end

  test "has counter widgets" do
    assert_exists("#inc")
    assert_exists("#dec")
    assert_exists("#count")
  end

  test "count reflects model" do
    click("#inc")
    click("#inc")
    assert_text("#count", "Count: 2")
  end

  test "has crash buttons" do
    assert_exists("#crash_update")
    assert_exists("#crash_view")
    assert_exists("#panic_widget")
  end

  test "has description texts" do
    assert_exists("#crash_update_desc")
    assert_exists("#crash_view_desc")
    assert_exists("#panic_desc")
  end

  test "has crash widget" do
    element = find!("#crash_ext")
    assert element.type == "crash_widget"
  end

  test "initial tree matches snapshot" do
    assert :ok =
             Plushie.Test.assert_tree_snapshot(
               tree(),
               Path.join(["test", "snapshots", "crash_test_initial.json"])
             )
  end

  # -- Unknown events ---------------------------------------------------------

  test "unknown click leaves model unchanged" do
    count_before = model().count
    click("#inc")
    click("#dec")
    assert model().count == count_before
  end
end
