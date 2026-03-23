//// Crash lab app -- error resilience demonstration.
////
//// Shows how plushie isolates failures at different levels:
////
//// - **Extension panic**: Rust extension panics in `handle_command`.
////   Caught by `catch_unwind`, widget replaced with error placeholder.
////   App continues running. Recovery: remove the widget from the tree
////   and re-add it (toggle button).
////
//// - **Gleam panic**: `update` hits `panic`. Runtime process crashes.
////   Supervisor restarts from `init`. Model is lost -- counter
////   resets to 0. This is the cost of a host-side crash.
////
//// The counter proves the model is alive. After an extension panic,
//// the counter still works. After a Gleam panic, it resets.

import crash_lab/crashable
import gleam/int
import gleam/list
import plushie/app
import plushie/command.{type Command}
import plushie/event.{type Event, WidgetClick}
import plushie/node.{type Node}
import plushie/prop/alignment
import plushie/prop/color
import plushie/prop/length
import plushie/prop/padding
import plushie/ui

/// Application state.
pub type Model {
  Model(
    /// Counter that proves the model survived a crash.
    count: Int,
    /// Whether the crash widget is in the tree.
    widget_alive: Bool,
  )
}

/// Initial state: counter at zero, widget present.
pub fn init() -> #(Model, Command(Event)) {
  #(Model(count: 0, widget_alive: True), command.none())
}

/// Handle UI events.
///
/// The "panic-gleam" handler deliberately crashes the runtime to
/// demonstrate model loss on host-side failures.
pub fn update(model: Model, event: Event) -> #(Model, Command(Event)) {
  case event {
    WidgetClick(id: "inc", ..) -> #(
      Model(..model, count: model.count + 1),
      command.none(),
    )

    WidgetClick(id: "dec", ..) -> #(
      Model(..model, count: model.count - 1),
      command.none(),
    )

    WidgetClick(id: "panic-extension", ..) -> #(
      model,
      crashable.panic_command("crasher"),
    )

    WidgetClick(id: "toggle-widget", ..) -> #(
      Model(..model, widget_alive: !model.widget_alive),
      command.none(),
    )

    WidgetClick(id: "panic-gleam", ..) ->
      panic as "intentional Gleam crash in update"

    _ -> #(model, command.none())
  }
}

/// Build the UI tree.
pub fn view(model: Model) -> Node {
  let assert Ok(muted) = color.from_hex("#888888")
  let assert Ok(section_bg) = color.from_hex("#f8f8f8")

  let toggle_label = case model.widget_alive {
    True -> "Remove Widget"
    False -> "Restore Widget"
  }

  let widget_nodes = case model.widget_alive {
    True -> [
      crashable.crash_widget("crasher", [crashable.label("Healthy")]),
    ]
    False -> [
      ui.text("widget-removed", "(widget removed from tree)", [
        ui.text_color(muted),
        ui.font_size(12.0),
      ]),
    ]
  }

  ui.window("main", [ui.title("Crash Lab"), ui.window_size(500.0, 480.0)], [
    ui.column(
      "root",
      [
        ui.padding(padding.all(20.0)),
        ui.spacing(16),
        ui.width(length.Fill),
        ui.align_x(alignment.Center),
      ],
      list.flatten([
        [ui.text("title", "Crash Lab", [ui.font_size(24.0)])],
        // Counter section
        [
          ui.container("counter-section", [
            ui.padding(padding.all(12.0)),
            ui.background(section_bg),
            ui.width(length.Fill),
          ], [
            ui.column("counter-col", [ui.spacing(8), ui.align_x(alignment.Center)], [
              ui.text("counter-label", "Counter (proof of life)", [
                ui.font_size(12.0),
                ui.text_color(muted),
              ]),
              ui.row("counter-row", [ui.spacing(8)], [
                ui.button_("dec", "-"),
                ui.text_("count", int.to_string(model.count)),
                ui.button_("inc", "+"),
              ]),
            ]),
          ]),
        ],
        // Crash widget section
        widget_nodes,
        // Action buttons
        [
          ui.row("actions", [ui.spacing(8)], [
            ui.button_("panic-extension", "Panic Extension"),
            ui.button_("toggle-widget", toggle_label),
          ]),
          ui.button_("panic-gleam", "Panic Gleam Update"),
        ],
        // Explanation
        [
          ui.text("hint", "Panic Extension poisons the widget. Remove and Restore to recover. Panic Gleam crashes the runtime and resets the counter.", [
            ui.font_size(11.0),
            ui.text_color(muted),
          ]),
        ],
      ]),
    ),
  ])
}

/// Build the app.
pub fn app() {
  app.simple(init, update, view)
}
