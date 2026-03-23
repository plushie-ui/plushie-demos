defmodule Notes.Widgets.ToolbarTest do
  use ExUnit.Case, async: true

  alias Notes.Widgets.Toolbar

  test "type_names" do
    assert Toolbar.type_names() == [:toolbar]
  end

  test "renders with title" do
    node = Toolbar.new("tb", title: "Hello")
    assert is_map(node)
  end
end
