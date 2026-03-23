# frozen_string_literal: true

require_relative "test_helper"

class DashboardTest < Plushie::Test::Case
  app Dashboard

  # -- initial view --

  def test_initial_view_has_title
    assert_text "#title", "System Monitor"
  end

  def test_initial_view_has_pause_button
    assert_text "#toggle_running", "Pause"
  end

  def test_initial_view_has_clear_button
    assert_text "#clear", "Clear"
  end

  def test_initial_view_has_status_text
    assert_text "#status", "0 samples"
  end

  def test_initial_view_has_sparkline_labels
    assert_text "#cpu_label", "CPU Usage"
    assert_text "#mem_label", "Memory"
    assert_text "#net_label", "Network I/O"
  end

  def test_initial_view_has_sparkline_widgets
    assert_exists "#cpu_spark"
    assert_exists "#mem_spark"
    assert_exists "#net_spark"
  end

  # -- pause/resume --

  def test_click_pause_changes_button_to_resume
    click "#toggle_running"
    assert_text "#toggle_running", "Resume"
  end

  def test_click_resume_changes_button_back_to_pause
    click "#toggle_running"
    assert_text "#toggle_running", "Resume"

    click "#toggle_running"
    assert_text "#toggle_running", "Pause"
  end

  # -- clear --

  def test_click_clear_resets_sample_count
    # Status starts at "0 samples" -- clear should keep it there
    click "#clear"
    assert_text "#status", "0 samples"
  end
end
