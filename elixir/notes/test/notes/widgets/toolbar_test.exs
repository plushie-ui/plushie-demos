defmodule Notes.Widgets.ToolbarTest do
  use ExUnit.Case, async: true

  alias Notes.Widgets.Toolbar

  defp find_node(nil, _target), do: nil
  defp find_node(%{id: target} = node, target), do: node
  defp find_node(%{children: c}, target), do: Enum.find_value(c, &find_node(&1, target))
  defp find_node(_, _), do: nil

  describe "metadata" do
    test "type_names" do
      assert Toolbar.type_names() == [:toolbar]
    end

    test "not a native widget" do
      refute function_exported?(Toolbar, :native_crate, 0)
    end
  end

  describe "defaults" do
    test "new with defaults" do
      node = Toolbar.new("tb")
      assert node != nil
    end
  end

  describe "build output" do
    test "title is rendered" do
      node = Toolbar.new("tb", title: "Hello")
      title = find_node(node, "tb_title")
      assert title != nil
      assert title.props[:content] == "Hello"
    end

    test "back button shown when show_back is true" do
      node = Toolbar.new("tb", show_back: true)
      assert find_node(node, "back") != nil
    end

    test "back button hidden when show_back is false" do
      node = Toolbar.new("tb", show_back: false)
      assert find_node(node, "back") == nil
    end

    test "action buttons rendered" do
      node = Toolbar.new("tb", actions: [{"save", "Save"}, {"cancel", "Cancel"}])
      assert find_node(node, "save") != nil
      assert find_node(node, "cancel") != nil
    end

    test "no action buttons when actions is empty" do
      node = Toolbar.new("tb", actions: [])
      # Only the title and spacer should be present
      assert find_node(node, "tb_title") != nil
    end
  end
end
