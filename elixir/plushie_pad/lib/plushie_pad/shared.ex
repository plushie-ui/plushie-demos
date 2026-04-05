defmodule PlushiePad.Shared do
  @moduledoc """
  Shared state server for collaborative PlushiePad.

  Holds the authoritative model and a registry of connected clients.
  Each client is a `Plushie.Runtime` process. When any client sends
  an event, the server runs `update/2` with error isolation, updates
  the authoritative model, and broadcasts the new state to all
  clients via `Plushie.Runtime.dispatch/2`.

  Broadcasts use `PlushiePad.Broadcast` structs so the app's
  `update/2` can pattern match and replace its local model.
  """

  use GenServer

  require Logger

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, :ok, opts)

  @doc "Returns the current authoritative model."
  @spec get_model(GenServer.server()) :: map()
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

  @doc "Forward an event from a client. Runs update/2 and broadcasts."
  @spec event(GenServer.server(), Plushie.Event.t()) :: :ok
  def event(server, event) do
    GenServer.cast(server, {:event, event})
  end

  @impl true
  def init(:ok) do
    {:ok, %{model: PlushiePad.init([]), clients: %{}}}
  end

  @impl true
  def handle_call(:get_model, _from, state) do
    {:reply, state.model, state}
  end

  @impl true
  def handle_call({:connect, id, runtime}, _from, state) do
    Process.monitor(runtime)
    clients = Map.put(state.clients, id, runtime)
    {:reply, :ok, %{state | clients: clients}}
  end

  @impl true
  def handle_cast({:disconnect, id}, state) do
    {:noreply, %{state | clients: Map.delete(state.clients, id)}}
  end

  @impl true
  def handle_cast({:event, event}, state) do
    case safe_update(state.model, event) do
      {:ok, model} ->
        broadcast(state.clients, model)
        {:noreply, %{state | model: model}}

      :error ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    clients =
      state.clients
      |> Enum.reject(fn {_id, p} -> p == pid end)
      |> Map.new()

    {:noreply, %{state | clients: clients}}
  end

  defp safe_update(model, event) do
    try do
      result = PlushiePad.update(model, event)

      model =
        case result do
          {new_model, _commands} -> new_model
          new_model -> new_model
        end

      {:ok, model}
    rescue
      e ->
        Logger.error("PlushiePad.Shared: update/2 crashed: #{Exception.message(e)}")
        :error
    end
  end

  defp broadcast(clients, model) do
    event = %PlushiePad.Broadcast{model: model}

    Enum.each(clients, fn {_id, runtime} ->
      Plushie.Runtime.dispatch(runtime, event)
    end)
  end
end
