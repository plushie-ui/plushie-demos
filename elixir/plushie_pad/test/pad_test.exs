defmodule PlushiePad.PadTest do
  use Plushie.Test.Case, app: PlushiePad

  test "starter code compiles and renders on init" do
    assert_text("#preview/greeting", "Hello, Plushie!")
    assert_exists("#preview/btn")
  end

  test "editor has starter code" do
    assert_exists("#editor")
  end

  test "save button exists" do
    assert_exists("#save")
  end

  test "clicking preview button does not crash" do
    click("#preview/btn")
  end
end
