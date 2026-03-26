defmodule SparklineDashboard.Dashboard do
  @moduledoc """
  Live dashboard with sparkline charts for simulated system metrics.

  Demonstrates:

  - Native widget extension (sparkline rendered in Rust/iced canvas)
  - Timer subscriptions for live data updates
  - Render-only extension (no commands or events)
  - Conditional subscriptions based on model state
  - Multiple instances of the same extension widget

  Run:

      mix plushie.gui SparklineDashboard.Dashboard
  """

  use Plushie.App

  alias SparklineDashboard.SparklineExtension, as: Sparkline
  alias Plushie.Event.{Timer, WidgetEvent}
  alias Plushie.Subscription

  defmodule Model do
    @moduledoc false

    @type t :: %__MODULE__{
            cpu_samples: [number()],
            mem_samples: [number()],
            net_samples: [number()],
            running: boolean(),
            tick_count: non_neg_integer()
          }

    @enforce_keys [:cpu_samples, :mem_samples, :net_samples, :running, :tick_count]
    defstruct [:cpu_samples, :mem_samples, :net_samples, :running, :tick_count]
  end

  @max_samples 100

  # -- Plushie.App callbacks --------------------------------------------------

  @impl true
  def init(_opts) do
    %Model{
      cpu_samples: [],
      mem_samples: [],
      net_samples: [],
      running: true,
      tick_count: 0
    }
  end

  # Timer tick: generate simulated samples for all three metrics.
  # Only fires when running -- the subscription is removed when paused,
  # but we also guard here for safety.
  @impl true
  def update(%Model{running: true} = model, %Timer{tag: :sample}) do
    %{
      model
      | cpu_samples: cap_samples(model.cpu_samples, cpu_sample(model.tick_count)),
        mem_samples: cap_samples(model.mem_samples, mem_sample(model.tick_count)),
        net_samples: cap_samples(model.net_samples, net_sample()),
        tick_count: model.tick_count + 1
    }
  end

  def update(model, %WidgetEvent{type: :click, id: "toggle_running"}) do
    %{model | running: not model.running}
  end

  def update(model, %WidgetEvent{type: :click, id: "clear"}) do
    %{model | cpu_samples: [], mem_samples: [], net_samples: [], tick_count: 0}
  end

  def update(model, _event), do: model

  @impl true
  def subscribe(%Model{running: true}) do
    [Subscription.every(500, :sample)]
  end

  def subscribe(_model), do: []

  @impl true
  def view(model) do
    import Plushie.UI

    window "main", title: "Sparkline Dashboard" do
      column padding: 20, spacing: 16 do
        text("title", "System Monitor", size: 24)

        row spacing: 12 do
          button("toggle_running", if(model.running, do: "Pause", else: "Resume"))
          button("clear", "Clear")

          text("status", "#{length(model.cpu_samples)} samples",
            size: 14,
            color: "#888888"
          )
        end

        sparkline_card("cpu", "CPU Usage", model.cpu_samples, "#4CAF50", true)
        sparkline_card("mem", "Memory", model.mem_samples, "#2196F3", true)
        sparkline_card("net", "Network I/O", model.net_samples, "#FF9800", false)
      end
    end
  end

  # -- Pure helpers (public for testing) --------------------------------------

  @doc false
  @spec cpu_sample(non_neg_integer()) :: float()
  def cpu_sample(tick) do
    base = 30 + :rand.uniform() * 39
    wave = :math.sin(tick * 0.1) * 15
    Float.round(base + wave, 1)
  end

  @doc false
  @spec mem_sample(non_neg_integer()) :: float()
  def mem_sample(tick) do
    raw = 40 + :rand.uniform() * 9 + tick * 0.05
    value = :math.fmod(raw, 80) + 20
    Float.round(value, 1)
  end

  @doc false
  @spec net_sample() :: number()
  def net_sample do
    round(:rand.uniform() * 100)
  end

  # -- Private ----------------------------------------------------------------

  @spec cap_samples([number()], number()) :: [number()]
  defp cap_samples(samples, value) do
    (samples ++ [value]) |> Enum.take(-@max_samples)
  end

  @spec sparkline_card(String.t(), String.t(), [number()], String.t(), boolean()) ::
          Plushie.Widget.ui_node()
  defp sparkline_card(id, label, data, color, fill) do
    import Plushie.UI

    column id: "#{id}_card", padding: 12, spacing: 4 do
      row id: "#{id}_header", spacing: 8 do
        text("#{id}_label", label, size: 14, color: "#666666")

        if data != [] do
          text("#{id}_value", "#{List.last(data)}", size: 14, color: color)
        end
      end

      Sparkline.new("#{id}_spark",
        data: data,
        color: color,
        stroke_width: 2.0,
        fill: fill,
        height: 60.0
      )
    end
  end
end
