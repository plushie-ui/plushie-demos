//// Temperature monitor app using the gauge extension widget.
////
//// Demonstrates the optimistic update pattern: button and slider
//// handlers update the model immediately, then send an extension
//// command to sync the Rust-side gauge state. No event is echoed
//// back from Rust, avoiding races on rapid interactions.

import gauge_demo/gauge
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import plushie/command.{type Command}
import plushie/event.{type Event, WidgetClick, WidgetSlide}
import plushie/node.{type Node}
import plushie/prop/alignment
import plushie/prop/color.{type Color}
import plushie/prop/length.{Fixed}
import plushie/prop/padding
import plushie/ui

const max_history = 50

/// Application state.
pub type Model {
  Model(
    /// Current temperature reading in degrees Celsius.
    temperature: Float,
    /// Slider-controlled target temperature.
    target_temp: Float,
    /// Recent temperature readings, oldest first (max 50).
    history: List(Float),
  )
}

// -- Elm loop ----------------------------------------------------------------

/// Initial state: 20 degrees, no pending commands.
pub fn init() -> #(Model, Command(Event)) {
  #(
    Model(temperature: 20.0, target_temp: 20.0, history: [20.0]),
    command.none(),
  )
}

/// Handle events from the UI.
///
/// - Slider "target": updates target_temp, sends animate_to
/// - Button "reset": sets temperature to 20, sends set_value
/// - Button "high": sets temperature to 90, sends set_value
/// - Anything else: model unchanged, no command
pub fn update(model: Model, event: Event) -> #(Model, Command(Event)) {
  case event {
    WidgetSlide(id: "target", value: target, ..) -> {
      let new_model = Model(..model, target_temp: target)
      #(new_model, gauge.animate_to("temp", target))
    }

    WidgetClick(id: "reset", ..) -> {
      let new_model =
        Model(
          temperature: 20.0,
          target_temp: 20.0,
          history: append_history(model.history, 20.0),
        )
      #(new_model, gauge.set_value("temp", 20.0))
    }

    WidgetClick(id: "high", ..) -> {
      let new_model =
        Model(
          temperature: 90.0,
          target_temp: 90.0,
          history: append_history(model.history, 90.0),
        )
      #(new_model, gauge.set_value("temp", 90.0))
    }

    _ -> #(model, command.none())
  }
}

/// Build the UI tree from the current model.
pub fn view(model: Model) -> Node {
  let temp = model.temperature
  let status = temperature_status(temp)
  let color = status_color(temp)

  ui.window("main", [ui.title("Temperature Gauge")], [
    ui.column(
      "content",
      [
        ui.padding(padding.all(24.0)),
        ui.spacing(16),
        ui.align_x(alignment.Center),
      ],
      [
        ui.text("title", "Temperature Monitor", [ui.font_size(24.0)]),
        gauge.gauge("temp", temp, [
          gauge.min(0.0),
          gauge.max(100.0),
          gauge.color(color),
          gauge.label(format_temp(temp)),
          gauge.width(Fixed(200.0)),
          gauge.height(Fixed(200.0)),
        ]),
        ui.text("status", "Status: " <> status, [ui.text_color(color)]),
        ui.text(
          "reading",
          "Current: "
            <> format_temp(temp)
            <> " | Target: "
            <> format_temp(model.target_temp),
          [],
        ),
        ui.slider("target", #(0.0, 100.0), model.target_temp, []),
        ui.row("actions", [ui.spacing(8)], [
          ui.button_("reset", "Reset (20\u{00B0}C)"),
          ui.button_("high", "High (90\u{00B0}C)"),
        ]),
        ui.text("history", "History: " <> format_history(model.history), [
          ui.font_size(12.0),
        ]),
      ],
    ),
  ])
}

// -- Helpers -----------------------------------------------------------------

/// Map a temperature to a human-readable status string.
pub fn temperature_status(temp: Float) -> String {
  case temp >=. 80.0 {
    True -> "Critical"
    False ->
      case temp >=. 60.0 {
        True -> "Warning"
        False ->
          case temp >=. 40.0 {
            True -> "Normal"
            False -> "Cool"
          }
      }
  }
}

/// Map a temperature to a status colour.
///
/// - Critical (>= 80): red (#e74c3c)
/// - Warning (>= 60): orange (#e67e22)
/// - Normal (>= 40): green (#27ae60)
/// - Cool (< 40): blue (#3498db)
pub fn status_color(temp: Float) -> Color {
  let assert Ok(c) = case temp >=. 80.0 {
    True -> color.from_hex("#e74c3c")
    False ->
      case temp >=. 60.0 {
        True -> color.from_hex("#e67e22")
        False ->
          case temp >=. 40.0 {
            True -> color.from_hex("#27ae60")
            False -> color.from_hex("#3498db")
          }
      }
  }
  c
}

/// Append a value to the history, capping at `max_history` entries.
pub fn append_history(history: List(Float), value: Float) -> List(Float) {
  let updated = list.append(history, [value])
  case list.length(updated) > max_history {
    True -> list.drop(updated, list.length(updated) - max_history)
    False -> updated
  }
}

fn format_temp(temp: Float) -> String {
  int.to_string(float.round(temp)) <> "\u{00B0}C"
}

fn format_history(history: List(Float)) -> String {
  history
  |> list.map(fn(t) { int.to_string(float.round(t)) <> "\u{00B0}" })
  |> string.join(", ")
}
