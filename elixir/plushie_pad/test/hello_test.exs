defmodule PlushiePad.HelloTest do
  use Plushie.Test.Case, app: PlushiePad.Hello

  test "starts at zero" do
    assert_text("#count", "Count: 0")
  end

  test "increment increases count" do
    click("#increment")
    click("#increment")
    assert_text("#count", "Count: 2")
  end

  test "decrement decreases count" do
    click("#decrement")
    assert_text("#count", "Count: -1")
  end
end
