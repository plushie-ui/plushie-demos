# frozen_string_literal: true

require_relative "test_helper"

class CollabTest < Plushie::Test::Case
  app Collab

  # -- initial state --

  def test_initial_view_has_all_widgets
    assert_exists "#header"
    assert_exists "#name"
    assert_exists "#count"
    assert_exists "#theme"
    assert_exists "#notes"
  end

  def test_initial_model
    assert_equal "", model.name
    assert_equal "", model.notes
    assert_equal 0, model.count
    assert_equal false, model.dark_mode
  end

  def test_initial_count_text
    assert_text "#count", "Count: 0"
  end

  def test_header_text
    assert_text "#header", "Plushie Demo"
  end

  # -- counter --

  def test_increment
    click "#inc"
    assert_text "#count", "Count: 1"
    assert_equal 1, model.count
  end

  def test_decrement
    click "#inc"
    click "#inc"
    click "#dec"
    assert_text "#count", "Count: 1"
    assert_equal 1, model.count
  end

  def test_multiple_increments
    3.times { click "#inc" }
    assert_text "#count", "Count: 3"
  end

  # -- text inputs --

  def test_name_input
    type_text "#name", "Alice"
    assert_equal "Alice", model.name
  end

  def test_notes_input
    type_text "#notes", "Hello world"
    assert_equal "Hello world", model.notes
  end

  # -- dark mode --

  def test_toggle_dark_mode_on
    toggle "#theme"
    assert_equal true, model.dark_mode
  end

  def test_toggle_dark_mode_off
    toggle "#theme"
    toggle "#theme"
    assert_equal false, model.dark_mode
  end

  # -- field isolation --

  def test_increment_preserves_name
    type_text "#name", "Bob"
    click "#inc"
    assert_equal "Bob", model.name
    assert_equal 1, model.count
  end

  def test_name_input_preserves_count
    click "#inc"
    type_text "#name", "Bob"
    assert_equal "Bob", model.name
    assert_equal 1, model.count
  end

  def test_toggle_preserves_notes
    type_text "#notes", "Keep this"
    toggle "#theme"
    assert_equal true, model.dark_mode
    assert_equal "Keep this", model.notes
  end

  # -- status is empty when not in collaborative mode --

  def test_status_hidden_when_empty
    assert_not_exists "#status"
  end
end
