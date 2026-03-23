# frozen_string_literal: true

require_relative "../test_helper"

class NoteCardTest < Minitest::Test
  Tree = Plushie::Tree

  def test_type_names
    assert_equal [:note_card], Notes::NoteCard.type_names
  end

  def test_not_native
    refute Notes::NoteCard.native?
  end

  def test_not_container
    refute Notes::NoteCard.container?
  end

  def test_new_with_defaults
    card = Notes::NoteCard.new("test")
    assert_equal "test", card.id
    assert_equal "", card.title
    assert_equal "", card.preview
    assert_equal "", card.timestamp
    assert_equal false, card.selected
  end

  def test_new_with_custom_props
    card = Notes::NoteCard.new("test",
      title: "Hello", preview: "World", timestamp: "Jan 1", selected: true)
    assert_equal "Hello", card.title
    assert_equal "World", card.preview
    assert_equal "Jan 1", card.timestamp
    assert_equal true, card.selected
  end

  def test_build_produces_node
    card = Notes::NoteCard.new("test", title: "Hello")
    node = card.build
    assert_instance_of Plushie::Node, node
  end

  def test_outer_node_is_mouse_area
    card = Notes::NoteCard.new("n1", title: "Title")
    node = card.build
    assert_equal "mouse_area", node.type
    assert_equal "n1_card", node.id
  end

  def test_node_contains_checkbox
    card = Notes::NoteCard.new("n1", title: "Title", selected: true)
    node = card.build
    cb = Tree.find(node, "select_n1")
    refute_nil cb
    assert_equal "checkbox", cb.type
    assert_equal true, cb.props[:checked]
  end

  def test_node_contains_title_text
    card = Notes::NoteCard.new("n1", title: "My Note")
    node = card.build
    title = Tree.find(node, "n1_title")
    refute_nil title
    assert_equal "My Note", title.props[:content]
  end

  def test_selected_checkbox_state
    card_off = Notes::NoteCard.new("n1", selected: false)
    cb = Tree.find(card_off.build, "select_n1")
    assert_equal false, cb.props[:checked]

    card_on = Notes::NoteCard.new("n1", selected: true)
    cb = Tree.find(card_on.build, "select_n1")
    assert_equal true, cb.props[:checked]
  end
end
