defmodule PlushiePad.PadTest do
  use Plushie.Test.Case, app: PlushiePad

  test "starter code compiles and renders on init" do
    assert_text("#preview/greeting", "Hello, Plushie!")
  end

  test "sidebar shows title" do
    assert_text("#sidebar-title", "Experiments")
  end

  test "new experiment input exists" do
    assert_exists("#new-name")
  end

  test "auto-save checkbox exists" do
    assert_exists("#auto-save")
  end

  test "event log captures preview clicks" do
    click("#preview/btn")
    assert_exists("#log-0")
  end

  test "save button exists" do
    assert_exists("#save")
  end
end
