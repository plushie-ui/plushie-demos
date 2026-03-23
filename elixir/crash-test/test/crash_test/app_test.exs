defmodule CrashTest.AppTest do
  use ExUnit.Case, async: true

  alias CrashTest.App
  alias CrashTest.App.Model
  alias Plushie.Event.Widget

  # -- Helpers ----------------------------------------------------------------

  defp app_init, do: App.init(%{})

  defp click(id), do: %Widget{type: :click, id: id}

  defp render_tree(model) do
    App.view(model) |> Plushie.Tree.normalize()
  end

  defp find_node(nil, _target), do: nil
  defp find_node(%{id: target} = node, target), do: node

  defp find_node(%{children: children}, target) do
    Enum.find_value(children, fn child -> find_node(child, target) end)
  end

  defp find_node(_node, _target), do: nil

  # -- Init -------------------------------------------------------------------

  describe "init/1" do
    test "returns a Model struct" do
      assert %Model{} = app_init()
    end

    test "count starts at zero" do
      assert app_init().count == 0
    end

    test "crash_view starts false" do
      assert app_init().crash_view == false
    end
  end

  # -- Counter (proof of life) ------------------------------------------------

  describe "counter" do
    test "increment" do
      model = App.update(app_init(), click("inc"))
      assert model.count == 1
    end

    test "decrement" do
      model = App.update(app_init(), click("dec"))
      assert model.count == -1
    end

    test "multiple increments accumulate" do
      model =
        app_init()
        |> App.update(click("inc"))
        |> App.update(click("inc"))
        |> App.update(click("inc"))

      assert model.count == 3
    end
  end

  # -- Crash: update/2 -------------------------------------------------------

  describe "crash update/2" do
    test "raises RuntimeError" do
      assert_raise RuntimeError, ~r/Deliberate crash in update/, fn ->
        App.update(app_init(), click("crash_update"))
      end
    end

    test "counter works independently of update crash" do
      # The runtime would roll back the model on crash. In unit tests
      # we verify the counter handler is unaffected.
      model = app_init()
      model = App.update(model, click("inc"))
      assert model.count == 1

      assert_raise RuntimeError, fn ->
        App.update(model, click("crash_update"))
      end

      # The model we have is still count: 1
      model = App.update(model, click("inc"))
      assert model.count == 2
    end
  end

  # -- Crash: view/1 ----------------------------------------------------------

  describe "crash view/1" do
    test "crash_view button sets the flag" do
      model = App.update(app_init(), click("crash_view"))
      assert model.crash_view == true
    end

    test "view raises when crash_view is true" do
      model = %{app_init() | crash_view: true}

      assert_raise RuntimeError, ~r/Deliberate crash in view/, fn ->
        App.view(model)
      end
    end

    test "view works when crash_view is false" do
      tree = render_tree(app_init())
      assert tree.type == "window"
    end
  end

  # -- Crash: Rust extension --------------------------------------------------

  describe "panic extension" do
    test "produces extension_command" do
      {model, cmd} = App.update(app_init(), click("panic_widget"))
      assert cmd.type == :extension_command
      assert cmd.payload.op == "panic"
      assert cmd.payload.node_id == "crash_ext"
      # Model is unchanged
      assert model.count == 0
    end
  end

  # -- Unknown events ---------------------------------------------------------

  describe "unknown events" do
    test "returns model unchanged" do
      model = app_init()
      assert App.update(model, click("nonexistent")) == model
    end
  end

  # -- View tree structure ----------------------------------------------------

  describe "view/1 tree structure" do
    test "root is a window" do
      tree = render_tree(app_init())
      assert tree.type == "window"
      assert tree.id == "main"
    end

    test "has title" do
      tree = render_tree(app_init())
      node = find_node(tree, "title")
      assert node != nil
      assert node.props[:content] == "Crash Test"
    end

    test "has counter widgets" do
      tree = render_tree(app_init())
      assert find_node(tree, "count") != nil
      assert find_node(tree, "inc") != nil
      assert find_node(tree, "dec") != nil
    end

    test "count reflects model" do
      model = %{app_init() | count: 42}
      tree = render_tree(model)
      node = find_node(tree, "count")
      assert node.props[:content] == "Count: 42"
    end

    test "has crash buttons" do
      tree = render_tree(app_init())
      assert find_node(tree, "crash_update") != nil
      assert find_node(tree, "crash_view") != nil
      assert find_node(tree, "panic_widget") != nil
    end

    test "has description texts" do
      tree = render_tree(app_init())
      assert find_node(tree, "crash_update_desc") != nil
      assert find_node(tree, "crash_view_desc") != nil
      assert find_node(tree, "panic_desc") != nil
    end

    test "has crash extension widget" do
      tree = render_tree(app_init())
      node = find_node(tree, "crash_ext")
      assert node != nil
      assert node.type == "crash_widget"
    end

    test "crash extension has label prop" do
      tree = render_tree(app_init())
      node = find_node(tree, "crash_ext")
      assert node.props[:label] == "Widget OK"
    end
  end
end
