defmodule Collab.SharedTest do
  use ExUnit.Case, async: true

  alias Collab.Shared
  alias Plushie.Event.Widget

  # -- Helpers ----------------------------------------------------------------

  defp click(id), do: %Widget{type: :click, id: id}
  defp input(id, value), do: %Widget{type: :input, id: id, value: value}

  defp receive_model do
    assert_receive {:model_changed, model}, 500
    model
  end

  # Drain any pending model_changed messages from the mailbox.
  defp flush_models do
    receive do
      {:model_changed, _} -> flush_models()
    after
      50 -> :ok
    end
  end

  # -- Connect / disconnect ---------------------------------------------------

  describe "connect/2" do
    test "registers client and receives initial model" do
      {:ok, shared} = Shared.start_link()
      :ok = Shared.connect(shared, "c1")

      model = receive_model()
      assert model.name == ""
      assert model.count == 0
    end

    test "status reflects connection count" do
      {:ok, shared} = Shared.start_link()
      :ok = Shared.connect(shared, "c1")

      model = receive_model()
      assert model.status == "1 connected"
    end

    test "second connection updates status for both clients" do
      {:ok, shared} = Shared.start_link()

      # Connect first client (this process receives for both IDs)
      :ok = Shared.connect(shared, "c1")
      assert receive_model().status == "1 connected"

      # Connect second client (same process, different ID)
      :ok = Shared.connect(shared, "c2")

      # Both clients receive "2 connected" -- since both map to
      # self(), we get the message twice
      assert receive_model().status == "2 connected"
      assert receive_model().status == "2 connected"
    end
  end

  describe "disconnect/2" do
    test "removes client and updates status" do
      {:ok, shared} = Shared.start_link()
      :ok = Shared.connect(shared, "c1")
      :ok = Shared.connect(shared, "c2")
      flush_models()

      Shared.disconnect(shared, "c2")

      # c1 (this process) receives the updated status
      model = receive_model()
      assert model.status == "1 connected"
    end
  end

  # -- Event handling ---------------------------------------------------------

  describe "event/3" do
    test "updates model and broadcasts to client" do
      {:ok, shared} = Shared.start_link()
      :ok = Shared.connect(shared, "c1")
      flush_models()

      Shared.event(shared, "c1", click("inc"))

      model = receive_model()
      assert model.count == 1
    end

    test "multiple events accumulate" do
      {:ok, shared} = Shared.start_link()
      :ok = Shared.connect(shared, "c1")
      flush_models()

      Shared.event(shared, "c1", click("inc"))
      Shared.event(shared, "c1", click("inc"))
      Shared.event(shared, "c1", click("inc"))

      # Drain to the last model
      model = receive_model()

      model =
        receive do
          {:model_changed, m} -> m
        after
          100 -> model
        end

      model =
        receive do
          {:model_changed, m} -> m
        after
          100 -> model
        end

      assert model.count == 3
    end

    test "text input updates broadcast to all clients" do
      {:ok, shared} = Shared.start_link()
      :ok = Shared.connect(shared, "c1")
      :ok = Shared.connect(shared, "c2")
      flush_models()

      Shared.event(shared, "c1", input("name", "Alice"))

      # Both clients receive it (both map to self())
      m1 = receive_model()
      m2 = receive_model()
      assert m1.name == "Alice"
      assert m2.name == "Alice"
    end
  end

  # -- Status preservation ----------------------------------------------------

  describe "status preservation" do
    test "status is preserved across app events" do
      {:ok, shared} = Shared.start_link()
      :ok = Shared.connect(shared, "c1")
      flush_models()

      # The app's update/2 doesn't touch status. The shared server
      # re-sets it after every event as a safety net.
      Shared.event(shared, "c1", click("inc"))

      model = receive_model()
      assert model.count == 1
      assert model.status == "1 connected"
    end

    test "status updates after disconnect even with active events" do
      {:ok, shared} = Shared.start_link()
      :ok = Shared.connect(shared, "c1")
      :ok = Shared.connect(shared, "c2")
      flush_models()

      Shared.event(shared, "c1", click("inc"))
      flush_models()

      Shared.disconnect(shared, "c2")

      model = receive_model()
      assert model.status == "1 connected"
      assert model.count == 1
    end
  end

  # -- Process monitoring -----------------------------------------------------

  describe "process monitoring" do
    test "client crash triggers automatic disconnect" do
      {:ok, shared} = Shared.start_link()

      # This process is the "survivor" client
      :ok = Shared.connect(shared, "survivor")
      assert receive_model().status == "1 connected"

      # Spawn a doomed client in a separate process
      doomed =
        spawn(fn ->
          :ok = Shared.connect(shared, "doomed")

          receive do
            :stop -> :ok
          end
        end)

      # Wait for doomed to connect -- survivor sees "2 connected"
      assert receive_model().status == "2 connected"
      # doomed's broadcast also arrives (mapped to a different pid, so not here)

      # Kill the doomed process
      Process.exit(doomed, :kill)

      # Survivor should see the disconnect
      assert receive_model().status == "1 connected"
    end
  end
end
