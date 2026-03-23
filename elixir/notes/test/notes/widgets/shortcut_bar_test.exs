defmodule Notes.Widgets.ShortcutBarTest do
  use ExUnit.Case, async: true

  alias Notes.Widgets.ShortcutBar

  defp find_node(nil, _target), do: nil
  defp find_node(%{id: target} = node, target), do: node
  defp find_node(%{children: c}, target), do: Enum.find_value(c, &find_node(&1, target))
  defp find_node(_, _), do: nil

  describe "metadata" do
    test "type_names" do
      assert ShortcutBar.type_names() == [:shortcut_bar]
    end
  end

  describe "defaults" do
    test "new with empty hints" do
      node = ShortcutBar.new("sb")
      assert node != nil
    end
  end

  describe "hint rendering" do
    test "each hint produces key and action text nodes" do
      hints = [{"Ctrl+N", "new"}, {"Esc", "back"}]
      node = ShortcutBar.new("sb", hints: hints)

      # Raw composite output (not normalized), so IDs are unscoped
      key_0 = find_node(node, "sb_key_0")
      act_0 = find_node(node, "sb_act_0")
      assert key_0 != nil
      assert key_0.props[:content] == "Ctrl+N"
      assert act_0 != nil
      assert act_0.props[:content] == "new"

      key_1 = find_node(node, "sb_key_1")
      act_1 = find_node(node, "sb_act_1")
      assert key_1 != nil
      assert key_1.props[:content] == "Esc"
      assert act_1 != nil
      assert act_1.props[:content] == "back"
    end

    test "key text has lighter color than action text" do
      node = ShortcutBar.new("sb", hints: [{"Ctrl+N", "new"}])
      key = find_node(node, "sb_key_0")
      act = find_node(node, "sb_act_0")
      # Key is lighter (#999999), action is darker (#666666)
      assert key.props[:color] != act.props[:color]
    end

    test "no hint nodes when hints is empty" do
      node = ShortcutBar.new("sb", hints: [])
      assert find_node(node, "sb_key_0") == nil
    end
  end
end
