defmodule PlushiePad.SharedTest do
  use ExUnit.Case, async: true

  @moduletag capture_log: true

  # A harmless event that exercises the update pipeline.
  # Escape clears the error field - a safe no-op on a fresh model.
  defp escape_event do
    %Plushie.Event.KeyEvent{
      type: :press,
      key: :escape,
      modifiers: %Plushie.KeyModifiers{}
    }
  end

  # Shared.connect does not broadcast on connect; the ssh_channel /
  # websocket callers seed a fresh Plushie.Runtime from
  # Shared.get_model/1. These tests exercise the event + disconnect
  # paths by driving the server directly and using self() (or a
  # spawned process) as the client "runtime". Broadcasts land as
  # {:renderer_event, %PlushiePad.Broadcast{...}} via
  # Plushie.Runtime.dispatch/2.

  describe "connect" do
    test "registers the client without broadcasting" do
      {:ok, server} = PlushiePad.Shared.start_link()
      assert :ok = PlushiePad.Shared.connect(server, "client-1", self())

      refute_receive {:renderer_event, %PlushiePad.Broadcast{}}, 50
    end

    test "get_model returns the authoritative model" do
      {:ok, server} = PlushiePad.Shared.start_link()
      :ok = PlushiePad.Shared.connect(server, "client-1", self())

      model = PlushiePad.Shared.get_model(server)
      assert is_map(model)
      assert Map.has_key?(model, :source)
      assert Map.has_key?(model, :event_log)
    end
  end

  describe "event" do
    test "updates model and broadcasts to all clients" do
      {:ok, server} = PlushiePad.Shared.start_link()
      :ok = PlushiePad.Shared.connect(server, "client-1", self())

      PlushiePad.Shared.event(server, escape_event())
      assert_receive {:renderer_event, %PlushiePad.Broadcast{model: updated}}
      assert updated.error == nil
    end

    test "broadcasts to multiple clients" do
      {:ok, server} = PlushiePad.Shared.start_link()
      test_pid = self()

      :ok = PlushiePad.Shared.connect(server, "client-1", self())

      client2 =
        spawn_link(fn ->
          receive do
            {:renderer_event, %PlushiePad.Broadcast{}} ->
              send(test_pid, :c2_got_update)
          end
        end)

      :ok = PlushiePad.Shared.connect(server, "client-2", client2)

      PlushiePad.Shared.event(server, escape_event())
      assert_receive {:renderer_event, %PlushiePad.Broadcast{}}
      assert_receive :c2_got_update

      Process.exit(client2, :normal)
    end
  end

  describe "disconnect" do
    test "removes the client from the broadcast list" do
      {:ok, server} = PlushiePad.Shared.start_link()
      :ok = PlushiePad.Shared.connect(server, "client-1", self())

      PlushiePad.Shared.disconnect(server, "client-1")
      # disconnect is a cast; give it a moment to be processed before
      # emitting the event so the client is actually gone.
      _ = PlushiePad.Shared.get_model(server)

      PlushiePad.Shared.event(server, escape_event())
      refute_receive {:renderer_event, %PlushiePad.Broadcast{}}, 100
    end
  end

  describe "client crash" do
    test "DOWN message removes the crashed client" do
      {:ok, server} = PlushiePad.Shared.start_link()

      {pid, ref} =
        spawn_monitor(fn ->
          receive do: (:stop -> :ok)
        end)

      :ok = PlushiePad.Shared.connect(server, "ephemeral", pid)

      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

      # Give the server time to process the DOWN
      Process.sleep(50)

      # Connect ourselves and verify we're the only client
      :ok = PlushiePad.Shared.connect(server, "survivor", self())

      PlushiePad.Shared.event(server, escape_event())
      assert_receive {:renderer_event, %PlushiePad.Broadcast{}}

      # Only one broadcast (ours), not two
      refute_receive {:renderer_event, %PlushiePad.Broadcast{}}, 100
    end
  end
end
