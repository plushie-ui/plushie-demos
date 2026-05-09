defmodule Notes.Widgets.NoteCardTest do
  use Plushie.Test.WidgetCase, widget: Notes.Widgets.NoteCard

  # NoteCard derives the selection checkbox id from the widget id:
  # init_widget("note_abc") -> checkbox "#select_abc", button "#note_abc"

  describe "full props rendering" do
    setup do
      init_widget("note_abc",
        title: "Hello World",
        preview: "First 80 chars of the note content...",
        timestamp: "May 9, 2026"
      )
    end

    test "title button exists and shows the title" do
      assert_exists("#note_abc")
      assert_text("#note_abc", "Hello World")
    end

    test "preview text is rendered" do
      assert_text("#note_abc_preview", "First 80 chars of the note content...")
    end

    test "timestamp is rendered" do
      assert_text("#note_abc_time", "May 9, 2026")
    end

    test "selection checkbox is present" do
      assert_exists("#select_abc")
    end
  end

  describe "selected prop" do
    setup do
      init_widget("note_xyz", title: "A Note", selected: true)
    end

    test "checkbox reflects selected=true" do
      element = find!("#select_xyz")
      assert element.props[:checked] == true
    end
  end

  describe "unselected default" do
    setup do
      init_widget("note_def", title: "Default")
    end

    test "checkbox is unchecked by default" do
      element = find!("#select_def")
      assert element.props[:checked] == false
    end
  end

  describe "empty optional fields" do
    setup do
      init_widget("note_min", title: "Minimal Note")
    end

    test "preview is not rendered when empty" do
      assert_not_exists("#note_min_preview")
    end

    test "timestamp is not rendered when empty" do
      assert_not_exists("#note_min_time")
    end
  end

  describe "interactions" do
    setup do
      init_widget("note_evt", title: "Clickable")
    end

    test "clicking the title button does not raise" do
      click("#note_evt")
      assert_exists("#note_evt")
    end

    test "toggling the checkbox does not raise" do
      toggle("#select_evt")
      assert_exists("#select_evt")
    end
  end

  describe "widget metadata" do
    test "type_names" do
      assert Notes.Widgets.NoteCard.type_names() == [:note_card]
    end
  end
end
