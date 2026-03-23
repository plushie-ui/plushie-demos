defmodule Notes.Widgets.NoteCardTest do
  use ExUnit.Case, async: true

  alias Notes.Widgets.NoteCard

  test "type_names" do
    assert NoteCard.type_names() == [:note_card]
  end

  test "renders with defaults" do
    node = NoteCard.new("note_abc")
    assert is_map(node)
  end
end
