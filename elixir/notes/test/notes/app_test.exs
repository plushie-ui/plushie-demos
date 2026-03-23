defmodule Notes.AppTest do
  use Plushie.Test.Case, app: Notes.App

  # -- Init -------------------------------------------------------------------

  test "starts with seed notes" do
    assert length(model().notes) == 3
  end

  test "starts on list route" do
    assert Plushie.Route.current(model().route) == "/list"
  end

  test "starts with empty search" do
    assert model().search == ""
  end

  # -- List view structure ----------------------------------------------------

  test "has toolbar title" do
    assert_exists("#toolbar_title")
  end

  test "has search input" do
    assert_exists("#search")
  end

  test "has sort picker" do
    assert_exists("#sort")
  end

  test "has new note button" do
    assert_exists("#new_note")
  end

  test "has shortcut bar" do
    assert_exists("#shortcuts_h0/shortcuts_key_0")
  end

  # -- Navigation -------------------------------------------------------------

  test "clicking a note opens the editor" do
    click("Welcome to Plushie Notes")
    assert Plushie.Route.current(model().route) == "/editor"
  end

  test "back button returns to list" do
    click("Welcome to Plushie Notes")
    click("#back")
    assert Plushie.Route.current(model().route) == "/list"
  end

  # -- CRUD -------------------------------------------------------------------

  test "new note creates a note and opens editor" do
    click("#new_note")
    assert length(model().notes) == 4
    assert Plushie.Route.current(model().route) == "/editor"
  end

  test "delete selected removes notes" do
    toggle("#select_welcome")
    click("#delete_selected")
    refute Enum.any?(model().notes, &(&1.id == "welcome"))
    assert length(model().notes) == 2
  end

  test "delete button hidden when nothing selected" do
    assert_not_exists("#delete_selected")
  end

  test "delete button appears when items selected" do
    toggle("#select_welcome")
    assert_exists("#delete_selected")
  end

  # -- Editor -----------------------------------------------------------------

  test "editor shows title input" do
    click("Welcome to Plushie Notes")
    assert_exists("#editor_title")
  end

  test "editor shows content input" do
    click("Welcome to Plushie Notes")
    assert_exists("#editor_content")
  end

  test "editor shows back button" do
    click("Welcome to Plushie Notes")
    assert_exists("#back")
  end

  test "updating title changes the note" do
    click("Welcome to Plushie Notes")
    type_text("#editor_title", "New Title")
    note = Enum.find(model().notes, &(&1.id == "welcome"))
    assert note.title == "New Title"
  end

  test "editing content tracks undo" do
    click("Welcome to Plushie Notes")
    type_text("#editor_content", "New content")
    assert Plushie.Undo.can_undo?(model().undo)
  end

  # -- Undo/Redo --------------------------------------------------------------

  test "undo restores previous content" do
    click("Welcome to Plushie Notes")
    original = Enum.find(model().notes, &(&1.id == "welcome")).content
    type_text("#editor_content", "Changed")
    click("#undo")
    note = Enum.find(model().notes, &(&1.id == "welcome"))
    assert note.content == original
  end

  test "redo reapplies undone content" do
    click("Welcome to Plushie Notes")
    type_text("#editor_content", "Changed")
    click("#undo")
    click("#redo")
    note = Enum.find(model().notes, &(&1.id == "welcome"))
    assert note.content == "Changed"
  end

  # -- Selection --------------------------------------------------------------

  test "toggle selects a note" do
    toggle("#select_welcome")
    assert Plushie.Selection.selected?(model().selection, "welcome")
  end

  test "toggle deselects a selected note" do
    toggle("#select_welcome")
    toggle("#select_welcome")
    refute Plushie.Selection.selected?(model().selection, "welcome")
  end

  # -- Sort -------------------------------------------------------------------

  test "sort by title" do
    select("#sort", "A-Z")
    assert model().sort_by == :title
  end

  # -- Subscribe --------------------------------------------------------------

  test "subscribes to key press events" do
    subs = Notes.App.subscribe(model())
    assert length(subs) == 1
    assert hd(subs).type == :on_key_press
  end

  # -- Settings ---------------------------------------------------------------

  # Notes app has no settings callback (uses defaults)
end
