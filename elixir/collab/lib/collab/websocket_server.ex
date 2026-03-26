defmodule Collab.WebsocketServer do
  @moduledoc """
  WebSocket server with shared state.

  Serves the plushie-wasm browser app over HTTP and establishes
  WebSocket connections for each client. All clients share a single
  app model via a Collab.Shared GenServer. The server encodes
  snapshots and the browser's plushie-wasm decodes them.

  Architecture:
    Browser (plushie-wasm) <--WebSocket--> Bandit <--GenServer msg--> Shared
  """

  def start_http(shared, port) do
    Bandit.start_link(
      plug: {Collab.Router, shared: shared},
      port: port,
      ip: {127, 0, 0, 1}
    )
  end
end

defmodule Collab.Router do
  @moduledoc false

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/ws" do
    shared = conn.private[:shared]

    conn
    |> WebSockAdapter.upgrade(Collab.WsHandler, %{shared: shared}, [])
  end

  match _ do
    Collab.Static.serve(conn)
  end

  def init(opts), do: opts

  def call(conn, opts) do
    conn
    |> Plug.Conn.put_private(:shared, opts[:shared])
    |> super(opts)
  end
end

defmodule Collab.WsHandler do
  @moduledoc false

  @behaviour WebSock

  alias Plushie.Event.WidgetEvent

  @impl true
  def init(%{shared: shared}) do
    client_id = "ws-#{:erlang.unique_integer([:positive])}"
    Collab.Shared.connect(shared, client_id)

    {:ok,
     %{
       id: client_id,
       shared: shared,
       dark_mode: false,
       last_model: Collab.init([])
     }}
  end

  @impl true
  def handle_in({text, [opcode: :text]}, state) do
    case Plushie.Protocol.Decode.decode_message(text, :json) do
      # Dark mode toggle: handle locally (per-client, not shared)
      %WidgetEvent{type: :toggle, id: "theme", value: checked} ->
        state = %{state | dark_mode: checked}
        client_model = %{state.last_model | dark_mode: checked}
        {:push, {:text, encode_snapshot(client_model)}, state}

      # All other events: forward to shared actor
      %_{} = event ->
        Collab.Shared.event(state.shared, state.id, event)
        {:ok, state}

      {:hello, _} ->
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  def handle_in(_other, state), do: {:ok, state}

  @impl true
  def handle_info({:model_changed, model}, state) do
    state = %{state | last_model: model}
    client_model = %{model | dark_mode: state.dark_mode}
    {:push, {:text, encode_snapshot(client_model)}, state}
  end

  def handle_info(_msg, state), do: {:ok, state}

  @impl true
  def terminate(_reason, state) do
    Collab.Shared.disconnect(state.shared, state.id)
    :ok
  end

  # -- Internals --------------------------------------------------------------

  defp encode_snapshot(model) do
    tree = Collab.view(model)
    normalized = Plushie.Tree.normalize(tree)
    IO.iodata_to_binary(Plushie.Protocol.encode_snapshot(normalized, :json))
  end
end
