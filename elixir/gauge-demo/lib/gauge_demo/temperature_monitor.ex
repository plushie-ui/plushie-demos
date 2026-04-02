defmodule GaugeDemo.TemperatureMonitor do
  @moduledoc """
  Temperature monitor app using a native Rust gauge widget.

  Demonstrates:

  - Native widget (gauge rendered in Rust/iced)
  - Widget commands (`set_value`, `animate_to`)
  - Widget events (`{:gauge, :value_changed}` from Rust back to Elixir)
  - Optimistic updates with confirmed state
  - Settings with `widget_config`

  Run:

      mix plushie.gui GaugeDemo.TemperatureMonitor
  """

  use Plushie.App

  alias GaugeDemo.GaugeExtension, as: Gauge
  alias Plushie.Event.WidgetEvent

  defmodule Model do
    @moduledoc false

    @type t :: %__MODULE__{
            temperature: number(),
            target_temp: number(),
            history: [number()]
          }

    @enforce_keys [:temperature, :target_temp, :history]
    defstruct [:temperature, :target_temp, :history]
  end

  @max_history 50

  # -- Plushie.App callbacks --------------------------------------------------

  @impl true
  def init(_opts) do
    %Model{temperature: 20.0, target_temp: 20.0, history: [20.0]}
  end

  # Widget event: Rust gauge confirms the value change.
  # This is the only path that updates `temperature` -- button handlers
  # only update `target_temp` optimistically.
  @impl true
  def update(
        model,
        %WidgetEvent{type: {:gauge, :value_changed}, id: "temp", data: %{value: new_temp}}
      ) do
    %{model | temperature: new_temp, history: append_history(model.history, new_temp)}
  end

  # Slider: update target optimistically + animate the Rust gauge.
  def update(model, %WidgetEvent{type: :slide, id: "target", value: value}) do
    {%{model | target_temp: value}, Gauge.animate_to("temp", value)}
  end

  # Reset button: target to 20, command to Rust (which confirms via event).
  def update(model, %WidgetEvent{type: :click, id: "reset"}) do
    {%{model | target_temp: 20.0}, Gauge.set_value("temp", 20.0)}
  end

  # High button: target to 90, command to Rust (which confirms via event).
  def update(model, %WidgetEvent{type: :click, id: "high"}) do
    {%{model | target_temp: 90.0}, Gauge.set_value("temp", 90.0)}
  end

  def update(model, _event), do: model

  @impl true
  def view(model) do
    import Plushie.UI

    color = status_color(model.temperature)
    status = temperature_status(model.temperature)

    window "main", title: "Temperature Gauge" do
      column padding: 24, spacing: 16, align_x: :center do
        text("title", "Temperature Monitor", size: 24)

        Gauge.new("temp",
          value: model.temperature,
          min: 0,
          max: 100,
          color: color,
          label: "#{round(model.temperature)}\u00B0C",
          width: 200,
          height: 200,
          event_rate: 30
        )

        text("status", "Status: #{status}", color: color)

        text(
          "reading",
          "Current: #{round(model.temperature)}\u00B0C | " <>
            "Target: #{round(model.target_temp)}\u00B0C"
        )

        slider("target", {0, 100}, model.target_temp)

        row spacing: 8 do
          button("reset", "Reset (20\u00B0C)")
          button("high", "High (90\u00B0C)")
        end

        text(
          "history",
          "History: #{model.history |> Enum.map(&"#{round(&1)}\u00B0") |> Enum.join(", ")}",
          size: 12,
          color: "#999999"
        )
      end
    end
  end

  @impl true
  def settings do
    [
      widget_config: %{
        "gauge" => %{"arcWidth" => 8, "tickCount" => 10}
      }
    ]
  end

  # -- Pure helpers (public for testing) --------------------------------------

  @doc false
  @spec temperature_status(number()) :: String.t()
  def temperature_status(temp) when temp >= 80, do: "Critical"
  def temperature_status(temp) when temp >= 60, do: "Warning"
  def temperature_status(temp) when temp >= 40, do: "Normal"
  def temperature_status(_temp), do: "Cool"

  @doc false
  @spec status_color(number()) :: String.t()
  def status_color(temp) when temp >= 80, do: "#e74c3c"
  def status_color(temp) when temp >= 60, do: "#e67e22"
  def status_color(temp) when temp >= 40, do: "#27ae60"
  def status_color(_temp), do: "#3498db"

  @spec append_history([number()], number()) :: [number()]
  defp append_history(history, value) do
    (history ++ [value]) |> Enum.take(-@max_history)
  end
end
