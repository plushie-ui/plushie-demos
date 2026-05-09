defmodule PlushiePad.HelloTest do
  use Plushie.Test.Case, app: PlushiePad.Hello

  @moduletag capture_log: true

  describe "initial state" do
    test "count starts at zero" do
      assert model().count == 0
      assert_text("#count", "Count: 0")
    end

    test "buttons are present" do
      assert_exists("#increment")
      assert_exists("#decrement")
    end
  end

  describe "increment and decrement" do
    test "clicking + increments the count" do
      click("#increment")
      assert model().count == 1
      assert_text("#count", "Count: 1")
    end

    test "clicking - decrements the count" do
      click("#decrement")
      assert model().count == -1
      assert_text("#count", "Count: -1")
    end

    test "multiple clicks accumulate" do
      click("#increment")
      click("#increment")
      click("#increment")
      click("#decrement")
      assert model().count == 2
      assert_text("#count", "Count: 2")
    end
  end
end
