//// Sparkline dashboard application.
////
//// Displays three simulated metrics (CPU, Memory, Network I/O) as
//// sparkline charts using a custom extension widget. Data is generated
//// by a timer subscription and capped at a rolling window.

import gleam/float
import gleam/int
import gleam/list
import gleam/option
import plushie/app
import plushie/command
import plushie/event.{type Event, TimerTick, WidgetClick}
import plushie/node.{type Node}
import plushie/platform
import plushie/prop/alignment
import plushie/prop/color.{type Color}
import plushie/prop/padding
import plushie/subscription
import plushie/ui
import plushie/widget/column
import plushie/widget/container
import plushie/widget/row
import plushie/widget/text
import plushie/widget/window
import sparkline_dashboard/sparkline

// -- Model -------------------------------------------------------------------

const max_samples = 60

pub type Model {
  Model(
    cpu_samples: List(Float),
    mem_samples: List(Float),
    net_samples: List(Float),
    tick: Int,
    running: Bool,
  )
}

pub fn init() -> #(Model, command.Command(Event)) {
  #(
    Model(
      cpu_samples: [],
      mem_samples: [],
      net_samples: [],
      tick: 0,
      running: True,
    ),
    command.none(),
  )
}

// -- Update ------------------------------------------------------------------

pub fn update(model: Model, event: Event) -> #(Model, command.Command(Event)) {
  case event {
    TimerTick(tag: "sample", ..) ->
      case model.running {
        True -> {
          let tick = model.tick + 1
          #(
            Model(
              cpu_samples: cap_samples(model.cpu_samples, cpu_sample(tick)),
              mem_samples: cap_samples(model.mem_samples, mem_sample(tick)),
              net_samples: cap_samples(model.net_samples, net_sample()),
              tick:,
              running: True,
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
      Model(..model, cpu_samples: [], mem_samples: [], net_samples: [], tick: 0),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

// -- Subscriptions -----------------------------------------------------------

pub fn subscribe(model: Model) -> List(subscription.Subscription) {
  case model.running {
    True -> [subscription.every(200, "sample")]
    False -> []
  }
}

// -- View --------------------------------------------------------------------

pub fn view(model: Model) -> Node {
  let assert Ok(cpu_color) = color.from_hex("#4CAF50")
  let assert Ok(mem_color) = color.from_hex("#2196F3")
  let assert Ok(net_color) = color.from_hex("#FF9800")

  let sample_count = list.length(model.cpu_samples)
  let toggle_label = case model.running {
    True -> "Pause"
    False -> "Resume"
  }

  ui.window("main", [window.Title("Sparkline Dashboard")], [
    ui.column(
      "content",
      [
        column.Padding(padding.all(16.0)),
        column.Spacing(16),
        column.AlignX(alignment.Center),
      ],
      [
        ui.row("controls", [row.Spacing(8)], [
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
  let wave = platform.math_sin(int.to_float(tick) *. 0.1) *. 15.0
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
        text.Size(12.0),
        text.Color(muted),
      ]),
    ]
    Error(_) -> []
  }

  ui.container(id <> "_card", [container.Padding(padding.all(12.0))], [
    ui.column(
      id <> "_col",
      [column.Spacing(4)],
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
