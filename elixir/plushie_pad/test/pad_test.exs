defmodule PlushiePad.PadTest do
  use Plushie.Test.Case, app: PlushiePad

  @moduletag capture_log: true

  @experiments_dir "priv/experiments"

  setup do
    # Clean up experiment files between tests to ensure isolation.
    on_exit(fn ->
      File.mkdir_p!(@experiments_dir)

      @experiments_dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".ex"))
      |> Enum.each(&File.rm!(Path.join(@experiments_dir, &1)))
    end)

    :ok
  end

  describe "initial state" do
    test "starter code compiles and renders a preview" do
      m = model()
      assert m.preview != nil
      assert m.error == nil
    end

    test "preview shows the starter code output" do
      assert_exists("#preview/greeting")
      assert_text("#preview/greeting", "Hello, Plushie!")
      assert_exists("#preview/btn")
    end

    test "event log starts empty" do
      assert model().event_log == []
    end

    test "editor and sidebar are present" do
      assert_exists("#editor")
      assert_exists("#sidebar-wrap")
    end

    test "toolbar controls exist" do
      assert_exists("#new-name")
      assert_exists("#auto-save")
      assert_exists("#import")
      assert_exists("#export")
      assert_exists("#copy")
      assert_exists("#detach")
      assert_exists("#show-browser")
    end

    test "dirty flag starts false" do
      refute model().dirty
    end

    test "detached starts false" do
      refute model().detached
    end

    test "route starts at editor" do
      assert Plushie.Route.current(model().route) == :editor
    end
  end

  describe "file management" do
    test "creating a new experiment" do
      type_text("#new-name", "demo.ex")
      submit("#new-name")

      m = model()
      assert m.active_file == "demo.ex"
      assert "demo.ex" in m.files
      assert m.new_name == ""
    end

    test "creating an experiment with invalid name is a no-op" do
      type_text("#new-name", "no-extension")
      submit("#new-name")

      assert model().active_file == nil
    end

    test "creating an experiment with blank name is a no-op" do
      type_text("#new-name", "   ")
      submit("#new-name")

      assert model().active_file == nil
    end

    test "switching between files" do
      type_text("#new-name", "alpha.ex")
      submit("#new-name")
      type_text("#new-name", "beta.ex")
      submit("#new-name")
      assert model().active_file == "beta.ex"

      click("#sidebar-wrap/sidebar/file-scroll/alpha.ex/select")
      assert model().active_file == "alpha.ex"
    end

    test "deleting a file" do
      type_text("#new-name", "doomed.ex")
      submit("#new-name")
      assert "doomed.ex" in model().files

      click("#sidebar-wrap/sidebar/file-scroll/doomed.ex/delete")
      refute "doomed.ex" in model().files
    end

    test "deleting the active file loads the next available" do
      type_text("#new-name", "first.ex")
      submit("#new-name")
      type_text("#new-name", "second.ex")
      submit("#new-name")

      click("#sidebar-wrap/sidebar/file-scroll/second.ex/select")
      assert model().active_file == "second.ex"

      click("#sidebar-wrap/sidebar/file-scroll/second.ex/delete")
      assert model().active_file == "first.ex"
    end

    test "deleting the last file resets to starter code" do
      type_text("#new-name", "only.ex")
      submit("#new-name")

      click("#sidebar-wrap/sidebar/file-scroll/only.ex/delete")
      m = model()
      assert m.active_file == nil
      assert m.files == []
      assert String.contains?(m.source, "Hello, Plushie!")
    end
  end

  describe "editing" do
    test "typing in editor sets the dirty flag" do
      refute model().dirty
      type_text("#editor", "new content")
      assert model().dirty
    end

    test "editing updates the source" do
      type_text("#editor", "replaced source")
      assert model().source == "replaced source"
    end
  end

  describe "escape key" do
    test "escape clears nil error gracefully" do
      # No error set -- escape is a no-op
      type_key("escape")
      assert model().error == nil
    end
  end

  describe "auto-save" do
    test "toggling auto-save on and off" do
      refute model().auto_save
      toggle("#auto-save")
      assert model().auto_save
      toggle("#auto-save")
      refute model().auto_save
    end
  end

  describe "event logging" do
    test "unhandled events appear in the log" do
      # Clicking the preview button generates a WidgetEvent that
      # falls through to the catch-all update clause.
      click("#preview/btn")
      assert length(model().event_log) > 0
    end

    test "log caps at 20 entries" do
      for _ <- 1..25 do
        click("#preview/btn")
      end

      assert length(model().event_log) == 20
    end
  end

  describe "undo and redo" do
    test "undo stack is initialized with starter code" do
      assert Plushie.Undo.can_undo?(model().undo) == false
      assert Plushie.Undo.can_redo?(model().undo) == false
    end

    test "editing creates an undo entry" do
      type_text("#editor", "changed")
      assert Plushie.Undo.can_undo?(model().undo)
    end
  end

  describe "detach preview" do
    test "detach button sets detached true" do
      click("#detach")
      assert model().detached
    end
  end

  describe "search" do
    test "typing in search updates the query" do
      type_text("#new-name", "apple.ex")
      submit("#new-name")
      type_text("#new-name", "banana.ex")
      submit("#new-name")

      type_text("#sidebar-wrap/sidebar/search", "apple")
      assert model().search_query == "apple"
    end
  end

  describe "selection" do
    test "toggling a file checkbox selects it" do
      type_text("#new-name", "sel.ex")
      submit("#new-name")

      toggle("#sidebar-wrap/sidebar/file-scroll/sel.ex/file-select")
      assert Plushie.Selection.selected?(model().selection, "sel.ex")
    end

    test "delete-selected removes selected files and clears selection" do
      type_text("#new-name", "keep.ex")
      submit("#new-name")
      type_text("#new-name", "remove.ex")
      submit("#new-name")

      toggle("#sidebar-wrap/sidebar/file-scroll/remove.ex/file-select")
      click("#delete-selected")

      m = model()
      refute "remove.ex" in m.files
      assert "keep.ex" in m.files
      assert Plushie.Selection.selected(m.selection) == MapSet.new()
    end
  end

  describe "routing" do
    test "browse button switches to browser view" do
      click("#show-browser")
      assert Plushie.Route.current(model().route) == :browser
    end

    test "back button returns to editor view" do
      click("#show-browser")
      click("#back-to-editor")
      assert Plushie.Route.current(model().route) == :editor
    end

    test "browser view shows title and back button" do
      click("#show-browser")
      assert_text("#browser-title", "All Experiments")
      assert_exists("#back-to-editor")
    end
  end

  describe "new experiment name input" do
    test "typing updates the new_name field" do
      type_text("#new-name", "hello.ex")
      assert model().new_name == "hello.ex"
    end

    test "submitting clears the input on success" do
      type_text("#new-name", "test.ex")
      submit("#new-name")
      assert model().new_name == ""
    end

    test "submitting an invalid name keeps the input" do
      type_text("#new-name", "bad-name")
      submit("#new-name")
      # Model doesn't change -- new_name stays as-is since the handler
      # returns the model unmodified for invalid names.
      assert model().new_name == "bad-name"
    end
  end
end
