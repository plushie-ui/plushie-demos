defmodule CollabTest do
  use ExUnit.Case, async: true

  alias Collab.Model
  alias Plushie.Event.Widget

  # -- Helpers ----------------------------------------------------------------

  defp app_init, do: Collab.init(%{})

  defp click(id), do: %Widget{type: :click, id: id}
  defp input(id, value), do: %Widget{type: :input, id: id, value: value}
  defp toggle(id, value), do: %Widget{type: :toggle, id: id, value: value}

  defp render_tree(model) do
    Collab.view(model) |> Plushie.Tree.normalize()
  end

  defp find_node(nil, _target), do: nil
  defp find_node(%{id: target} = node, target), do: node

  defp find_node(%{children: children}, target) do
    Enum.find_value(children, fn child -> find_node(child, target) end)
  end

  defp find_node(_node, _target), do: nil

  # The view nests widgets inside named containers that scope IDs:
  #   window "main" (no scope) > themer "theme-root" > container "bg" > ...
  # Counter widgets are additionally scoped by row "counter-row".
  defp scoped(id), do: "theme-root/bg/#{id}"
  defp counter_scoped(id), do: "theme-root/bg/counter-row/#{id}"

  # -- Init -------------------------------------------------------------------

  describe "init/1" do
    test "name defaults to empty string" do
      assert app_init().name == ""
    end

    test "notes defaults to empty string" do
      assert app_init().notes == ""
    end

    test "count defaults to 0" do
      assert app_init().count == 0
    end

    test "dark_mode defaults to false" do
      assert app_init().dark_mode == false
    end

    test "status defaults to empty string" do
      assert app_init().status == ""
    end

    test "returns a Model struct" do
      assert %Model{} = app_init()
    end
  end

  # -- Update: counter --------------------------------------------------------

  describe "update/2 counter" do
    test "increment increases count" do
      model = Collab.update(app_init(), click("inc"))
      assert model.count == 1
    end

    test "decrement decreases count" do
      model = Collab.update(app_init(), click("dec"))
      assert model.count == -1
    end

    test "multiple increments accumulate" do
      model =
        app_init()
        |> Collab.update(click("inc"))
        |> Collab.update(click("inc"))
        |> Collab.update(click("inc"))

      assert model.count == 3
    end

    test "increment then decrement returns to zero" do
      model =
        app_init()
        |> Collab.update(click("inc"))
        |> Collab.update(click("dec"))

      assert model.count == 0
    end
  end

  # -- Update: text inputs ----------------------------------------------------

  describe "update/2 text inputs" do
    test "name input updates name" do
      model = Collab.update(app_init(), input("name", "Alice"))
      assert model.name == "Alice"
    end

    test "notes input updates notes" do
      model = Collab.update(app_init(), input("notes", "meeting at 3pm"))
      assert model.notes == "meeting at 3pm"
    end

    test "name input replaces previous value" do
      model =
        app_init()
        |> Collab.update(input("name", "Alice"))
        |> Collab.update(input("name", "Bob"))

      assert model.name == "Bob"
    end
  end

  # -- Update: dark mode toggle -----------------------------------------------

  describe "update/2 dark mode" do
    test "toggle on sets dark_mode to true" do
      model = Collab.update(app_init(), toggle("theme", true))
      assert model.dark_mode == true
    end

    test "toggle off sets dark_mode to false" do
      model =
        %{app_init() | dark_mode: true}
        |> Collab.update(toggle("theme", false))

      assert model.dark_mode == false
    end
  end

  # -- Update: field isolation ------------------------------------------------

  describe "update/2 field isolation" do
    test "incrementing preserves name and notes" do
      model = %{app_init() | name: "Alice", notes: "hello"}
      updated = Collab.update(model, click("inc"))
      assert updated.name == "Alice"
      assert updated.notes == "hello"
      assert updated.count == 1
    end

    test "updating name preserves count" do
      model = %{app_init() | count: 5}
      updated = Collab.update(model, input("name", "Bob"))
      assert updated.count == 5
      assert updated.name == "Bob"
    end

    test "toggling dark_mode preserves count and name" do
      model = %{app_init() | count: 3, name: "Alice"}
      updated = Collab.update(model, toggle("theme", true))
      assert updated.count == 3
      assert updated.name == "Alice"
      assert updated.dark_mode == true
    end

    test "updating notes preserves all other fields" do
      model = %{app_init() | name: "Alice", count: 7, dark_mode: true, status: "2 connected"}
      updated = Collab.update(model, input("notes", "new note"))
      assert updated.name == "Alice"
      assert updated.count == 7
      assert updated.dark_mode == true
      assert updated.status == "2 connected"
      assert updated.notes == "new note"
    end
  end

  # -- Update: unknown events -------------------------------------------------

  describe "update/2 unknown events" do
    test "returns model unchanged for unknown click" do
      model = app_init()
      assert Collab.update(model, click("nonexistent")) == model
    end

    test "returns model unchanged for unrelated event" do
      model = app_init()
      event = %Widget{type: :select, id: "something", value: "x"}
      assert Collab.update(model, event) == model
    end
  end

  # -- View tree structure ----------------------------------------------------

  describe "view/1 tree structure" do
    test "root is a window" do
      tree = render_tree(app_init())
      assert tree.type == "window"
      assert tree.id == "main"
    end

    test "contains header text" do
      tree = render_tree(app_init())
      node = find_node(tree, scoped("header"))
      assert node != nil
      assert node.props[:content] == "Plushie Demo"
    end

    test "contains name input" do
      tree = render_tree(app_init())
      node = find_node(tree, scoped("name"))
      assert node != nil
      assert node.type == "text_input"
    end

    test "contains counter widgets" do
      tree = render_tree(app_init())
      assert find_node(tree, counter_scoped("dec")) != nil
      assert find_node(tree, counter_scoped("count")) != nil
      assert find_node(tree, counter_scoped("inc")) != nil
    end

    test "contains theme checkbox" do
      tree = render_tree(app_init())
      assert find_node(tree, scoped("theme")) != nil
    end

    test "contains notes input" do
      tree = render_tree(app_init())
      node = find_node(tree, scoped("notes"))
      assert node != nil
      assert node.type == "text_input"
    end

    test "count text reflects model" do
      model = %{app_init() | count: 42}
      tree = render_tree(model)
      node = find_node(tree, counter_scoped("count"))
      assert node.props[:content] == "Count: 42"
    end

    test "status text shown when set" do
      model = %{app_init() | status: "3 connected"}
      tree = render_tree(model)
      node = find_node(tree, scoped("status"))
      assert node != nil
      assert node.props[:content] == "3 connected"
    end

    test "status text empty when not set" do
      tree = render_tree(app_init())
      node = find_node(tree, scoped("status"))
      assert node != nil
      assert node.props[:content] == ""
    end

    test "name input reflects model value" do
      model = %{app_init() | name: "Alice"}
      tree = render_tree(model)
      node = find_node(tree, scoped("name"))
      assert node.props[:value] == "Alice"
    end
  end

  # -- Settings ---------------------------------------------------------------

  describe "settings/0" do
    test "has default_event_rate" do
      settings = Collab.settings()
      assert Keyword.get(settings, :default_event_rate) == 30
    end
  end
end
