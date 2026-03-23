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

  def test_broken_callback_does_not_block_others
    good_received = []
    @shared.connect("bad") { |_| raise "boom" }
    @shared.connect("good") { |m| good_received << m.count }

    event = Plushie::Event::Widget.new(
      type: :click, id: "inc", scope: [], data: nil
    )
    @shared.event("c1", event)
    assert_includes good_received, 1
  end
end
