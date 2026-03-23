# frozen_string_literal: true

require_relative "../test_helper"

class ShortcutBarTest < Minitest::Test
  Tree = Plushie::Tree

  def test_type_names
    assert_equal [:shortcut_bar], Notes::ShortcutBar.type_names
  end

  def test_new_with_defaults
    bar = Notes::ShortcutBar.new("sb")
    assert_equal "sb", bar.id
    assert_equal [], bar.hints
  end

  def test_build_with_hints
    bar = Notes::ShortcutBar.new("sb", hints: ["Ctrl+N new", "Esc back"])
    node = bar.build
    refute_nil node
    assert_instance_of Plushie::Node, node
  end

  def test_each_hint_becomes_text_node
    hints = ["Ctrl+N new", "Esc back", "Ctrl+Z undo"]
    bar = Notes::ShortcutBar.new("sb", hints: hints)
    node = bar.build

    hints.each_with_index do |hint, i|
      text_node = Tree.find(node, "sb_hint_#{i}")
      refute_nil text_node, "Expected hint node sb_hint_#{i}"
      assert_equal hint, text_node.props[:content]
    end
  end
end
