defmodule Notes.AppTest do
  use ExUnit.Case, async: true

  alias Notes.App
  alias Notes.App.Model
  alias Plushie.Event.{Key, Widget}
  alias Plushie.KeyModifiers

  # -- Helpers ----------------------------------------------------------------

  defp app_init, do: App.init(%{})

  defp click(id), do: %Widget{type: :click, id: id}
  defp input(id, value), do: %Widget{type: :input, id: id, value: value}
  defp toggle(id), do: %Widget{type: :toggle, id: id}
  defp select(id, value), do: %Widget{type: :select, id: id, value: value}

  defp key_press(key, modifiers \\ %{}) do
    %Key{type: :press, key: key, modifiers: struct(KeyModifiers, modifiers)}
  end

  defp render_tree(model) do
    App.view(model) |> Plushie.Tree.normalize()
  end

  defp find_node(nil, _target), do: nil
  defp find_node(%{id: target} = node, target), do: node

  defp find_node(%{children: children}, target) do
    Enum.find_value(children, fn child -> find_node(child, target) end)
  end

  defp find_node(_node, _target), do: nil

  defp current_route(model), do: Plushie.Route.current(model.route)
  defp route_params(model), do: Plushie.Route.params(model.route)

  # Note card buttons are scoped: scrollable "note_list" > row "note_<id>_row"
  defp card_btn(note_id), do: "note_list/note_#{note_id}_row/note_#{note_id}"

  # Navigate to editor for the given note
  defp open_editor(model, note_id) do
    App.update(model, click("note_#{note_id}"))
  end

  # -- Init -------------------------------------------------------------------

  describe "init/1" do
    test "returns a Model struct" do
      assert %Model{} = app_init()
    end

    test "starts with seed notes" do
      model = app_init()
      assert length(model.notes) == 3
      assert Enum.any?(model.notes, &(&1.id == "welcome"))
    end

    test "starts on the list route" do
      assert current_route(app_init()) == "/list"
    end

    test "starts with empty selection" do
      model = app_init()
      assert MapSet.size(Plushie.Selection.selected(model.selection)) == 0
    end

    test "starts with no undo state" do
      assert app_init().undo == nil
    end

    test "starts with empty search" do
      assert app_init().search == ""
    end

    test "starts with recent sort" do
      assert app_init().sort_by == :recent
    end
  end

  # -- Navigation -------------------------------------------------------------

  describe "navigation" do
    test "clicking a note opens the editor" do
      model = open_editor(app_init(), "welcome")
      assert current_route(model) == "/editor"
      assert route_params(model)[:note_id] == "welcome"
    end

    test "opening a note initializes undo state" do
      model = open_editor(app_init(), "welcome")
      assert model.undo != nil
      note = Enum.find(model.notes, &(&1.id == "welcome"))
      assert Plushie.Undo.current(model.undo) == note.content
    end

    test "back button returns to list" do
      model =
        app_init()
        |> open_editor("welcome")
        |> App.update(click("back"))

      assert current_route(model) == "/list"
    end

    test "opening a nonexistent note is a no-op" do
      model = open_editor(app_init(), "nonexistent")
      assert current_route(model) == "/list"
    end
  end

  # -- CRUD -------------------------------------------------------------------

  describe "create note" do
    test "adds a new note to the list" do
      model = App.update(app_init(), click("new_note"))
      assert length(model.notes) == 4
    end

    test "new note has 'Untitled' as title" do
      model = App.update(app_init(), click("new_note"))
      new_note = hd(model.notes)
      assert new_note.title == "Untitled"
    end

    test "navigates to editor after creation" do
      model = App.update(app_init(), click("new_note"))
      assert current_route(model) == "/editor"
      assert route_params(model)[:note_id] == hd(model.notes).id
    end

    test "initializes undo for the new note" do
      model = App.update(app_init(), click("new_note"))
      assert model.undo != nil
      assert Plushie.Undo.current(model.undo) == ""
    end
  end

  describe "delete selected" do
    test "removes selected notes" do
      model = app_init()
      model = %{model | selection: Plushie.Selection.toggle(model.selection, "welcome")}
      model = App.update(model, click("delete_selected"))
      refute Enum.any?(model.notes, &(&1.id == "welcome"))
      assert length(model.notes) == 2
    end

    test "clears selection after delete" do
      model = app_init()
      model = %{model | selection: Plushie.Selection.toggle(model.selection, "welcome")}
      model = App.update(model, click("delete_selected"))
      assert MapSet.size(Plushie.Selection.selected(model.selection)) == 0
    end

    test "no-op when nothing is selected" do
      model = app_init()
      updated = App.update(model, click("delete_selected"))
      assert length(updated.notes) == length(model.notes)
    end
  end

  # -- Editor -----------------------------------------------------------------

  describe "editor" do
    test "updating title changes the note" do
      model = open_editor(app_init(), "welcome")
      model = App.update(model, input("editor_title", "New Title"))
      note = Enum.find(model.notes, &(&1.id == "welcome"))
      assert note.title == "New Title"
    end

    test "updating content changes the note and tracks undo" do
      model = open_editor(app_init(), "welcome")
      model = App.update(model, input("editor_content", "New content"))
      note = Enum.find(model.notes, &(&1.id == "welcome"))
      assert note.content == "New content"
      assert Plushie.Undo.can_undo?(model.undo)
    end

    test "title update preserves other notes" do
      model = open_editor(app_init(), "welcome")
      model = App.update(model, input("editor_title", "Changed"))
      shortcuts_note = Enum.find(model.notes, &(&1.id == "shortcuts"))
      assert shortcuts_note.title == "Keyboard shortcuts"
    end
  end

  # -- Undo/Redo --------------------------------------------------------------

  describe "undo/redo" do
    test "undo restores previous content" do
      model = open_editor(app_init(), "welcome")
      original = Enum.find(model.notes, &(&1.id == "welcome")).content

      model = App.update(model, input("editor_content", "Changed"))
      model = App.update(model, click("undo"))

      note = Enum.find(model.notes, &(&1.id == "welcome"))
      assert note.content == original
    end

    test "redo reapplies undone content" do
      model = open_editor(app_init(), "welcome")

      model = App.update(model, input("editor_content", "Changed"))
      model = App.update(model, click("undo"))
      model = App.update(model, click("redo"))

      note = Enum.find(model.notes, &(&1.id == "welcome"))
      assert note.content == "Changed"
    end

    test "undo is a no-op when nothing to undo" do
      model = open_editor(app_init(), "welcome")
      updated = App.update(model, click("undo"))
      assert updated == model
    end

    test "redo is a no-op when nothing to redo" do
      model = open_editor(app_init(), "welcome")
      updated = App.update(model, click("redo"))
      assert updated == model
    end
  end

  # -- Search & Sort ----------------------------------------------------------

  describe "search" do
    test "updates search field" do
      model = App.update(app_init(), input("search", "keyboard"))
      assert model.search == "keyboard"
    end

    test "search filters notes" do
      model = %{app_init() | search: "keyboard"}
      entries = App.filtered_notes(model)
      assert length(entries) == 1
      assert hd(entries).id == "shortcuts"
    end

    test "empty search returns all notes" do
      model = app_init()
      entries = App.filtered_notes(model)
      assert length(entries) == 3
    end
  end

  describe "sort" do
    test "sort by title" do
      model = App.update(app_init(), select("sort", "A-Z"))
      assert model.sort_by == :title
      entries = App.filtered_notes(model)
      titles = Enum.map(entries, & &1.title)
      assert titles == Enum.sort(titles)
    end

    test "sort by oldest" do
      model = App.update(app_init(), select("sort", "Oldest"))
      assert model.sort_by == :oldest
    end

    test "sort by recent (default)" do
      model = App.update(app_init(), select("sort", "Recent"))
      assert model.sort_by == :recent
    end
  end

  # -- Selection --------------------------------------------------------------

  describe "selection" do
    test "toggle selects a note" do
      model = App.update(app_init(), toggle("select_welcome"))
      assert Plushie.Selection.selected?(model.selection, "welcome")
    end

    test "toggle deselects a selected note" do
      model = app_init()
      model = App.update(model, toggle("select_welcome"))
      model = App.update(model, toggle("select_welcome"))
      refute Plushie.Selection.selected?(model.selection, "welcome")
    end

    test "multiple selections accumulate" do
      model =
        app_init()
        |> App.update(toggle("select_welcome"))
        |> App.update(toggle("select_shortcuts"))

      selected = Plushie.Selection.selected(model.selection)
      assert MapSet.size(selected) == 2
    end
  end

  # -- Escape handling --------------------------------------------------------

  describe "escape" do
    test "in editor, navigates back" do
      model =
        app_init()
        |> open_editor("welcome")
        |> App.update(key_press(:escape))

      assert current_route(model) == "/list"
    end

    test "in list with selection, clears selection" do
      model =
        app_init()
        |> App.update(toggle("select_welcome"))
        |> App.update(key_press(:escape))

      assert MapSet.size(Plushie.Selection.selected(model.selection)) == 0
    end

    test "in list with search, clears search" do
      model =
        %{app_init() | search: "hello"}
        |> App.update(key_press(:escape))

      assert model.search == ""
    end

    test "in list with no selection or search, is a no-op" do
      model = app_init()
      assert App.update(model, key_press(:escape)) == model
    end
  end

  # -- Keyboard shortcuts -----------------------------------------------------

  describe "keyboard shortcuts" do
    test "Ctrl+N creates a new note" do
      model = App.update(app_init(), key_press("n", command: true))
      assert length(model.notes) == 4
      assert current_route(model) == "/editor"
    end

    test "Ctrl+Z triggers undo" do
      model =
        app_init()
        |> open_editor("welcome")
        |> App.update(input("editor_content", "Changed"))

      original_content = Enum.find(app_init().notes, &(&1.id == "welcome")).content
      model = App.update(model, key_press("z", command: true))
      note = Enum.find(model.notes, &(&1.id == "welcome"))
      assert note.content == original_content
    end

    test "Ctrl+Y triggers redo" do
      model =
        app_init()
        |> open_editor("welcome")
        |> App.update(input("editor_content", "Changed"))
        |> App.update(key_press("z", command: true))
        |> App.update(key_press("y", command: true))

      note = Enum.find(model.notes, &(&1.id == "welcome"))
      assert note.content == "Changed"
    end
  end

  # -- Unknown events ---------------------------------------------------------

  describe "unknown events" do
    test "returns model unchanged" do
      model = app_init()
      assert App.update(model, click("nonexistent")) == model
    end
  end

  # -- Subscribe --------------------------------------------------------------

  describe "subscribe/1" do
    test "subscribes to key press events" do
      subs = App.subscribe(app_init())
      assert length(subs) == 1
      assert hd(subs).type == :on_key_press
    end
  end

  # -- View: list -------------------------------------------------------------

  describe "view list" do
    test "root is a window" do
      tree = render_tree(app_init())
      assert tree.type == "window"
      assert tree.id == "main"
    end

    test "contains toolbar with title" do
      tree = render_tree(app_init())
      node = find_node(tree, "toolbar_title")
      assert node != nil
      assert node.props[:content] == "Plushie Notes"
    end

    test "contains search input" do
      tree = render_tree(app_init())
      assert find_node(tree, "search") != nil
    end

    test "contains sort picker" do
      tree = render_tree(app_init())
      assert find_node(tree, "sort") != nil
    end

    test "contains new note button" do
      tree = render_tree(app_init())
      assert find_node(tree, "new_note") != nil
    end

    test "renders note cards for seed data" do
      tree = render_tree(app_init())
      # Note cards are inside scrollable "note_list" > row "note_<id>_row",
      # which creates a two-level scope for each card's children.
      assert find_node(tree, card_btn("welcome")) != nil
      assert find_node(tree, card_btn("shortcuts")) != nil
      assert find_node(tree, card_btn("widgets")) != nil
    end

    test "contains shortcut bar" do
      tree = render_tree(app_init())
      # Shortcut hints are scoped: shortcuts_h0/shortcuts_key_0
      assert find_node(tree, "shortcuts_h0/shortcuts_key_0") != nil
    end

    test "delete button appears when items selected" do
      model = App.update(app_init(), toggle("select_welcome"))
      tree = render_tree(model)
      assert find_node(tree, "delete_selected") != nil
    end

    test "delete button hidden when nothing selected" do
      tree = render_tree(app_init())
      assert find_node(tree, "delete_selected") == nil
    end
  end

  # -- View: editor -----------------------------------------------------------

  describe "view editor" do
    test "shows back button" do
      model = open_editor(app_init(), "welcome")
      tree = render_tree(model)
      assert find_node(tree, "back") != nil
    end

    test "shows title input with note title" do
      model = open_editor(app_init(), "welcome")
      tree = render_tree(model)
      node = find_node(tree, "editor_title")
      assert node != nil
      assert node.props[:value] == "Welcome to Plushie Notes"
    end

    test "shows content input with note content" do
      model = open_editor(app_init(), "welcome")
      tree = render_tree(model)
      node = find_node(tree, "editor_content")
      assert node != nil
    end

    test "shows shortcut hints" do
      model = open_editor(app_init(), "welcome")
      tree = render_tree(model)
      # "Esc back" should always be present in editor
      assert find_node(tree, "shortcuts_h0/shortcuts_key_0") != nil
      assert find_node(tree, "shortcuts_h0/shortcuts_act_0") != nil
    end

    test "undo button shown when undo is available" do
      model =
        app_init()
        |> open_editor("welcome")
        |> App.update(input("editor_content", "changed"))

      tree = render_tree(model)
      assert find_node(tree, "undo") != nil
    end

    test "undo button hidden when nothing to undo" do
      model = open_editor(app_init(), "welcome")
      tree = render_tree(model)
      assert find_node(tree, "undo") == nil
    end

    test "missing note shows not found" do
      # Manually push a route to a nonexistent note
      model = %{
        app_init()
        | route: Plushie.Route.push(Plushie.Route.new("/list"), "/editor", %{note_id: "gone"})
      }

      tree = render_tree(model)
      assert find_node(tree, "missing") != nil
    end
  end
end
