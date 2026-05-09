defmodule Notes.Widgets.ShortcutBarTest do
  use Plushie.Test.WidgetCase, widget: Notes.Widgets.ShortcutBar

  describe "with multiple hints" do
    setup do
      init_widget("sb", hints: [{"Ctrl+N", "new"}, {"Ctrl+Z", "undo"}])
    end

    test "renders key and action text for first hint" do
      assert_text("#sb_key_0", "Ctrl+N")
      assert_text("#sb_act_0", "new")
    end

    test "renders key and action text for second hint" do
      assert_text("#sb_key_1", "Ctrl+Z")
      assert_text("#sb_act_1", "undo")
    end

    test "hint container rows exist" do
      assert_exists("#sb_h0")
      assert_exists("#sb_h1")
    end
  end

  describe "single hint" do
    setup do
      init_widget("sb", hints: [{"Esc", "cancel"}])
    end

    test "first hint is rendered" do
      assert_text("#sb_key_0", "Esc")
      assert_text("#sb_act_0", "cancel")
    end

    test "second hint is not rendered" do
      assert_not_exists("#sb_h1")
    end
  end

  describe "empty hints list" do
    setup do
      init_widget("sb", hints: [])
    end

    test "no hint rows rendered" do
      assert_not_exists("#sb_h0")
    end
  end

  describe "widget metadata" do
    test "type_names" do
      assert Notes.Widgets.ShortcutBar.type_names() == [:shortcut_bar]
    end
  end
end
