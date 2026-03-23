defmodule Notes.Widgets.NoteCardTest do
  use ExUnit.Case, async: true

  alias Notes.Widgets.NoteCard

  defp find_node(nil, _target), do: nil
  defp find_node(%{id: target} = node, target), do: node
  defp find_node(%{children: c}, target), do: Enum.find_value(c, &find_node(&1, target))
  defp find_node(_, _), do: nil

  describe "metadata" do
    test "type_names" do
      assert NoteCard.type_names() == [:note_card]
    end

    test "not a native widget" do
      refute function_exported?(NoteCard, :native_crate, 0)
    end
  end

  describe "defaults" do
    test "new with defaults" do
      node = NoteCard.new("note_abc")
      assert node != nil
    end

    test "default props" do
      card = NoteCard.new("note_abc")
      # Composite widget -- new returns the rendered tree, not a struct
      assert is_map(card)
    end
  end

  describe "build output" do
    test "contains selection checkbox" do
      node = NoteCard.new("note_abc", selected: true)
      cb = find_node(node, "select_abc")
      assert cb != nil
      assert cb.type == "checkbox"
    end

    test "checkbox reflects selected state" do
      node_off = NoteCard.new("note_abc", selected: false)
      cb_off = find_node(node_off, "select_abc")
      assert cb_off.props[:checked] == false

      node_on = NoteCard.new("note_abc", selected: true)
      cb_on = find_node(node_on, "select_abc")
      assert cb_on.props[:checked] == true
    end

    test "contains title button for opening" do
      node = NoteCard.new("note_abc", title: "My Note")
      btn = find_node(node, "note_abc")
      assert btn != nil
      assert btn.type == "button"
    end

    test "contains preview text when present" do
      node = NoteCard.new("note_abc", preview: "Some content...")
      preview = find_node(node, "note_abc_preview")
      assert preview != nil
      assert preview.props[:content] == "Some content..."
    end

    test "omits preview when empty" do
      node = NoteCard.new("note_abc", preview: "")
      assert find_node(node, "note_abc_preview") == nil
    end

    test "contains timestamp when present" do
      node = NoteCard.new("note_abc", timestamp: "Mar 23, 10:00")
      time = find_node(node, "note_abc_time")
      assert time != nil
      assert time.props[:content] == "Mar 23, 10:00"
    end

    test "omits timestamp when empty" do
      node = NoteCard.new("note_abc", timestamp: "")
      assert find_node(node, "note_abc_time") == nil
    end
  end
end
