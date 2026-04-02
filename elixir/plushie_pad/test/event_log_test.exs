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

    test "clicking toggle hides the log on next render" do
      click("#toggle-log")

      # Widget state updates are applied on the next render cycle.
      # Trigger a re-render by pressing a key that reaches the harness app.
      press("a")

      assert_not_exists("#log-scroll")
    end

    test "clicking toggle twice shows the log again" do
      click("#toggle-log")
      press("a")
      assert_not_exists("#log-scroll")

      click("#toggle-log")
      press("a")
      assert_exists("#log-scroll")
    end

    test "toggle button label reflects state" do
      assert_text("#toggle-log", "Hide Log")

      click("#toggle-log")
      press("a")
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
