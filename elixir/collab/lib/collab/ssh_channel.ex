defmodule Collab.SshChannel do
  @moduledoc """
  SSH channel iostream adapter for the collaborative demo.

  Each SSH connection gets a dedicated `Plushie.Runtime` that handles
  the full SDK pipeline (rendering, tree diffing, patching,
  subscriptions). This channel acts as a transparent iostream adapter,
  forwarding bytes between the SSH transport and the Bridge.

  Events flow through the local Runtime's `update/2`, which forwards
  shared events to `Collab.Shared`. The shared server broadcasts model
  changes to all client runtimes via `Runtime.dispatch/2`.

  Wire protocol: MessagePack with 4-byte length-prefixed framing.
  """

  @behaviour :ssh_server_channel

  alias Plushie.Transport.Framing

  @handshake_timeout 15_000

  defstruct [
    :shared,
    :client_id,
    :conn,
    :channel,
    :bridge,
    :plushie_sup,
    :handshake_timer,
    buffer: <<>>
  ]

  @impl true
  def init([shared]) do
    client_id = "ssh-#{:erlang.unique_integer([:positive])}"
    {:ok, %__MODULE__{shared: shared, client_id: client_id}}
  end

  @impl true
  def handle_msg({:ssh_channel_up, channel, conn}, state) do
    state = %{state | conn: conn, channel: channel}

    # Start handshake timeout
    timer = Process.send_after(self(), :handshake_timeout, @handshake_timeout)

    # Fetch authoritative model to seed the client's init
    model = Collab.Shared.get_model(state.shared)

    # Start a Plushie supervisor with this channel as iostream adapter.
    # The Bridge drives the settings/hello handshake automatically.
    plushie_name = :"collab_#{state.client_id}"

    {:ok, sup} =
      Plushie.start_link(Collab,
        name: plushie_name,
        transport: {:iostream, self()},
        format: :msgpack,
        daemon: true,
        app_opts: [
          shared_model: model,
          client_id: state.client_id,
          shared: state.shared
        ]
      )

    # Register the runtime for broadcast delivery
    runtime = Plushie.runtime_for(plushie_name)
    Collab.Shared.connect(state.shared, state.client_id, runtime)

    {:ok, %{state | plushie_sup: sup, handshake_timer: timer}}
  end

  # iostream protocol: Bridge registers itself
  def handle_msg({:iostream_bridge, bridge_pid}, state) do
    {:ok, %{state | bridge: bridge_pid}}
  end

  # iostream protocol: Bridge sends encoded data to the renderer (SSH client)
  def handle_msg({:iostream_send, data}, state) do
    # Cancel handshake timer on first outgoing data (Bridge is alive)
    state =
      if state.handshake_timer do
        Process.cancel_timer(state.handshake_timer)
        %{state | handshake_timer: nil}
      else
        state
      end

    packet = Framing.encode_packet(data) |> IO.iodata_to_binary()
    :ssh_connection.send(state.conn, state.channel, packet)
    {:ok, state}
  end

  # Handshake timeout
  def handle_msg(:handshake_timeout, state) do
    cleanup(state)
    {:stop, state.channel, state}
  end

  def handle_msg(_msg, state), do: {:ok, state}

  @impl true
  # Maximum accumulated buffer size (64 MiB, matching bridge.ex).
  @max_buffer_size 64 * 1024 * 1024

  def handle_ssh_msg({:ssh_cm, _conn, {:data, _channel, 0, data}}, state) do
    combined = state.buffer <> data

    if byte_size(combined) > @max_buffer_size do
      require Logger
      Logger.error("collab SSH: buffer exceeded #{@max_buffer_size} bytes, dropping")
      {:ok, %{state | buffer: <<>>}}
    else
      {frames, buffer} = Framing.decode_packets(combined)

      Enum.each(frames, fn frame ->
        if state.bridge, do: send(state.bridge, {:iostream_data, frame})
      end)

      {:ok, %{state | buffer: buffer}}
    end
  end

  def handle_ssh_msg({:ssh_cm, _conn, {:eof, _channel}}, state) do
    {:ok, state}
  end

  def handle_ssh_msg({:ssh_cm, _conn, {:closed, _channel}}, state) do
    cleanup(state)
    {:stop, state.channel, state}
  end

  def handle_ssh_msg(_msg, state), do: {:ok, state}

  @impl true
  def terminate(_reason, state) do
    cleanup(state)
    :ok
  end

  defp cleanup(state) do
    if state.handshake_timer, do: Process.cancel_timer(state.handshake_timer)

    Collab.Shared.disconnect(state.shared, state.client_id)

    if state.bridge do
      send(state.bridge, {:iostream_closed, :ssh_closed})
    end

    if state.plushie_sup do
      try do
        Plushie.stop(state.plushie_sup)
      catch
        :exit, _ -> :ok
      end
    end
  end
end
