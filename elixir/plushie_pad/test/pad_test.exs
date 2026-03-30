defmodule PlushiePad.PadTest do
  use Plushie.Test.Case, app: PlushiePad

  test "starter code compiles and renders on init" do
    assert_text("#preview/greeting", "Hello, Plushie!")
    assert_exists("#preview/btn")
  end

  test "save button exists" do
    assert_exists("#save")
  end

  test "event log exists" do
    assert_exists("#log")
  end

  test "clicking preview button logs an event" do
    click("#preview/btn")
    assert_exists("#log-0")
  end
end
