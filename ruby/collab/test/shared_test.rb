# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/collab/shared"

class SharedTest < Minitest::Test
  def setup
    @shared = Collab::Shared.new
  end

  def test_connect_returns_model
    model = @shared.connect("c1") { |_| }
    assert_equal 0, model.count
    assert_equal "", model.name
  end

  def test_connect_updates_status
    model = @shared.connect("c1") { |_| }
    assert_equal "1 connected", model.status
  end

  def test_connect_broadcasts_to_existing_clients
    received = []
    @shared.connect("c1") { |m| received << m.status }
    @shared.connect("c2") { |_| }
    assert_includes received, "2 connected"
  end

  def test_disconnect_updates_status
    received = []
    @shared.connect("c1") { |m| received << m.status }
    @shared.connect("c2") { |_| }
    received.clear
    @shared.disconnect("c2")
    assert_includes received, "1 connected"
  end

  def test_event_updates_model
    @shared.connect("c1") { |_| }
    event = Plushie::Event::Widget.new(
      type: :click, id: "inc", scope: [], data: nil
    )
    @shared.event("c1", event)
    # Connect a new client to get the current model
    model = @shared.connect("c2") { |_| }
    assert_equal 1, model.count
  end

  def test_event_broadcasts_to_all_clients
    received_c1 = []
    received_c2 = []
    @shared.connect("c1") { |m| received_c1 << m.count }
    @shared.connect("c2") { |m| received_c2 << m.count }

    event = Plushie::Event::Widget.new(
      type: :click, id: "inc", scope: [], data: nil
    )
    @shared.event("c1", event)

    assert_includes received_c1, 1
    assert_includes received_c2, 1
  end

  def test_event_preserves_status
    @shared.connect("c1") { |_| }
    event = Plushie::Event::Widget.new(
      type: :click, id: "inc", scope: [], data: nil
    )
    @shared.event("c1", event)

    model = @shared.connect("c2") { |_| }
    assert_equal "2 connected", model.status
    assert_equal 1, model.count
  end

  def test_disconnect_nonexistent_client_is_safe
    @shared.disconnect("nobody")
    # Should not raise
  end

  def test_all_disconnected_shows_zero
    @shared.connect("c1") { |_| }
    @shared.disconnect("c1")
    model = @shared.connect("c2") { |_| }
    # c2 is the only one connected now
    assert_equal "1 connected", model.status
  end

  def test_multiple_increments_are_atomic
    @shared.connect("c1") { |_| }
    inc = Plushie::Event::Widget.new(
      type: :click, id: "inc", scope: [], data: nil
    )
    5.times { @shared.event("c1", inc) }
    model = @shared.connect("c2") { |_| }
    assert_equal 5, model.count
  end

  def test_concurrent_events_from_multiple_threads
    @shared.connect("c1") { |_| }
    @shared.connect("c2") { |_| }

    inc = Plushie::Event::Widget.new(
      type: :click, id: "inc", scope: [], data: nil
    )

    threads = 10.times.map do |i|
      Thread.new { 10.times { @shared.event("c#{(i % 2) + 1}", inc) } }
    end
    threads.each(&:join)

    model = @shared.connect("c3") { |_| }
    assert_equal 100, model.count
  end

  def test_event_does_not_overwrite_status_with_app_update
    # The app's update doesn't touch status, but verify the broker
    # preserves it even when the app returns a model without changes
    @shared.connect("c1") { |_| }
    @shared.connect("c2") { |_| }

    name_event = Plushie::Event::Widget.new(
      type: :input, id: "name", scope: [],
      data: {"value" => "Alice"}
    )
    @shared.event("c1", name_event)

    model = @shared.connect("c3") { |_| }
    assert_equal "Alice", model.name
    assert_equal "3 connected", model.status
  end

  def test_disconnect_then_reconnect
    @shared.connect("c1") { |_| }
    inc = Plushie::Event::Widget.new(
      type: :click, id: "inc", scope: [], data: nil
    )
    @shared.event("c1", inc)
    @shared.disconnect("c1")

    # Reconnect -- should see the accumulated state
    model = @shared.connect("c1") { |_| }
    assert_equal 1, model.count
    assert_equal "1 connected", model.status
  end

  def test_broken_callback_does_not_block_others
    good_received = []
    @shared.connect("bad") { |_| raise "boom" }
    @shared.connect("good") { |m| good_received << m.count }

    event = Plushie::Event::Widget.new(
      type: :click, id: "inc", scope: [], data: nil
    )
    @shared.event("good", event)
    assert_includes good_received, 1
  end
end
