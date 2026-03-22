defmodule Collab do
  @moduledoc """
  Shared collab app definition used by all demo modes.

  Follows the Elm architecture: init/update/view with immutable
  model updates. The same code runs in native desktop, WebSocket
  shared-state, and SSH modes.

  In collaborative modes (WebSocket, SSH), `name`, `notes`, and
  `count` are shared across all connected clients. The `dark_mode`
  toggle is per-client -- each user picks their own theme. The
  `status` field is set externally by the server adapter to show
  the current connection count.
  """

  use Plushie.App

  alias Plushie.Event.Widget

  def init(_opts) do
    %{name: "", notes: "", count: 0, dark_mode: false, status: ""}
  end

  def update(model, %Widget{type: :click, id: "inc"}),
    do: %{model | count: model.count + 1}

  def update(model, %Widget{type: :click, id: "dec"}),
    do: %{model | count: model.count - 1}

  def update(model, %Widget{type: :input, id: "name", value: value}),
    do: %{model | name: value}

  def update(model, %Widget{type: :input, id: "notes", value: value}),
    do: %{model | notes: value}

  def update(model, %Widget{type: :toggle, id: "theme", value: checked}),
    do: %{model | dark_mode: checked}

  def update(model, _event), do: model

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

  def settings, do: [default_event_rate: 30]
end
