defmodule CrashTest.App do
  @moduledoc """
  Crash resilience demo -- deliberately crashes Elixir handlers and
  a Rust extension to show how the framework recovers.

  A working counter proves the app keeps functioning through all crashes.

  Run:

      mix plushie.gui CrashTest.App
  """

  use Plushie.App

  alias CrashTest.CrashExtension
  alias Plushie.Event.WidgetEvent

  defmodule Model do
    @moduledoc false

    @type t :: %__MODULE__{
            count: integer(),
            crash_view: boolean()
          }

    @enforce_keys [:count, :crash_view]
    defstruct [:count, :crash_view]
  end

  # -- Plushie.App callbacks --------------------------------------------------

  @impl true
  def init(_opts) do
    %Model{count: 0, crash_view: false}
  end

  # -- Working counter (proof of life) --

  @impl true
  def update(model, %WidgetEvent{type: :click, id: "inc"}),
    do: %{model | count: model.count + 1}

  def update(model, %WidgetEvent{type: :click, id: "dec"}),
    do: %{model | count: model.count - 1}

  # -- Deliberate crash in update/2 --
  # The runtime catches this and rolls back the model.

  def update(_model, %WidgetEvent{type: :click, id: "crash_update"}) do
    raise "Deliberate crash in update/2 -- the runtime catches this and rolls back the model"
  end

  # -- Trigger crash in view/1 --
  # Sets a flag that causes the NEXT view/1 call to raise.
  # The runtime catches the view crash and rolls back the model,
  # clearing the flag -- so it's a one-shot crash.

  def update(model, %WidgetEvent{type: :click, id: "crash_view"}) do
    %{model | crash_view: true}
  end

  # -- Panic the Rust extension --
  # Sends a command that calls panic!() in handle_command.
  # The renderer isolates it via catch_unwind and shows a red placeholder.

  def update(model, %WidgetEvent{type: :click, id: "panic_widget"}) do
    {model, CrashExtension.panic("crash_ext")}
  end

  def update(model, _event), do: model

  @impl true
  def view(%Model{crash_view: true}) do
    raise "Deliberate crash in view/1 -- the runtime catches this and shows the previous tree"
  end

  def view(model) do
    import Plushie.UI

    window "main", title: "Crash Test", size: {520, 560} do
      column padding: 20, spacing: 20, width: :fill do
        text("title", "Crash Test", size: 24)

        # -- Working counter (proof of life) --
        row spacing: 12 do
          text("count", "Count: #{model.count}", size: 18)
          button("inc", "+")
          button("dec", "-")
        end

        text("counter_hint", "This counter keeps working through every crash below.",
          size: 12,
          color: "#888888"
        )

        rule()

        # -- Elixir update crash --
        column spacing: 4 do
          button("crash_update", "Crash update/2")

          text(
            "crash_update_desc",
            "Raises RuntimeError in update/2. The runtime catches it " <>
              "and rolls back the model to its pre-exception state.",
            size: 12,
            color: "#888888"
          )
        end

        # -- Elixir view crash --
        column spacing: 4 do
          button("crash_view", "Crash view/1")

          text(
            "crash_view_desc",
            "Sets a flag that raises on the next render. The runtime " <>
              "catches it, shows the previous tree, and rolls back the " <>
              "model (clearing the flag). One-shot crash.",
            size: 12,
            color: "#888888"
          )
        end

        rule()

        # -- Rust extension panic --
        column spacing: 4 do
          button("panic_widget", "Panic extension")

          text(
            "panic_desc",
            "Sends a command that panics the Rust extension's " <>
              "handle_command. The renderer isolates it via catch_unwind " <>
              "and replaces the widget with a red placeholder.",
            size: 12,
            color: "#888888"
          )
        end

        CrashExtension.new("crash_ext", label: "Widget OK")
      end
    end
  end
end
