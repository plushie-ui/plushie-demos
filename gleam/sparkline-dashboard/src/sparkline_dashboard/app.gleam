//// System monitor dashboard with three sparkline charts.
////
//// Demonstrates a render-only extension: the sparkline widget consumes
//// data arrays as props and renders them as canvas line charts. No
//// commands or events flow back from the extension.
////
//// Timer subscriptions generate simulated metrics every 500ms. The
//// subscribe callback is conditional -- returns subscriptions only when
//// running, disarming the timer when paused.

import gleam/float
import gleam/int
import gleam/list
import plushie/command.{type Command}
import plushie/event.{type Event, TimerTick, WidgetClick}
import plushie/node.{type Node}
import plushie/prop/alignment
import plushie/prop/color.{type Color}
import plushie/prop/padding
import plushie/subscription.{type Subscription}
import plushie/ui
import sparkline_dashboard/sparkline

const max_samples = 100

/// Application state.
pub type Model {
  Model(
    /// CPU utilisation samples (0-100), oldest first.
    cpu_samples: List(Float),
    /// Memory usage samples (0-100), oldest first.
    mem_samples: List(Float),
    /// Network I/O samples (0-100), oldest first.
    net_samples: List(Float),
    /// Whether the simulation timer is running.
    running: Bool,
    /// Monotonic tick counter for deterministic metric shapes.
    tick_count: Int,
  )
}

// -- Elm loop ----------------------------------------------------------------

/// Initial state: empty samples, timer running, tick at zero.
pub fn init() -> #(Model, Command(Event)) {
  #(
    Model(
      cpu_samples: [],
      mem_samples: [],
      net_samples: [],
      running: True,
      tick_count: 0,
    ),
    command.none(),
  )
}

/// Handle events from the UI and timer.
pub fn update(model: Model, event: Event) -> #(Model, Command(Event)) {
  case event {
    TimerTick(tag: "sample", ..) ->
      case model.running {
        True -> {
          let tick = model.tick_count
          #(
            Model(
              cpu_samples: cap_samples(model.cpu_samples, cpu_sample(tick)),
              mem_samples: cap_samples(model.mem_samples, mem_sample(tick)),
              net_samples: cap_samples(model.net_samples, net_sample()),
              running: model.running,
              tick_count: tick + 1,
            ),
            command.none(),
          )
        }
        False -> #(model, command.none())
      }

    WidgetClick(id: "toggle_running", ..) -> #(
      Model(..model, running: !model.running),
      command.none(),
    )

    WidgetClick(id: "clear", ..) -> #(
      Model(
        cpu_samples: [],
        mem_samples: [],
        net_samples: [],
        running: model.running,
        tick_count: 0,
      ),
      command.none(),
    )

    _ -> #(model, command.none())
  }
}

/// Subscriptions: 500ms timer when running, nothing when paused.
pub fn subscribe(model: Model) -> List(Subscription) {
  case model.running {
    True -> [subscription.every(500, "sample")]
    False -> []
  }
}

/// Build the UI tree from the current model.
pub fn view(model: Model) -> Node {
  let assert Ok(cpu_color) = color.from_hex("#4CAF50")
  let assert Ok(mem_color) = color.from_hex("#2196F3")
  let assert Ok(net_color) = color.from_hex("#FF9800")

  let sample_count = list.length(model.cpu_samples)
  let toggle_label = case model.running {
    True -> "Pause"
    False -> "Resume"
  }

  ui.window("main", [ui.title("Sparkline Dashboard")], [
    ui.column(
      "content",
      [
        ui.padding(padding.all(16.0)),
        ui.spacing(16),
        ui.align_x(alignment.Center),
      ],
      [
        ui.row("controls", [ui.spacing(8)], [
          ui.button_("toggle_running", toggle_label),
          ui.button_("clear", "Clear"),
        ]),
        ui.text_("status", int.to_string(sample_count) <> " samples"),
        sparkline_card("cpu", "CPU", model.cpu_samples, cpu_color, True),
        sparkline_card("mem", "Memory", model.mem_samples, mem_color, True),
        sparkline_card(
          "net",
          "Network I/O",
          model.net_samples,
          net_color,
          False,
        ),
      ],
    ),
  ])
}

// -- Metrics -----------------------------------------------------------------

/// Simulated CPU utilisation: random base with sine wave overlay.
/// Range: approximately 15-85.
pub fn cpu_sample(tick: Int) -> Float {
  let base = 30.0 +. float.random() *. 40.0
  let wave = sin(int.to_float(tick) *. 0.1) *. 15.0
  float.clamp(base +. wave, min: 0.0, max: 100.0)
}

/// Simulated memory usage: oscillating pattern.
/// Range: 20-100.
pub fn mem_sample(tick: Int) -> Float {
  let raw = 40.0 +. float.random() *. 9.0 +. int.to_float(tick) *. 0.05
  let assert Ok(m) = float.modulo(raw, 80.0)
  m +. 20.0
}

/// Simulated network I/O: pure random.
/// Range: 0-100.
pub fn net_sample() -> Float {
  float.random() *. 100.0
}

@external(erlang, "math", "sin")
fn sin(x: Float) -> Float

// -- Helpers -----------------------------------------------------------------

/// Append a value to a sample list, capping at `max_samples`.
pub fn cap_samples(samples: List(Float), value: Float) -> List(Float) {
  let updated = list.append(samples, [value])
  case list.length(updated) > max_samples {
    True -> list.drop(updated, list.length(updated) - max_samples)
    False -> updated
  }
}

fn sparkline_card(
  id: String,
  label_text: String,
  data: List(Float),
  card_color: Color,
  with_fill: Bool,
) -> Node {
  let assert Ok(muted) = color.from_hex("#888888")

  let value_nodes = case list.last(data) {
    Ok(v) -> [
      ui.text(id <> "_value", int.to_string(float.round(v)) <> "%", [
        ui.font_size(12.0),
        ui.text_color(muted),
      ]),
    ]
    Error(_) -> []
  }

  ui.container(id <> "_card", [ui.padding(padding.all(12.0))], [
    ui.column(
      id <> "_col",
      [ui.spacing(4)],
      list.flatten([
        [ui.text_(id <> "_label", label_text)],
        value_nodes,
        [
          sparkline.sparkline(id <> "_spark", data, [
            sparkline.color(card_color),
            sparkline.fill(with_fill),
          ]),
        ],
      ]),
    ),
  ])
}
