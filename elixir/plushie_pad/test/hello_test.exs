defmodule PlushiePad.HelloTest do
  use Plushie.Test.Case, app: PlushiePad.Hello

  # Ch 2: first test
  test "clicking + increments the count" do
    click("#increment")
    assert_text("#count", "Count: 1")
  end
end
