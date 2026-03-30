defmodule PlushiePad.PadTest do
  use Plushie.Test.Case, app: PlushiePad

  test "shows placeholder in preview" do
    assert_text("#preview/placeholder", "Press Save to compile and preview")
  end

  test "editor exists with content" do
    assert_exists("#editor")
  end

  test "save button exists" do
    assert_exists("#save")
  end
end
