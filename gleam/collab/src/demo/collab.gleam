//// Shared collab app definition used by all 6 demo modes.
////
//// Follows the Elm architecture: init/update/view with immutable
//// model updates. The same code runs in native desktop, WASM browser,
//// WebSocket shared-state, and SSH modes.
////
//// In collaborative modes (WebSocket, SSH), `name`, `notes`, and
//// `count` are shared across all connected clients. The `dark_mode`
//// toggle is per-client -- each user picks their own theme. The
//// `status` field is set externally by the server adapter to show
//// the current connection count.

import gleam/int
import gleam/option
import plushie/app
import plushie/command
import plushie/event.{type Event, WidgetClick, WidgetInput, WidgetToggle}
import plushie/node.{type Node}
import plushie/prop/length
import plushie/prop/padding
import plushie/ui

pub type Model {
  Model(
    /// User's display name. Shared in collaborative modes.
    name: String,
    /// Free-form notes. Shared in collaborative modes.
    notes: String,
    /// Simple counter value. Shared in collaborative modes.
    count: Int,
    /// Light/dark theme preference. Per-client, not shared.
    dark_mode: Bool,
    /// Connection status text (e.g. "2 connected"). Set by the
    /// server adapter, not by the app itself.
    status: String,
  )
}

pub fn init() -> #(Model, command.Command(Event)) {
  #(
    Model(name: "", notes: "", count: 0, dark_mode: False, status: ""),
    command.none(),
  )
}

/// Route widget events to model updates. Each branch matches a
/// widget by its ID and extracts the relevant event data.
pub fn update(model: Model, event: Event) -> #(Model, command.Command(Event)) {
  case event {
    WidgetClick(id: "inc", ..) -> #(
      Model(..model, count: model.count + 1),
      command.none(),
    )
    WidgetClick(id: "dec", ..) -> #(
      Model(..model, count: model.count - 1),
      command.none(),
    )
    WidgetInput(id: "name", value:, ..) -> #(
      Model(..model, name: value),
      command.none(),
    )
    WidgetInput(id: "notes", value:, ..) -> #(
      Model(..model, notes: value),
      command.none(),
    )
    WidgetToggle(id: "theme", value: checked, ..) -> #(
      Model(..model, dark_mode: checked),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

/// Build the UI tree from the current model. The tree is diffed
/// against the previous render and only changes are sent to the
/// renderer as patches.
pub fn view(model: Model) -> Node {
  let theme = case model.dark_mode {
    True -> "dark"
    False -> "light"
  }

  ui.window("main", [ui.title("Plushie Demo"), ui.window_size(500.0, 450.0)], [
    ui.themer("theme-root", theme, [], [
      ui.column(
        "root",
        [
          ui.padding(padding.all(20.0)),
          ui.spacing(16),
          ui.width(length.Fill),
        ],
        [
          ui.text("header", "Plushie Demo", [ui.font_size(24.0)]),
          ui.text_("status", model.status),
          ui.text_input("name", model.name, [
            ui.placeholder("Your name"),
          ]),
          ui.row("counter-row", [ui.spacing(8)], [
            ui.button_("dec", "-"),
            ui.text_("count", "Count: " <> int.to_string(model.count)),
            ui.button_("inc", "+"),
          ]),
          ui.checkbox("theme", "Dark mode", model.dark_mode, []),
          ui.text_input("notes", model.notes, [
            ui.placeholder("Shared notes..."),
            ui.width(length.Fill),
          ]),
        ],
      ),
    ]),
  ])
}

/// Build the app with a 30 Hz event rate cap. This throttles
/// high-frequency events (mouse moves, resize) to 30 updates/sec,
/// keeping the event loop responsive without flooding the wire.
pub fn app() {
  app.simple(init, update, view)
  |> app.with_settings(fn() {
    app.Settings(..app.default_settings(), default_event_rate: option.Some(30))
  })
}
