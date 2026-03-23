//// Crash lab app -- error resilience demonstration.
////
//// Shows how plushie isolates failures at three different levels:
////
//// - **Extension panic**: Rust `handle_command` panics. Caught by
////   `catch_unwind`, widget replaced with error placeholder. Recovery:
////   remove the widget from the tree and re-add it.
////
//// - **Update panic**: Gleam `update` hits `panic`. The runtime catches
////   it via `try_call`, logs the error, preserves the model, and
////   discards the event. The app continues as if nothing happened.
////
//// - **View panic**: Gleam `view` hits `panic`. The runtime catches it,
////   keeps the previous rendered tree, and continues. A "Recover" button
////   in the previous tree clears the flag so the next render succeeds.
////
//// The counter proves the model survives all three crash types.

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
    /// When True, the next `view` call will panic.
    view_broken: Bool,
  )
}

/// Initial state: counter at zero, widget present, view healthy.
pub fn init() -> #(Model, Command(Event)) {
  #(Model(count: 0, widget_alive: True, view_broken: False), command.none())
}

/// Handle UI events.
///
/// Three deliberately destructive handlers demonstrate different
/// failure modes. The runtime catches all of them.
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

    // Deliberately panic in update. The runtime catches this via
    // try_call, preserves the model, and discards the event.
    WidgetClick(id: "panic-update", ..) ->
      panic as "intentional panic in update"

    // Set the flag that causes view to panic on next render. The
    // update succeeds (flag is set), but the subsequent view call
    // will fail. The runtime preserves the previous tree.
    WidgetClick(id: "break-view", ..) -> #(
      Model(..model, view_broken: True),
      command.none(),
    )

    // Clear the broken-view flag. This handler runs even while the
    // view is broken because the previous rendered tree (which
    // contains the Recover button) is still displayed.
    WidgetClick(id: "recover-view", ..) -> #(
      Model(..model, view_broken: False),
      command.none(),
    )

    _ -> #(model, command.none())
  }
}

/// Build the UI tree.
///
/// If `view_broken` is True, this function panics. The runtime
/// catches the panic and keeps displaying the previous tree, which
/// still contains the "Recover" button.
pub fn view(model: Model) -> Node {
  case model.view_broken {
    True -> panic as "intentional panic in view"
    False -> Nil
  }

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

  ui.window("main", [ui.title("Crash Lab"), ui.window_size(500.0, 520.0)], [
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
          ui.container(
            "counter-section",
            [
              ui.padding(padding.all(12.0)),
              ui.background(section_bg),
              ui.width(length.Fill),
            ],
            [
              ui.column(
                "counter-col",
                [ui.spacing(8), ui.align_x(alignment.Center)],
                [
                  ui.text("counter-label", "Counter (proof of life)", [
                    ui.font_size(12.0),
                    ui.text_color(muted),
                  ]),
                  ui.row("counter-row", [ui.spacing(8)], [
                    ui.button_("dec", "-"),
                    ui.text_("count", int.to_string(model.count)),
                    ui.button_("inc", "+"),
                  ]),
                ],
              ),
            ],
          ),
        ],
        // Crash widget section
        widget_nodes,
        // Action buttons
        [
          ui.row("rust-actions", [ui.spacing(8)], [
            ui.button_("panic-extension", "Panic Extension"),
            ui.button_("toggle-widget", toggle_label),
          ]),
          ui.row("gleam-actions", [ui.spacing(8)], [
            ui.button_("panic-update", "Panic Update"),
            ui.button_("break-view", "Break View"),
            ui.button_("recover-view", "Recover"),
          ]),
        ],
        // Explanation
        [
          ui.text(
            "hint",
            "All three crash types are caught. The counter survives every one.",
            [ui.font_size(11.0), ui.text_color(muted)],
          ),
        ],
      ]),
    ),
  ])
}

/// Build the app.
pub fn app() {
  app.simple(init, update, view)
}
