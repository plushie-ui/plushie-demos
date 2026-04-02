defmodule PlushiePad.SharedTest do
  use ExUnit.Case, async: true

  @moduletag capture_log: true

  # A harmless event that exercises the update pipeline.
  # Escape clears the error field -- a safe no-op on a fresh model.
  defp escape_event do
    %Plushie.Event.KeyEvent{
      type: :press,
      key: :escape,
      modifiers: %Plushie.KeyModifiers{}
    }
  end

  describe "connect" do
    test "broadcasts the current model to the connecting client" do
      {:ok, server} = PlushiePad.Shared.start_link()
      PlushiePad.Shared.connect(server, "client-1")

      assert_receive {:model_changed, model}
      assert is_map(model)
      assert Map.has_key?(model, :source)
      assert Map.has_key?(model, :event_log)
    end

    test "multiple connects each receive the model" do
      {:ok, server} = PlushiePad.Shared.start_link()

      PlushiePad.Shared.connect(server, "a")
      assert_receive {:model_changed, _}

      PlushiePad.Shared.connect(server, "b")
      # Both clients receive the broadcast
      assert_receive {:model_changed, _}
      assert_receive {:model_changed, _}
    end
  end

  describe "event" do
    test "updates model and broadcasts to all clients" do
      {:ok, server} = PlushiePad.Shared.start_link()
      PlushiePad.Shared.connect(server, "client-1")
      assert_receive {:model_changed, _initial}

      PlushiePad.Shared.event(server, escape_event())
      assert_receive {:model_changed, updated}
      assert updated.error == nil
    end

    test "broadcasts to multiple clients" do
      {:ok, server} = PlushiePad.Shared.start_link()
      test_pid = self()

      PlushiePad.Shared.connect(server, "client-1")
      assert_receive {:model_changed, _}

      {:ok, client2} =
        Task.start_link(fn ->
          PlushiePad.Shared.connect(server, "client-2")

          receive do
            {:model_changed, _} -> send(test_pid, :c2_connected)
          end

          receive do
            {:model_changed, _m} -> send(test_pid, :c2_got_update)
          end
        end)

      # Wait for client2's connect broadcast (sent to both clients)
      assert_receive {:model_changed, _}
      assert_receive :c2_connected

      PlushiePad.Shared.event(server, escape_event())
      assert_receive {:model_changed, _}
      assert_receive :c2_got_update

      Process.exit(client2, :normal)
    end
  end

  describe "disconnect" do
    test "removes the client from the broadcast list" do
      {:ok, server} = PlushiePad.Shared.start_link()
      PlushiePad.Shared.connect(server, "client-1")
      assert_receive {:model_changed, _}

      PlushiePad.Shared.disconnect(server, "client-1")

      PlushiePad.Shared.event(server, escape_event())
      refute_receive {:model_changed, _}, 100
    end
  end

  describe "client crash" do
    test "DOWN message removes the crashed client" do
      {:ok, server} = PlushiePad.Shared.start_link()

      {pid, ref} =
        spawn_monitor(fn ->
          PlushiePad.Shared.connect(server, "ephemeral")
          receive do: (:stop -> :ok)
        end)

      # Give the connect call time to complete
      Process.sleep(50)

      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

      # Give the server time to process the DOWN
      Process.sleep(50)

      # Connect ourselves and verify we're the only client
      PlushiePad.Shared.connect(server, "survivor")
      assert_receive {:model_changed, _}

      PlushiePad.Shared.event(server, escape_event())
      assert_receive {:model_changed, _}

      # Only one broadcast (ours), not two
      refute_receive {:model_changed, _}, 100
    end
  end
end
