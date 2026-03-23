# frozen_string_literal: true

require_relative "test_helper"

class TemperatureMonitorTest < Plushie::Test::Case
  app TemperatureMonitor

  # -- initial state --

  def test_initial_widgets_exist
    assert_exists "#title"
    assert_exists "#temp"
    assert_exists "#status"
    assert_exists "#target"
    assert_exists "#reset"
    assert_exists "#high"
    assert_exists "#reading"
    assert_exists "#history"
  end

  def test_initial_model
    assert_equal 20.0, model.temperature
    assert_equal 20.0, model.target_temp
    assert_equal [20.0], model.history
  end

  def test_initial_status
    assert_text "#status", "Status: Cool"
  end

  def test_initial_reading
    assert_text "#reading", "Current: 20\u00B0C | Target: 20\u00B0C"
  end

  # -- button: high --

  def test_click_high_updates_target
    click "#high"
    assert_equal 90.0, model.target_temp
  end

  def test_click_high_temperature_unchanged_without_confirmation
    click "#high"
    # Temperature stays at initial until the extension confirms via value_changed.
    # The mock backend processes extension_command as a no-op, so temperature
    # won't change from the click alone.
    assert_equal 20.0, model.temperature
  end

  # -- button: reset --

  def test_click_reset_updates_target
    # First go high, then reset
    click "#high"
    click "#reset"
    assert_equal 20.0, model.target_temp
  end

  def test_click_reset_temperature_unchanged_without_confirmation
    click "#high"
    click "#reset"
    assert_equal 20.0, model.temperature
  end

  # -- slider --

  def test_slide_updates_target
    slide "#target", 75
    assert_equal 75, model.target_temp
  end

  def test_slide_does_not_change_temperature
    slide "#target", 75
    assert_equal 20.0, model.temperature
    assert_equal [20.0], model.history
  end

  # -- rapid interactions --

  def test_rapid_clicks_only_update_target
    click "#high"
    click "#reset"
    click "#high"

    assert_equal 90.0, model.target_temp
    assert_equal 20.0, model.temperature
    assert_equal [20.0], model.history
  end

  # -- unknown events pass through --

  def test_model_unchanged_after_unrecognized_widget
    original = model
    # Clicking a widget that has no update handler leaves the model unchanged
    click "#title"
  rescue Plushie::Error
    # title is a text widget, not clickable -- the renderer may reject the interact.
    # Either way, the model should be unchanged.
    assert_equal original, model
  end
end
