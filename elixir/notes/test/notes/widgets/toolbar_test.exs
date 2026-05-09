defmodule Notes.Widgets.ToolbarTest do
  use Plushie.Test.WidgetCase, widget: Notes.Widgets.Toolbar

  describe "title only (defaults)" do
    setup do
      init_widget("tb", title: "My Notes")
    end

    test "title text is rendered" do
      assert_text("#tb_title", "My Notes")
    end

    test "back button is absent by default" do
      assert_not_exists("#back")
    end

    test "no action buttons when none provided" do
      assert_not_exists("#new_note")
      assert_not_exists("#delete_selected")
    end
  end

  describe "with back button" do
    setup do
      init_widget("tb", title: "Editor", show_back: true)
    end

    test "back button is rendered" do
      assert_exists("#back")
    end

    test "clicking the back button does not raise" do
      click("#back")
      assert_exists("#tb_title")
    end
  end

  describe "with action buttons" do
    setup do
      init_widget("tb",
        title: "List",
        actions: [{"new_note", "New"}, {"delete_selected", "Delete"}]
      )
    end

    test "action buttons are rendered" do
      assert_exists("#new_note")
      assert_exists("#delete_selected")
    end

    test "action button labels are correct" do
      assert_text("#new_note", "New")
      assert_text("#delete_selected", "Delete")
    end

    test "clicking an action button does not raise" do
      click("#new_note")
      assert_exists("#tb_title")
    end
  end

  describe "back button and actions together" do
    setup do
      init_widget("tb",
        title: "Editor",
        show_back: true,
        actions: [{"save", "Save"}]
      )
    end

    test "back button and action button coexist" do
      assert_exists("#back")
      assert_exists("#save")
    end
  end

  describe "widget metadata" do
    test "type_names" do
      assert Notes.Widgets.Toolbar.type_names() == [:toolbar]
    end
  end
end
