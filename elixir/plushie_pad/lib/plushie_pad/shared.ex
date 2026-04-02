defmodule PlushiePad.Shared do
  use GenServer

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, :ok, opts)

  def connect(server, client_id),
    do: GenServer.call(server, {:connect, client_id, self()})

  def disconnect(server, client_id),
    do: GenServer.cast(server, {:disconnect, client_id})

  def event(server, event),
    do: GenServer.cast(server, {:event, event})

  @impl true
  def init(:ok) do
    {:ok, %{model: PlushiePad.init([]), clients: %{}}}
  end

  @impl true
  def handle_call({:connect, id, pid}, _from, state) do
    Process.monitor(pid)
    clients = Map.put(state.clients, id, pid)
    broadcast(clients, state.model)
    {:reply, :ok, %{state | clients: clients}}
  end

  @impl true
  def handle_cast({:disconnect, id}, state) do
    {:noreply, %{state | clients: Map.delete(state.clients, id)}}
  end

  @impl true
  def handle_cast({:event, event}, state) do
    model = PlushiePad.update(state.model, event)
    broadcast(state.clients, model)
    {:noreply, %{state | model: model}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    clients =
      state.clients
      |> Enum.reject(fn {_id, p} -> p == pid end)
      |> Map.new()

    {:noreply, %{state | clients: clients}}
  end

  defp broadcast(clients, model) do
    Enum.each(clients, fn {_id, pid} ->
      send(pid, {:model_changed, model})
    end)
  end
end
