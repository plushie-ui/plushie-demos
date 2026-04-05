defmodule Collab.WebsocketServer do
  @moduledoc """
  WebSocket server with shared state.

  Serves the plushie-wasm browser app over HTTP and establishes
  WebSocket connections for each client. Each client gets a dedicated
  `Plushie.Runtime` for rendering (tree diffing, patching) and shares
  state via `Collab.Shared` for coordination.

  Security:
  - Origin checking against allowed origins
  - Rate limiting (max messages per second per client)
  - Invalid messages are logged
  """

  @default_allowed_origins ["http://localhost", "http://127.0.0.1"]

  def start_http(shared, port, opts \\ []) do
    allowed_origins =
      Keyword.get(opts, :allowed_origins, @default_allowed_origins)

    Bandit.start_link(
      plug: {Collab.Router, shared: shared, allowed_origins: allowed_origins},
      port: port,
      ip: {127, 0, 0, 1}
    )
  end
end

defmodule Collab.Router do
  @moduledoc false

  use Plug.Router

  require Logger

  plug(:match)
  plug(:dispatch)

  get "/ws" do
    shared = conn.private[:shared]
    allowed_origins = conn.private[:allowed_origins] || []

    origin = Plug.Conn.get_req_header(conn, "origin") |> List.first()

    if origin_allowed?(origin, allowed_origins) do
      conn
      |> WebSockAdapter.upgrade(Collab.WsHandler, %{shared: shared}, [])
    else
      Logger.warning("collab: rejected WebSocket from origin: #{inspect(origin)}")
      Plug.Conn.send_resp(conn, 403, "Forbidden")
    end
  end

  match _ do
    Collab.Static.serve(conn)
  end

  def init(opts), do: opts

  def call(conn, opts) do
    conn
    |> Plug.Conn.put_private(:shared, opts[:shared])
    |> Plug.Conn.put_private(:allowed_origins, opts[:allowed_origins])
    |> super(opts)
  end

  defp origin_allowed?(nil, _allowed), do: true
  defp origin_allowed?(_origin, []), do: true

  defp origin_allowed?(origin, allowed) do
    Enum.any?(allowed, fn allowed_origin ->
      String.starts_with?(origin, allowed_origin)
    end)
  end
end

defmodule Collab.WsHandler do
  @moduledoc false

  @behaviour WebSock

  require Logger

  @max_messages_per_second 100
  @rate_window_ms 1_000

  @impl true
  def init(%{shared: shared}) do
    client_id = "ws-#{:erlang.unique_integer([:positive])}"

    # Fetch authoritative model
    model = Collab.Shared.get_model(shared)

    # Start a Plushie supervisor with this handler as iostream adapter.
    # For WebSocket, the wire format is JSON (browser-compatible).
    plushie_name = :"collab_ws_#{client_id}"

    {:ok, sup} =
      Plushie.start_link(Collab,
        name: plushie_name,
        transport: {:iostream, self()},
        format: :json,
        daemon: true,
        app_opts: [
          shared_model: model,
          client_id: client_id,
          shared: shared
        ]
      )

    runtime = Plushie.runtime_for(plushie_name)
    Collab.Shared.connect(shared, client_id, runtime)

    {:ok,
     %{
       id: client_id,
       shared: shared,
       bridge: nil,
       plushie_sup: sup,
       message_count: 0,
       rate_window_start: System.monotonic_time(:millisecond)
     }}
  end

  @impl true
  def handle_in({text, [opcode: :text]}, state) do
    case check_rate_limit(state) do
      {:ok, state} ->
        # Forward to Bridge, which will decode and send to Runtime
        if state.bridge, do: send(state.bridge, {:iostream_data, text})
        {:ok, state}

      {:rate_limited, state} ->
        Logger.warning("collab: rate limited client #{state.id}")
        {:ok, state}
    end
  end

  def handle_in({data, _opts}, state) do
    Logger.warning("collab: invalid message from #{state.id}: #{inspect(data, limit: 100)}")
    {:ok, state}
  end

  @impl true
  def handle_info({:iostream_bridge, bridge_pid}, state) do
    {:ok, %{state | bridge: bridge_pid}}
  end

  # Bridge sends encoded data to the browser client
  def handle_info({:iostream_send, data}, state) do
    {:push, {:text, IO.iodata_to_binary(data)}, state}
  end

  def handle_info({:iostream_closed, reason}, state) do
    Logger.info("collab: iostream closed for #{state.id}: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  def handle_info(_msg, state), do: {:ok, state}

  @impl true
  def terminate(_reason, state) do
    Collab.Shared.disconnect(state.shared, state.id)

    if state.bridge do
      send(state.bridge, {:iostream_closed, :ws_closed})
    end

    if state.plushie_sup do
      try do
        Plushie.stop(state.plushie_sup)
      catch
        :exit, _ -> :ok
      end
    end

    :ok
  end

  defp check_rate_limit(state) do
    now = System.monotonic_time(:millisecond)
    elapsed = now - state.rate_window_start

    if elapsed >= @rate_window_ms do
      {:ok, %{state | message_count: 1, rate_window_start: now}}
    else
      if state.message_count >= @max_messages_per_second do
        {:rate_limited, state}
      else
        {:ok, %{state | message_count: state.message_count + 1}}
      end
    end
  end
end
