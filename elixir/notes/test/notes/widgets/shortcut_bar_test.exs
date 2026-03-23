defmodule Notes.Widgets.ShortcutBarTest do
  use ExUnit.Case, async: true

  alias Notes.Widgets.ShortcutBar

  test "type_names" do
    assert ShortcutBar.type_names() == [:shortcut_bar]
  end

  test "renders with hints" do
    node = ShortcutBar.new("sb", hints: [{"Ctrl+N", "new"}])
    assert is_map(node)
  end
end
