defmodule PlushiePad.EventLogTest do
  use Plushie.Test.WidgetCase, widget: PlushiePad.EventLog

  setup do
    init_widget("log", events: ["click on btn", "input on name"])
  end

  test "shows event entries" do
    assert_text("#log/log-scroll/log-0", "click on btn")
  end
end
