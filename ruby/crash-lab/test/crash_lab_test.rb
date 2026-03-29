# frozen_string_literal: true

require_relative "test_helper"

class CrashLabTest < Plushie::Test::Case
  app CrashLab

  # -- initial view --

  def test_initial_view_has_title
    assert_text "#title", "Crash Lab"
  end

  def test_initial_view_has_subtitle
    assert_exists "#subtitle"
  end

  def test_initial_view_has_counter
    assert_text "#clicks", "Clicks: 0"
  end

  def test_initial_view_has_extension_panel
    assert_exists "#crasher"
    assert_text "#panic_ext", "Panic Extension"
    assert_text "#toggle_ext", "Remove from Tree"
  end

  def test_initial_view_has_ruby_error_panel
    assert_text "#ruby_heading", "Ruby Errors"
    assert_text "#recover", "Recover View"
    assert_text "#raise_update", "Raise in Update"
    assert_text "#raise_view", "Raise in View"
  end

  def test_initial_view_has_footer
    element = find!("#footer")
    actual = text(element)
    assert_includes actual, "rendered successfully"
  end

  # -- counter --

  def test_click_count_increments
    click "#count"
    assert_text "#clicks", "Clicks: 1"
  end

  def test_click_count_increments_multiple
    click "#count"
    click "#count"
    click "#count"
    assert_text "#clicks", "Clicks: 3"
  end

  # -- toggle widget --

  def test_toggle_ext_removes_extension
    click "#toggle_ext"
    assert_not_exists "#crasher"
    assert_text "#toggle_ext", "Restore Extension"
  end

  def test_toggle_ext_restores_extension
    click "#toggle_ext"
    assert_not_exists "#crasher"

    click "#toggle_ext"
    assert_exists "#crasher"
    assert_text "#toggle_ext", "Remove from Tree"
  end

  def test_counter_works_after_toggle
    click "#toggle_ext"
    click "#count"
    assert_text "#clicks", "Clicks: 1"
  end

  # -- raise in update --

  def test_raise_update_app_survives
    # Click raise_update -- the runtime catches the error and preserves
    # the model. Then clicking +1 proves the app is still alive.
    click "#count"
    assert_text "#clicks", "Clicks: 1"

    click "#raise_update"

    # Model was preserved at count=1 by the runtime's error recovery
    click "#count"
    assert_text "#clicks", "Clicks: 2"
  end

  # -- raise in view --

  def test_raise_view_preserves_tree_and_recovers
    # Clicking raise_view sets view_broken=true. On the next render,
    # the runtime catches the error and preserves the previous tree.
    # The UI stays visible (with the recover button).
    click "#raise_view"

    # The previous tree is preserved by the runtime, so the view
    # should still be visible. Click recover to clear the flag.
    click "#recover"

    # View renders normally again
    assert_exists "#footer"
    assert_text "#clicks", "Clicks: 0"
  end
end
