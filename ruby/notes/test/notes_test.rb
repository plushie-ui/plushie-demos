# frozen_string_literal: true

require_relative "test_helper"

class NotesTest < Minitest::Test
  Event = Plushie::Event
  Tree = Plushie::Tree

  def setup
    @app = Notes.new
    @model = @app.init({})
  end

  # -- init --

  def test_init_has_seed_notes
    assert_equal 3, @model.notes.length
    assert_equal "welcome", @model.notes.first.id
  end

  def test_init_route_at_list
    assert_equal "/list", Plushie::Route.current(@model.route)
  end

  def test_init_empty_search
    assert_equal "", @model.search
  end

  def test_init_selection_empty
    assert Plushie::Selection.selected(@model.selection).empty?
  end

  def test_init_no_undo
    assert_nil @model.undo
  end

  def test_init_sort_by_recent
    assert_equal :recent, @model.sort_by
  end

  # -- navigation --

  def test_click_note_opens_editor
    event = Event::Widget.new(type: :click, id: "note_welcome")
    model = @app.update(@model, event)
    assert_equal "/editor", Plushie::Route.current(model.route)
    assert_equal "welcome", Plushie::Route.params(model.route)[:note_id]
  end

  def test_back_pops_to_list
    event = Event::Widget.new(type: :click, id: "note_welcome")
    model = @app.update(@model, event)
    back = Event::Widget.new(type: :click, id: "back")
    model = @app.update(model, back)
    assert_equal "/list", Plushie::Route.current(model.route)
  end

  def test_back_from_list_does_nothing
    back = Event::Widget.new(type: :click, id: "back")
    model = @app.update(@model, back)
    assert_equal "/list", Plushie::Route.current(model.route)
  end

  # -- CRUD --

  def test_create_note_adds_to_front_and_navigates
    event = Event::Widget.new(type: :click, id: "new_note")
    model = @app.update(@model, event)
    assert_equal 4, model.notes.length
    assert_equal "Untitled", model.notes.first.title
    assert_equal "/editor", Plushie::Route.current(model.route)
    assert_equal model.notes.first.id, Plushie::Route.params(model.route)[:note_id]
  end

  def test_delete_selected_removes_notes
    sel = Plushie::Selection.toggle(@model.selection, "welcome")
    model = @model.with(selection: sel)
    event = Event::Widget.new(type: :click, id: "delete_selected")
    model = @app.update(model, event)
    refute model.notes.any? { |n| n.id == "welcome" }
    assert Plushie::Selection.selected(model.selection).empty?
  end

  def test_delete_with_no_selection_does_nothing
    event = Event::Widget.new(type: :click, id: "delete_selected")
    model = @app.update(@model, event)
    assert_equal 3, model.notes.length
  end

  # -- editor --

  def test_update_title_changes_note
    model = open_note(@model, "welcome")
    event = Event::Widget.new(type: :input, id: "editor_title",
      data: {"value" => "New Title"})
    model = @app.update(model, event)
    note = model.notes.find { |n| n.id == "welcome" }
    assert_equal "New Title", note.title
  end

  def test_update_content_changes_note_and_creates_undo
    model = open_note(@model, "welcome")
    event = Event::Widget.new(type: :input, id: "editor_content",
      data: {"value" => "Updated body"})
    model = @app.update(model, event)
    note = model.notes.find { |n| n.id == "welcome" }
    assert_equal "Updated body", note.content
    assert Plushie::Undo.can_undo?(model.undo)
  end

  # -- undo/redo --

  def test_undo_restores_previous_content
    model = open_note(@model, "welcome")
    original_content = model.notes.find { |n| n.id == "welcome" }.content

    event = Event::Widget.new(type: :input, id: "editor_content",
      data: {"value" => "Changed"})
    model = @app.update(model, event)

    undo_event = Event::Key.new(type: :press, key: "z", modifiers: {ctrl: true})
    model = @app.update(model, undo_event)
    note = model.notes.find { |n| n.id == "welcome" }
    assert_equal original_content, note.content
  end

  def test_redo_reapplies_content
    model = open_note(@model, "welcome")

    event = Event::Widget.new(type: :input, id: "editor_content",
      data: {"value" => "Changed"})
    model = @app.update(model, event)

    undo_event = Event::Key.new(type: :press, key: "z", modifiers: {ctrl: true})
    model = @app.update(model, undo_event)

    redo_event = Event::Key.new(type: :press, key: "y", modifiers: {ctrl: true})
    model = @app.update(model, redo_event)
    note = model.notes.find { |n| n.id == "welcome" }
    assert_equal "Changed", note.content
  end

  def test_undo_when_nothing_to_undo_is_noop
    model = open_note(@model, "welcome")
    undo_event = Event::Key.new(type: :press, key: "z", modifiers: {ctrl: true})
    model2 = @app.update(model, undo_event)
    assert_equal model.notes, model2.notes
  end

  # -- search --

  def test_search_updates_model
    event = Event::Widget.new(type: :input, id: "search",
      data: {"value" => "keyboard"})
    model = @app.update(@model, event)
    assert_equal "keyboard", model.search
  end

  # -- sort --

  def test_sort_select_changes_sort_by
    event = Event::Widget.new(type: :select, id: "sort",
      data: {"value" => "A-Z"})
    model = @app.update(@model, event)
    assert_equal :title, model.sort_by
  end

  def test_sort_oldest
    event = Event::Widget.new(type: :select, id: "sort",
      data: {"value" => "Oldest"})
    model = @app.update(@model, event)
    assert_equal :oldest, model.sort_by
  end

  # -- selection --

  def test_toggle_selection
    event = Event::Widget.new(type: :toggle, id: "select_welcome")
    model = @app.update(@model, event)
    assert Plushie::Selection.selected?(model.selection, "welcome")
  end

  def test_escape_clears_selection
    sel = Plushie::Selection.toggle(@model.selection, "welcome")
    model = @model.with(selection: sel)
    event = Event::Key.new(type: :press, key: "Escape")
    model = @app.update(model, event)
    assert Plushie::Selection.selected(model.selection).empty?
  end

  # -- escape --

  def test_escape_in_editor_navigates_back
    model = open_note(@model, "welcome")
    event = Event::Key.new(type: :press, key: "Escape")
    model = @app.update(model, event)
    assert_equal "/list", Plushie::Route.current(model.route)
  end

  def test_escape_clears_selection_before_search
    sel = Plushie::Selection.toggle(@model.selection, "welcome")
    model = @model.with(selection: sel, search: "test")
    event = Event::Key.new(type: :press, key: "Escape")
    model = @app.update(model, event)
    # Selection cleared first, search still present
    assert Plushie::Selection.selected(model.selection).empty?
    assert_equal "test", model.search
  end

  def test_escape_clears_search_when_no_selection
    model = @model.with(search: "test")
    event = Event::Key.new(type: :press, key: "Escape")
    model = @app.update(model, event)
    assert_equal "", model.search
  end

  def test_escape_noop_when_nothing_to_clear
    event = Event::Key.new(type: :press, key: "Escape")
    model = @app.update(@model, event)
    assert_equal @model, model
  end

  # -- keyboard shortcuts --

  def test_ctrl_n_creates_note
    event = Event::Key.new(type: :press, key: "n", modifiers: {ctrl: true})
    model = @app.update(@model, event)
    assert_equal 4, model.notes.length
    assert_equal "/editor", Plushie::Route.current(model.route)
  end

  def test_ctrl_z_undoes
    model = open_note(@model, "welcome")
    edit = Event::Widget.new(type: :input, id: "editor_content",
      data: {"value" => "Changed"})
    model = @app.update(model, edit)

    event = Event::Key.new(type: :press, key: "z", modifiers: {ctrl: true})
    model = @app.update(model, event)
    refute_equal "Changed", model.notes.find { |n| n.id == "welcome" }.content
  end

  def test_ctrl_y_redoes
    model = open_note(@model, "welcome")
    edit = Event::Widget.new(type: :input, id: "editor_content",
      data: {"value" => "Changed"})
    model = @app.update(model, edit)

    undo = Event::Key.new(type: :press, key: "z", modifiers: {ctrl: true})
    model = @app.update(model, undo)

    redo_ev = Event::Key.new(type: :press, key: "y", modifiers: {ctrl: true})
    model = @app.update(model, redo_ev)
    assert_equal "Changed", model.notes.find { |n| n.id == "welcome" }.content
  end

  # -- view: list --

  def test_view_list_contains_toolbar
    tree = @app.view(@model)
    toolbar = Tree.find(tree, "toolbar_bar")
    refute_nil toolbar
  end

  def test_view_list_contains_search
    tree = @app.view(@model)
    search = Tree.find(tree, "search")
    refute_nil search
  end

  def test_view_list_contains_note_cards
    tree = @app.view(@model)
    card = Tree.find(tree, "note_welcome_card")
    refute_nil card
  end

  def test_view_list_contains_shortcut_bar
    tree = @app.view(@model)
    bar = Tree.find(tree, "shortcuts_bar")
    refute_nil bar
  end

  def test_view_list_has_new_button
    tree = @app.view(@model)
    btn = Tree.find(tree, "new_note")
    refute_nil btn
  end

  def test_view_list_shows_note_titles
    tree = @app.view(@model)
    title_node = Tree.find(tree, "note_welcome_title")
    refute_nil title_node
    assert_equal "Welcome to Plushie Notes", title_node.props[:content]
  end

  # -- view: editor --

  def test_view_editor_contains_back_button
    model = open_note(@model, "welcome")
    tree = @app.view(model)
    back = Tree.find(tree, "back")
    refute_nil back
  end

  def test_view_editor_contains_title_input
    model = open_note(@model, "welcome")
    tree = @app.view(model)
    title_input = Tree.find(tree, "editor_title")
    refute_nil title_input
  end

  def test_view_editor_contains_content_input
    model = open_note(@model, "welcome")
    tree = @app.view(model)
    content_input = Tree.find(tree, "editor_content")
    refute_nil content_input
  end

  def test_view_editor_shortcut_bar
    model = open_note(@model, "welcome")
    tree = @app.view(model)
    bar = Tree.find(tree, "shortcuts_bar")
    refute_nil bar
  end

  def test_view_editor_undo_hints
    model = open_note(@model, "welcome")
    edit = Event::Widget.new(type: :input, id: "editor_content",
      data: {"value" => "Changed"})
    model = @app.update(model, edit)

    tree = @app.view(model)
    undo_btn = Tree.find(tree, "undo")
    refute_nil undo_btn
  end

  # -- view: list with selection --

  def test_view_list_with_selection_shows_delete
    sel = Plushie::Selection.toggle(@model.selection, "welcome")
    model = @model.with(selection: sel)
    tree = @app.view(model)
    delete_btn = Tree.find(tree, "delete_selected")
    refute_nil delete_btn
  end

  def test_view_list_with_selection_shortcut_hints
    sel = Plushie::Selection.toggle(@model.selection, "welcome")
    model = @model.with(selection: sel)
    tree = @app.view(model)
    hints = Tree.find_all(tree) { |n| n.id.start_with?("shortcuts_hint_") }
    hint_texts = hints.map { |n| n.props[:content] }
    assert hint_texts.any? { |t| t.include?("Del") }
  end

  # -- DataQuery integration --

  def test_search_filters_notes_in_view
    model = @model.with(search: "keyboard")
    tree = @app.view(model)
    # Only the shortcuts note matches "keyboard"
    card = Tree.find(tree, "note_shortcuts_card")
    refute_nil card
    # Other cards should not be present
    welcome_card = Tree.find(tree, "note_welcome_card")
    assert_nil welcome_card
  end

  def test_sort_changes_order
    model = @model.with(sort_by: :title)
    tree = @app.view(model)
    col = Tree.find(tree, "notes_col")
    refute_nil col
    # Cards should be in alphabetical order by title
    card_ids = col.children
      .select { |n| n.id.end_with?("_card") }
      .map { |n| n.id }
    # "Custom widgets" < "Keyboard shortcuts" < "Welcome to Plushie Notes"
    assert_equal %w[note_widgets_card note_shortcuts_card note_welcome_card], card_ids
  end

  # -- subscribe --

  def test_subscribe_returns_key_press_subscription
    subs = @app.subscribe(@model)
    assert_equal 1, subs.length
    assert_equal :on_key_press, subs.first.type
  end

  # -- editor view with missing note --

  def test_editor_view_missing_note_shows_not_found
    model = @model.with(
      route: Plushie::Route.push(@model.route, "/editor", note_id: "nonexistent")
    )
    tree = @app.view(model)
    missing = Tree.find(tree, "missing")
    refute_nil missing
    assert_includes missing.props[:content], "no longer exists"
  end

  # -- unmatched event --

  def test_unmatched_event_returns_model
    event = Event::Widget.new(type: :click, id: "unknown_widget")
    model = @app.update(@model, event)
    assert_equal @model, model
  end

  private

  def open_note(model, note_id)
    event = Event::Widget.new(type: :click, id: "note_#{note_id}")
    @app.update(model, event)
  end
end
