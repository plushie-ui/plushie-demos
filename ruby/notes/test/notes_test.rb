# frozen_string_literal: true

require_relative "test_helper"

class NotesTest < Plushie::Test::Case
  app Notes

  # -- initial state --

  def test_initial_view_shows_three_notes
    assert_exists "#note_welcome_card"
    assert_exists "#note_shortcuts_card"
    assert_exists "#note_widgets_card"
  end

  def test_initial_view_has_toolbar
    assert_exists "#toolbar_bar"
  end

  def test_initial_view_has_search
    assert_exists "#search"
  end

  def test_initial_view_has_shortcut_bar
    assert_exists "#shortcuts_bar"
  end

  def test_initial_view_has_new_button
    assert_exists "#new_note"
  end

  def test_initial_view_shows_note_titles
    assert_text "#note_welcome_title", "Welcome to Plushie Notes"
    assert_text "#note_shortcuts_title", "Keyboard shortcuts"
    assert_text "#note_widgets_title", "Custom widgets"
  end

  def test_init_route_at_list
    assert_equal "/list", Plushie::Route.current(model.route)
  end

  def test_init_empty_search
    assert_equal "", model.search
  end

  def test_init_selection_empty
    assert Plushie::Selection.selected(model.selection).empty?
  end

  def test_init_no_undo
    assert_nil model.undo
  end

  def test_init_sort_by_recent
    assert_equal :recent, model.sort_by
  end

  # -- navigation --

  def test_click_note_opens_editor
    click "#note_welcome_card"
    assert_exists "#editor_title"
    assert_exists "#editor_content"
    assert_exists "#back"
  end

  def test_back_returns_to_list
    click "#note_welcome_card"
    click "#back"
    assert_exists "#note_welcome_card"
    assert_not_exists "#editor_title"
  end

  # -- CRUD --

  def test_new_note_opens_editor_with_untitled
    click "#new_note"
    assert_exists "#editor_title"
    assert_text "#editor_title", "Untitled"
  end

  def test_new_note_adds_to_list
    click "#new_note"
    click "#back"
    # Original 3 + 1 new
    assert_equal 4, model.notes.length
  end

  def test_delete_selected_removes_notes
    toggle "#select_note_welcome"
    click "#delete_selected"
    assert_not_exists "#note_welcome_card"
    assert Plushie::Selection.selected(model.selection).empty?
  end

  def test_delete_with_no_selection_does_nothing
    # delete_selected button isn't rendered when nothing is selected,
    # so we just verify the note count is unchanged
    assert_equal 3, model.notes.length
  end

  # -- editor --

  def test_update_title_in_editor
    click "#note_welcome_card"
    type_text "#editor_title", "New Title"
    note = model.notes.find { |n| n.id == "welcome" }
    assert_equal "New Title", note.title
  end

  def test_update_content_creates_undo
    click "#note_welcome_card"
    type_text "#editor_content", "Updated body"
    note = model.notes.find { |n| n.id == "welcome" }
    assert_equal "Updated body", note.content
    assert Plushie::Undo.can_undo?(model.undo)
  end

  # -- undo/redo --

  def test_undo_restores_previous_content
    click "#note_welcome_card"
    original_content = model.notes.find { |n| n.id == "welcome" }.content
    type_text "#editor_content", "Changed"
    press "ctrl+z"
    note = model.notes.find { |n| n.id == "welcome" }
    assert_equal original_content, note.content
  end

  def test_redo_reapplies_content
    click "#note_welcome_card"
    type_text "#editor_content", "Changed"
    press "ctrl+z"
    press "ctrl+y"
    note = model.notes.find { |n| n.id == "welcome" }
    assert_equal "Changed", note.content
  end

  def test_undo_when_nothing_to_undo_is_noop
    click "#note_welcome_card"
    notes_before = model.notes
    press "ctrl+z"
    assert_equal notes_before, model.notes
  end

  # -- search --

  def test_search_filters_notes
    type_text "#search", "keyboard"
    assert_exists "#note_shortcuts_card"
    assert_not_exists "#note_welcome_card"
    assert_not_exists "#note_widgets_card"
  end

  # -- sort --

  def test_sort_by_title
    select "#sort", "A-Z"
    assert_equal :title, model.sort_by
  end

  def test_sort_by_oldest
    select "#sort", "Oldest"
    assert_equal :oldest, model.sort_by
  end

  # -- selection --

  def test_toggle_selection
    toggle "#select_note_welcome"
    assert Plushie::Selection.selected?(model.selection, "welcome")
  end

  def test_selection_shows_delete_button
    toggle "#select_note_welcome"
    assert_exists "#delete_selected"
  end

  def test_escape_clears_selection
    toggle "#select_note_welcome"
    press "Escape"
    assert Plushie::Selection.selected(model.selection).empty?
  end

  def test_escape_in_editor_navigates_back
    click "#note_welcome_card"
    press "Escape"
    assert_exists "#note_welcome_card"
    assert_not_exists "#editor_title"
  end

  def test_escape_clears_selection_before_search
    toggle "#select_note_welcome"
    type_text "#search", "test"
    press "Escape"
    # Selection cleared first, search still present
    assert Plushie::Selection.selected(model.selection).empty?
    assert_equal "test", model.search
  end

  def test_escape_clears_search_when_no_selection
    type_text "#search", "test"
    press "Escape"
    assert_equal "", model.search
  end

  def test_escape_noop_when_nothing_to_clear
    model_before = model
    press "Escape"
    assert_equal model_before, model
  end

  # -- keyboard shortcuts --

  def test_ctrl_n_creates_note
    press "ctrl+n"
    assert_exists "#editor_title"
    assert_equal 4, model.notes.length
  end

  def test_ctrl_z_undoes_in_editor
    click "#note_welcome_card"
    type_text "#editor_content", "Changed"
    press "ctrl+z"
    refute_equal "Changed", model.notes.find { |n| n.id == "welcome" }.content
  end

  def test_ctrl_y_redoes_in_editor
    click "#note_welcome_card"
    type_text "#editor_content", "Changed"
    press "ctrl+z"
    press "ctrl+y"
    assert_equal "Changed", model.notes.find { |n| n.id == "welcome" }.content
  end

  # -- editor view structure --

  def test_editor_view_has_shortcut_bar
    click "#note_welcome_card"
    assert_exists "#shortcuts_bar"
  end

  def test_editor_view_shows_undo_button_after_edit
    click "#note_welcome_card"
    type_text "#editor_content", "Changed"
    assert_exists "#undo"
  end

  # -- subscribe --

  def test_subscribe_returns_key_press_subscription
    app = Notes.new
    subs = app.subscribe(model)
    assert_equal 1, subs.length
    assert_equal :on_key_press, subs.first.type
  end

  # -- unmatched event --

  def test_unmatched_event_returns_model
    model_before = model
    # Pressing a random key with no binding should be a no-op
    press "F12"
    assert_equal model_before, model
  end
end
