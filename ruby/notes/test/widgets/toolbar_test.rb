# frozen_string_literal: true

require_relative "../test_helper"

class ToolbarTest < Minitest::Test
  Tree = Plushie::Tree

  def test_type_names
    assert_equal [:toolbar], Notes::Toolbar.type_names
  end

  def test_new_with_defaults
    tb = Notes::Toolbar.new("tb")
    assert_equal "tb", tb.id
    assert_equal "", tb.title
    assert_equal false, tb.show_back
    assert_equal [], tb.actions
  end

  def test_build_with_title_only
    tb = Notes::Toolbar.new("tb", title: "Hello")
    node = tb.build
    title = Tree.find(node, "tb_title")
    refute_nil title
    assert_equal "Hello", title.props[:content]
  end

  def test_build_with_back_button
    tb = Notes::Toolbar.new("tb", show_back: true)
    node = tb.build
    back = Tree.find(node, "back")
    refute_nil back
    assert_equal "button", back.type
  end

  def test_build_without_back_button
    tb = Notes::Toolbar.new("tb", show_back: false)
    node = tb.build
    back = Tree.find(node, "back")
    assert_nil back
  end

  def test_build_with_actions
    tb = Notes::Toolbar.new("tb", actions: [["save", "Save"], ["cancel", "Cancel"]])
    node = tb.build
    save = Tree.find(node, "save")
    refute_nil save
    assert_equal "button", save.type
    cancel = Tree.find(node, "cancel")
    refute_nil cancel
  end
end
