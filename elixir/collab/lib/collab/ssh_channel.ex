defmodule Collab.SshChannel do
  @moduledoc """
  SSH channel adapter implementing the plushie wire protocol.

  Each SSH connection spawns one of these. It registers with the
  Collab.Shared GenServer, decodes incoming protocol messages from
  the native plushie binary, and sends snapshot responses back
  over the SSH channel.

  Uses msgpack with 4-byte length-prefixed framing (the default
  wire format). The protocol handshake is:
  1. We send settings on channel open
  2. Renderer replies with hello
  3. We register with the shared GenServer (which sends the first snapshot)
  """

  @behaviour :ssh_server_channel

  alias Plushie.Event.WidgetEvent
  alias Plushie.Transport.Framing

  defstruct [
    :shared,
    :client_id,
    :conn,
    :channel,
    buffer: <<>>,
    dark_mode: false,
    handshake_done: false
  ]

  # -- ssh_server_channel callbacks -------------------------------------------

  @impl true
  def init([shared]) do
    client_id = "ssh-#{:erlang.unique_integer([:positive])}"
    {:ok, %__MODULE__{shared: shared, client_id: client_id}}
  end

  @impl true
  def handle_msg({:ssh_channel_up, channel, conn}, state) do
    state = %{state | conn: conn, channel: channel}
    send_settings(state)
    {:ok, state}
  end

  def handle_msg({:model_changed, model}, state) do
    if state.handshake_done do
      client_model = %{model | dark_mode: state.dark_mode}
      send_snapshot(client_model, state)
    end

    {:ok, state}
  end

  def handle_msg(_msg, state) do
    {:ok, state}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, _conn, {:data, _channel, 0, data}}, state) do
    combined = state.buffer <> data
    {frames, new_buffer} = Framing.decode_packets(combined)
    state = Enum.reduce(frames, state, &handle_frame/2)
    {:ok, %{state | buffer: new_buffer}}
  end

  def handle_ssh_msg({:ssh_cm, _conn, {:eof, _channel}}, state) do
    {:ok, state}
  end

  def handle_ssh_msg({:ssh_cm, _conn, {:closed, _channel}}, state) do
    disconnect(state)
    {:stop, state.channel, state}
  end

  def handle_ssh_msg(_msg, state) do
    {:ok, state}
  end

  @impl true
  def terminate(_reason, state) do
    disconnect(state)
    :ok
  end

  # -- Internals --------------------------------------------------------------

  defp disconnect(state) do
    if state.handshake_done do
      Collab.Shared.disconnect(state.shared, state.client_id)
    end
  end

  defp handle_frame(frame, state) do
    case Plushie.Protocol.Decode.decode_message(frame, :msgpack) do
      %WidgetEvent{type: :toggle, id: "theme", value: checked} ->
        %{state | dark_mode: checked}

      %_{} = event ->
        if state.handshake_done do
          Collab.Shared.event(state.shared, state.client_id, event)
        end

        state

      {:hello, _} ->
        # Renderer acknowledged our settings -- handshake complete
        Collab.Shared.connect(state.shared, state.client_id)
        %{state | handshake_done: true}

      _ ->
        state
    end
  end

  defp send_settings(state) do
    data =
      Plushie.Protocol.encode_settings(
        %{
          "antialiasing" => true,
          "default_text_size" => 16.0,
          "default_event_rate" => 30
        },
        :msgpack
      )

    packet = Framing.encode_packet(data)
    :ssh_connection.send(state.conn, state.channel, IO.iodata_to_binary(packet))
  end

  defp send_snapshot(model, state) do
    tree = Collab.view(model)
    normalized = Plushie.Tree.normalize(tree)
    data = Plushie.Protocol.encode_snapshot(normalized, :msgpack)
    packet = Framing.encode_packet(data)
    :ssh_connection.send(state.conn, state.channel, IO.iodata_to_binary(packet))
  end
end
