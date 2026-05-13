defmodule Collab do
  @moduledoc """
  Shared collab app definition used by all demo modes.

  Follows the Elm architecture: init/update/view with immutable
  model updates. The same code runs in native desktop, WebSocket
  shared-state, and SSH modes.

  In collaborative modes (WebSocket, SSH), `name`, `notes`, and
  `count` are shared across all connected clients. The `dark_mode`
  toggle is per-client (kept in the local Runtime's model, preserved
  across broadcasts). The `status` field is set by the shared server
  to show the current connection count.

  In shared mode, user events are forwarded to `Collab.Shared` which
  runs `update/2` centrally and broadcasts the result to all client
  runtimes via `Plushie.Runtime.dispatch/2`. The local runtime
  handles `Collab.Broadcast` events by replacing shared fields while
  preserving per-client state (dark_mode).
  """

  use Plushie.App

  alias Plushie.Event.WidgetEvent

  defmodule Model do
    @moduledoc """
    Collab app state.

    - `name`, `notes`, `count` - shared across all connected clients
    - `dark_mode` - per-client (preserved across broadcasts)
    - `status` - set by the shared server (connection count)
    - `client_id` - this client's ID (nil in standalone mode)
    - `shared` - PID of the shared server (nil in standalone mode)
    """

    @type t :: %__MODULE__{
            name: String.t(),
            notes: String.t(),
            count: integer(),
            dark_mode: boolean(),
            status: String.t(),
            client_id: String.t() | nil,
            shared: pid() | nil
          }

    @enforce_keys [:name, :notes, :count, :dark_mode, :status]
    defstruct [:name, :notes, :count, :dark_mode, :status, :client_id, :shared]
  end

  @impl true
  def init(opts) do
    case Keyword.get(opts, :shared_model) do
      nil ->
        %Model{name: "", notes: "", count: 0, dark_mode: false, status: ""}

      shared_model ->
        # Seed from the shared server's authoritative state
        client_id = Keyword.get(opts, :client_id)
        shared = Keyword.get(opts, :shared)

        %{shared_model | dark_mode: false, client_id: client_id, shared: shared}
    end
  end

  @impl true
  def update(model, %Collab.Broadcast{model: shared_model, originator_id: originator_id}) do
    if originator_id == model.client_id and originator_id != nil do
      # We originated this event, our model is already up to date
      # (except for status which the shared server manages)
      %{model | status: shared_model.status}
    else
      # Replace shared fields, preserve per-client state
      %{
        shared_model
        | dark_mode: model.dark_mode,
          client_id: model.client_id,
          shared: model.shared
      }
    end
  end

  def update(model, %WidgetEvent{type: :click, id: "inc"} = event) do
    maybe_forward(model, event)
    %{model | count: model.count + 1}
  end

  def update(model, %WidgetEvent{type: :click, id: "dec"} = event) do
    maybe_forward(model, event)
    %{model | count: model.count - 1}
  end

  def update(model, %WidgetEvent{type: :input, id: "name", value: value} = event) do
    maybe_forward(model, event)
    %{model | name: value}
  end

  def update(model, %WidgetEvent{type: :input, id: "notes", value: value} = event) do
    maybe_forward(model, event)
    %{model | notes: value}
  end

  # Dark mode is per-client, never forwarded to shared server
  def update(model, %WidgetEvent{type: :toggle, id: "theme", value: checked}),
    do: %{model | dark_mode: checked}

  def update(model, _event), do: model

  @impl true
  def view(model) do
    import Plushie.UI

    theme = if model.dark_mode, do: :dark, else: :light

    window "main", title: "Plushie Demo", size: {500, 450} do
      themer "theme-root", theme: theme do
        container "bg", width: :fill, height: :fill do
          column padding: 20, spacing: 16, width: :fill do
            text("header", "Plushie Demo", size: 24)
            text("status", model.status)
            text_input("name", model.name, placeholder: "Your name")

            row id: "counter-row", spacing: 8 do
              button("dec", "-")
              text("count", "Count: #{model.count}")
              button("inc", "+")
            end

            checkbox("theme", model.dark_mode, label: "Dark mode")

            text_input("notes", model.notes,
              placeholder: "Shared notes...",
              width: :fill
            )
          end
        end
      end
    end
  end

  @impl true
  def settings, do: %{default_event_rate: 30}

  # In shared mode, forward events to the shared server for broadcast.
  # In standalone mode, this is a no-op.
  defp maybe_forward(%Model{shared: nil}, _event), do: :ok

  defp maybe_forward(%Model{shared: shared, client_id: client_id}, event) do
    Collab.Shared.event(shared, client_id, event)
  end
end
