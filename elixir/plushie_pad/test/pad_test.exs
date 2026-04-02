defmodule PlushiePad.PadTest do
  use Plushie.Test.Case, app: PlushiePad

  @moduletag capture_log: true

  # Ch 3: verify layout
  test "pad has editor and preview panes" do
    assert_exists("#editor")
    assert_exists("#preview")
  end

  # Ch 4: verify compilation
  test "starter code compiles and renders on init" do
    assert_text("#preview/greeting", "Hello, Plushie!")
    assert_exists("#preview/btn")
  end

  # Ch 5: verify event log
  test "clicking preview button logs an event" do
    click("#preview/btn")
    assert_exists("#log-0")
  end

  # Ch 6: verify sidebar and inputs
  test "sidebar and input exist" do
    assert_text("#sidebar-title", "Experiments")
    assert_exists("#new-name")
    assert_exists("#auto-save")
  end

  # Ch 9: verify keyboard shortcut
  test "ctrl+s saves and compiles" do
    press("ctrl+s")
    assert_exists("#preview/greeting")
  end
end
