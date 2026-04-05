defmodule PlushiePad.SshChannel do
  @moduledoc """
  SSH channel iostream adapter for collaborative PlushiePad.

  Each SSH connection gets a dedicated `Plushie.Runtime` for rendering
  (tree diffing, patching, subscriptions) and a connection to the
  shared GenServer for state coordination.

  Incoming wire data is decoded. Handshake messages (hello) are
  forwarded to the Bridge. User events are forwarded to the shared
  server, which runs `update/2` and broadcasts the result to all
  client runtimes via `Runtime.dispatch/2`.

  Wire protocol: MessagePack with 4-byte length-prefixed framing.
  """

  @behaviour :ssh_server_channel

  alias Plushie.Transport.Framing

  defstruct [
    :shared,
    :client_id,
    :conn,
    :channel,
    :bridge,
    :plushie_sup,
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

    # Fetch authoritative model to seed the client's init
    model = PlushiePad.Shared.get_model(state.shared)

    # Start a Plushie supervisor with this channel as iostream adapter.
    # The Bridge will send settings to the renderer and handle the
    # handshake automatically.
    plushie_name = :"plushie_pad_#{state.client_id}"

    {:ok, sup} =
      Plushie.start_link(PlushiePad,
        name: plushie_name,
        transport: {:iostream, self()},
        format: :msgpack,
        daemon: true,
        app_opts: [shared_model: model]
      )

    # Register the runtime so shared server can broadcast to it
    runtime = Plushie.runtime_for(plushie_name)
    PlushiePad.Shared.connect(state.shared, state.client_id, runtime)

    {:ok, %{state | plushie_sup: sup}}
  end

  # iostream protocol: Bridge registers itself
  def handle_msg({:iostream_bridge, bridge_pid}, state) do
    {:ok, %{state | bridge: bridge_pid}}
  end

  # iostream protocol: Bridge sends encoded data to the renderer (SSH client)
  def handle_msg({:iostream_send, data}, state) do
    packet = Framing.encode_packet(data) |> IO.iodata_to_binary()
    :ssh_connection.send(state.conn, state.channel, packet)
    {:ok, state}
  end

  def handle_msg(_msg, state), do: {:ok, state}

  @impl true
  def handle_ssh_msg({:ssh_cm, _conn, {:data, _channel, 0, data}}, state) do
    combined = state.buffer <> data
    {frames, buffer} = Framing.decode_packets(combined)
    state = Enum.reduce(frames, state, &handle_frame/2)
    {:ok, %{state | buffer: buffer}}
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

  defp handle_frame(frame, state) do
    case Plushie.Protocol.Decode.decode_message(frame, :msgpack) do
      {:hello, _} ->
        # Handshake: forward to Bridge so the Runtime can initialize
        if state.bridge, do: send(state.bridge, {:iostream_data, frame})
        state

      %_{} = event ->
        # User events go to the shared server, not the local Runtime.
        # Shared will run update/2 and broadcast the result to all runtimes.
        PlushiePad.Shared.event(state.shared, event)
        state

      _ ->
        # Other messages (shouldn't happen normally): forward to Bridge
        if state.bridge, do: send(state.bridge, {:iostream_data, frame})
        state
    end
  end

  defp cleanup(state) do
    PlushiePad.Shared.disconnect(state.shared, state.client_id)

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
