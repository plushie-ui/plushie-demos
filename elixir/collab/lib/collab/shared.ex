defmodule Collab.Shared do
  @moduledoc """
  Shared state server for collaborative modes.

  Holds the authoritative model and a registry of connected client
  runtimes. When any client sends an event, the server runs update/2
  with error isolation, updates the authoritative model, and
  broadcasts the new state to all clients via `Runtime.dispatch/2`.

  The `status` field is managed by this server (connection count).
  Per-client state (dark_mode) lives in each client's local Runtime
  and is preserved across broadcasts.
  """

  use GenServer

  require Logger

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc "Returns the current authoritative model."
  @spec get_model(GenServer.server()) :: Collab.Model.t()
  def get_model(server) do
    GenServer.call(server, :get_model)
  end

  @doc "Register a client runtime for broadcast delivery."
  @spec connect(GenServer.server(), String.t(), pid()) :: :ok
  def connect(server, client_id, runtime) do
    GenServer.call(server, {:connect, client_id, runtime})
  end

  @doc "Unregister a client."
  @spec disconnect(GenServer.server(), String.t()) :: :ok
  def disconnect(server, client_id) do
    GenServer.cast(server, {:disconnect, client_id})
  end

  @doc "Forward a widget event from a client."
  @spec event(GenServer.server(), String.t(), Plushie.Event.t()) :: :ok
  def event(server, client_id, event) do
    GenServer.cast(server, {:event, client_id, event})
  end

  @impl true
  def init(:ok) do
    model = Collab.init([])
    {:ok, %{model: model, clients: %{}}}
  end

  @impl true
  def handle_call(:get_model, _from, state) do
    {:reply, state.model, state}
  end

  @impl true
  def handle_call({:connect, id, runtime}, _from, state) do
    Process.monitor(runtime)
    clients = Map.put(state.clients, id, runtime)
    model = %{state.model | status: status_text(clients)}

    # Broadcast updated status to all clients (including the new one,
    # which will get the status via its init model and this broadcast)
    broadcast(clients, model, nil)
    {:reply, :ok, %{state | model: model, clients: clients}}
  end

  @impl true
  def handle_cast({:disconnect, id}, state) do
    clients = Map.delete(state.clients, id)
    model = %{state.model | status: status_text(clients)}

    broadcast(clients, model, nil)
    {:noreply, %{state | model: model, clients: clients}}
  end

  @impl true
  def handle_cast({:event, client_id, event}, state) do
    case safe_update(state.model, event) do
      {:ok, new_model} ->
        model = %{new_model | status: status_text(state.clients)}
        broadcast(state.clients, model, client_id)
        {:noreply, %{state | model: model}}

      :error ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    case Enum.find(state.clients, fn {_id, p} -> p == pid end) do
      {id, _pid} ->
        clients = Map.delete(state.clients, id)
        model = %{state.model | status: status_text(clients)}

        broadcast(clients, model, nil)
        {:noreply, %{state | model: model, clients: clients}}

      nil ->
        {:noreply, state}
    end
  end

  defp safe_update(model, event) do
    try do
      result = Collab.update(model, event)

      model =
        case result do
          {new_model, _commands} -> new_model
          new_model -> new_model
        end

      {:ok, model}
    rescue
      e ->
        Logger.error("Collab.Shared: update/2 crashed: #{Exception.message(e)}")
        :error
    end
  end

  @spec broadcast(%{String.t() => pid()}, Collab.Model.t(), String.t() | nil) :: :ok
  defp broadcast(clients, model, originator_id) do
    event = %Collab.Broadcast{model: model, originator_id: originator_id}

    Enum.each(clients, fn {_id, runtime} ->
      Plushie.Runtime.dispatch(runtime, event)
    end)
  end

  @spec status_text(%{String.t() => pid()}) :: String.t()
  defp status_text(clients) do
    count = map_size(clients)
    "#{count} connected"
  end
end
