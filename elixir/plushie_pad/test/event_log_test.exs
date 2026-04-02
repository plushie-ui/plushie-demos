defmodule PlushiePad.EventLogTest do
  use Plushie.Test.WidgetCase, widget: PlushiePad.EventLog

  @moduletag capture_log: true

  describe "displaying events" do
    setup do
      init_widget("log", events: ["click on btn", "input on name", "toggle on check"])
    end

    test "shows event entries in the scrollable log" do
      assert_text("#log-0", "click on btn")
      assert_text("#log-1", "input on name")
      assert_text("#log-2", "toggle on check")
    end

    test "displays the event count" do
      assert_text("#count", "3 events")
    end
  end

  describe "toggling visibility" do
    setup do
      init_widget("log", events: ["click on btn"])
    end

    test "log is visible by default" do
      assert_exists("#log-scroll")
    end

    test "clicking toggle hides the log" do
      click("#toggle-log")
      assert_not_exists("#log-scroll")
    end

    test "clicking toggle twice shows the log again" do
      click("#toggle-log")
      assert_not_exists("#log-scroll")

      click("#toggle-log")
      assert_exists("#log-scroll")
    end

    test "toggle button label reflects state" do
      assert_text("#toggle-log", "Hide Log")

      click("#toggle-log")
      assert_text("#toggle-log", "Show Log")
    end
  end

  describe "empty log" do
    setup do
      init_widget("log", events: [])
    end

    test "shows zero events" do
      assert_text("#count", "0 events")
    end
  end
end
