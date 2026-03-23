defmodule Notes.NoteTest do
  use ExUnit.Case, async: true

  alias Notes.Note

  test "struct creation with all fields" do
    now = DateTime.utc_now()
    note = %Note{id: "abc", title: "Hello", content: "World", updated_at: now}
    assert note.id == "abc"
    assert note.title == "Hello"
    assert note.content == "World"
    assert note.updated_at == now
  end

  test "to_map/1 returns a plain map" do
    now = DateTime.utc_now()
    note = %Note{id: "abc", title: "Hello", content: "World", updated_at: now}
    map = Note.to_map(note)
    assert map == %{id: "abc", title: "Hello", content: "World", updated_at: now}
    refute is_struct(map)
  end

  test "enforce_keys rejects missing fields" do
    assert_raise ArgumentError, fn ->
      struct!(Note, id: "x", title: "y")
    end
  end
end
