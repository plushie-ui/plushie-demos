defmodule Collab.Shared do
  @moduledoc """
  Shared state server for collaborative modes.

  Holds the authoritative model and a set of connected clients.
  When any client sends an event, the server runs update(), re-renders
  the view, and broadcasts the new model to ALL connected clients.

  The `status` field is managed by this server (not the app). It
  tracks the current connection count and is re-set after every
  event and connect/disconnect.
  """

  use GenServer

  # -- Public API -------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc "Register a client. The caller receives `{:model_changed, model}` messages."
  @spec connect(GenServer.server(), String.t()) :: :ok
  def connect(server, client_id) do
    GenServer.call(server, {:connect, client_id, self()})
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

  # -- GenServer callbacks ----------------------------------------------------

  @impl true
  def init(:ok) do
    model = Collab.init([])
    {:ok, %{model: model, clients: %{}}}
  end

  @impl true
  def handle_call({:connect, id, pid}, _from, state) do
    Process.monitor(pid)
    clients = Map.put(state.clients, id, pid)
    model = %{state.model | status: status_text(clients)}

    broadcast(clients, model)
    {:reply, :ok, %{state | model: model, clients: clients}}
  end

  @impl true
  def handle_cast({:disconnect, id}, state) do
    clients = Map.delete(state.clients, id)
    model = %{state.model | status: status_text(clients)}

    broadcast(clients, model)
    {:noreply, %{state | model: model, clients: clients}}
  end

  @impl true
  def handle_cast({:event, _id, event}, state) do
    new_model = Collab.update(state.model, event)
    # Preserve status (managed by the server, not the app)
    new_model = %{new_model | status: status_text(state.clients)}

    broadcast(state.clients, new_model)
    {:noreply, %{state | model: new_model}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    case Enum.find(state.clients, fn {_id, p} -> p == pid end) do
      {id, _pid} ->
        clients = Map.delete(state.clients, id)
        model = %{state.model | status: status_text(clients)}

        broadcast(clients, model)
        {:noreply, %{state | model: model, clients: clients}}

      nil ->
        {:noreply, state}
    end
  end

  # -- Internals --------------------------------------------------------------

  @spec broadcast(%{String.t() => pid()}, Collab.Model.t()) :: :ok
  defp broadcast(clients, model) do
    Enum.each(clients, fn {_id, pid} ->
      send(pid, {:model_changed, model})
    end)
  end

  @spec status_text(%{String.t() => pid()}) :: String.t()
  defp status_text(clients) do
    count = map_size(clients)
    "#{count} connected"
  end
end
