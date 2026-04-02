defmodule PlushiePad.SshChannel do
  @behaviour :ssh_server_channel

  alias Plushie.Event.WidgetEvent
  alias Plushie.Transport.Framing

  defstruct [:shared, :client_id, :conn, :channel, buffer: <<>>, handshake_done: false]

  @impl true
  def init([shared]) do
    {:ok, %__MODULE__{shared: shared, client_id: "ssh-#{:erlang.unique_integer([:positive])}"}}
  end

  @impl true
  def handle_msg({:ssh_channel_up, channel, conn}, state) do
    state = %{state | conn: conn, channel: channel}

    settings =
      Plushie.Protocol.encode_settings(
        %{"antialiasing" => true, "default_text_size" => 16.0},
        :msgpack
      )

    send_packet(state, settings)
    {:ok, state}
  end

  def handle_msg({:model_changed, model}, state) do
    if state.handshake_done, do: send_snapshot(model, state)
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

  def handle_ssh_msg({:ssh_cm, _conn, {:closed, _channel}}, state) do
    {:stop, state.channel, state}
  end

  def handle_ssh_msg(_msg, state), do: {:ok, state}

  @impl true
  def terminate(_reason, state) do
    if state.handshake_done,
      do: PlushiePad.Shared.disconnect(state.shared, state.client_id)

    :ok
  end

  defp handle_frame(frame, state) do
    case Plushie.Protocol.decode_message(frame, :msgpack) do
      {:hello, _} ->
        PlushiePad.Shared.connect(state.shared, state.client_id)
        %{state | handshake_done: true}

      %WidgetEvent{} = event ->
        if state.handshake_done,
          do: PlushiePad.Shared.event(state.shared, event)

        state

      _ ->
        state
    end
  end

  defp send_snapshot(model, state) do
    tree = PlushiePad.view(model) |> Plushie.Tree.normalize()
    data = Plushie.Protocol.encode_snapshot(tree, :msgpack)
    send_packet(state, data)
  end

  defp send_packet(state, data) do
    packet = Framing.encode_packet(data) |> IO.iodata_to_binary()
    :ssh_connection.send(state.conn, state.channel, packet)
  end
end
