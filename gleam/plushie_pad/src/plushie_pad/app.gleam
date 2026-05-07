//// The main Plushie Pad app.
////
//// A live Erlang experiment editor: type code on the left, see it
//// render on the right, save to disk, switch between experiments,
//// undo / redo with Ctrl+Z / Ctrl+Shift+Z, auto-save after a pause,
//// and log every event that fires in the preview.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import plushie/app.{type App}
import plushie/command.{type Command}
import plushie/event.{
  type Event, type EventTarget, Click, Close, EventTarget, Input, Key, KeyEvent,
  KeyPressed, Submit, Toggle, Widget,
}
import plushie/node.{type Node}
import plushie/prop/border
import plushie/prop/color
import plushie/prop/font.{Monospace}
import plushie/prop/length.{Fill, FillPortion, Fixed, Shrink}
import plushie/prop/padding
import plushie/prop/theme.{Dark}
import plushie/subscription.{type Subscription}
import plushie/ui
import plushie/undo
import plushie/widget/button
import plushie/widget/checkbox
import plushie/widget/column
import plushie/widget/container
import plushie/widget/row
import plushie/widget/scrollable
import plushie/widget/text
import plushie/widget/text_editor
import plushie/widget/text_input
import plushie/widget/window
import plushie_pad/compile
import plushie_pad/experiments

pub type Model {
  Model(
    source: String,
    preview: Option(Node),
    error: Option(String),
    event_log: List(String),
    files: List(String),
    active_file: Option(String),
    new_name: String,
    auto_save: Bool,
    dirty: Bool,
    undo_stack: undo.UndoStack(String),
  )
}

pub fn app() -> App(Model, Event) {
  app.simple(init, update, view)
  |> app.with_subscribe(subscribe)
}

fn init() -> #(Model, Command(Event)) {
  let files = experiments.list()
  let #(source, active) = case files {
    [first, ..] -> #(experiments.load(first), Some(first))
    [] -> #(experiments.starter_source("hello"), None)
  }
  let #(preview, error) = case compile.compile_and_render(source) {
    Ok(tree) -> #(Some(tree), None)
    Error(msg) -> #(None, Some(msg))
  }
  let model =
    Model(
      source: source,
      preview: preview,
      error: error,
      event_log: [],
      files: files,
      active_file: active,
      new_name: "",
      auto_save: False,
      dirty: False,
      undo_stack: undo.new(source),
    )
  #(model, command.none())
}

fn subscribe(model: Model) -> List(Subscription) {
  let base = [subscription.on_key_press()]
  case model.auto_save && model.dirty {
    True -> [subscription.every(1000, "auto_save"), ..base]
    False -> base
  }
}

fn update(model: Model, evt: Event) -> #(Model, Command(Event)) {
  case evt {
    // Editor content changed - push an undo entry.
    Widget(Input(target: EventTarget(id: "editor", ..), value: s)) -> {
      let next_undo =
        undo.push_with_coalesce(model.undo_stack, s, "typing", 500)
      #(
        Model(..model, source: s, dirty: True, undo_stack: next_undo),
        command.none(),
      )
    }

    // Save button.
    Widget(Click(target: EventTarget(id: "save", ..))) -> #(
      save_and_render(model),
      command.none(),
    )

    // Auto-save tick (via subscription tag).
    event.Timer(event.TimerEvent(tag: "auto_save", ..)) -> #(
      save_and_render(model),
      command.none(),
    )

    // Auto-save toggle.
    Widget(Toggle(target: EventTarget(id: "auto-save", ..), value: on)) -> #(
      Model(..model, auto_save: on),
      command.none(),
    )

    // New-experiment name input.
    Widget(Input(target: EventTarget(id: "new-name", ..), value: v)) -> #(
      Model(..model, new_name: v),
      command.none(),
    )

    // Submit new-experiment name (Enter in the input).
    Widget(Submit(target: EventTarget(id: "new-name", ..), ..)) -> #(
      create_new(model),
      command.none(),
    )

    // Select a file from the sidebar.
    Widget(Click(target: EventTarget(id: "select", scope: [file, ..], ..))) -> #(
      switch_file(model, file),
      command.none(),
    )

    // Delete a file from the sidebar.
    Widget(Click(target: EventTarget(id: "delete", scope: [file, ..], ..))) -> #(
      delete_file(model, file),
      command.none(),
    )

    // Ctrl+Z for undo.
    Key(KeyEvent(event_type: KeyPressed, key: "z", modifiers: m, ..))
      if m.command && !m.shift
    -> #(do_undo(model), command.none())

    // Ctrl+Shift+Z for redo.
    Key(KeyEvent(event_type: KeyPressed, key: "z", modifiers: m, ..))
      if m.command && m.shift
    -> #(do_redo(model), command.none())

    // Ctrl+S for save.
    Key(KeyEvent(event_type: KeyPressed, key: "s", modifiers: m, ..))
      if m.command
    -> #(save_and_render(model), command.none())

    // Escape clears the error banner.
    Key(KeyEvent(event_type: KeyPressed, key: "Escape", ..)) -> #(
      Model(..model, error: None),
      command.none(),
    )

    // Log everything else for the event-log panel.
    _ -> #(log_event(model, evt), command.none())
  }
}

fn save_and_render(model: Model) -> Model {
  case compile.compile_and_render(model.source) {
    Ok(tree) -> {
      case model.active_file {
        Some(f) -> experiments.save(f, model.source)
        None -> Nil
      }
      Model(..model, preview: Some(tree), error: None, dirty: False)
    }
    Error(msg) -> Model(..model, error: Some(msg), preview: None)
  }
}

fn switch_file(model: Model, file: String) -> Model {
  case model.active_file {
    Some(prev) -> experiments.save(prev, model.source)
    None -> Nil
  }
  let source = experiments.load(file)
  let model =
    Model(
      ..model,
      active_file: Some(file),
      source: source,
      dirty: False,
      undo_stack: undo.new(source),
    )
  case compile.compile_and_render(source) {
    Ok(tree) -> Model(..model, preview: Some(tree), error: None)
    Error(msg) -> Model(..model, preview: None, error: Some(msg))
  }
}

fn delete_file(model: Model, file: String) -> Model {
  experiments.delete(file)
  let files = experiments.list()
  case model.active_file == Some(file) {
    True ->
      case files {
        [first, ..] -> switch_file(Model(..model, files: files), first)
        [] ->
          Model(
            ..model,
            files: [],
            active_file: None,
            source: experiments.starter_source("hello"),
            preview: None,
            error: None,
          )
      }
    False -> Model(..model, files: files)
  }
}

fn create_new(model: Model) -> Model {
  case string.trim(model.new_name) {
    "" -> model
    raw -> {
      let name = case string.ends_with(raw, ".erl") {
        True -> raw
        False -> raw <> ".erl"
      }
      let module = experiments.module_name_of(name)
      let source = experiments.starter_source(module)
      experiments.save(name, source)
      let files = experiments.list()
      let #(preview, error) = case compile.compile_and_render(source) {
        Ok(tree) -> #(Some(tree), None)
        Error(msg) -> #(None, Some(msg))
      }
      Model(
        ..model,
        files: files,
        active_file: Some(name),
        source: source,
        preview: preview,
        error: error,
        new_name: "",
        dirty: False,
        undo_stack: undo.new(source),
      )
    }
  }
}

fn do_undo(model: Model) -> Model {
  case undo.can_undo(model.undo_stack) {
    True -> {
      let stack = undo.undo(model.undo_stack)
      Model(..model, source: undo.current(stack), undo_stack: stack)
    }
    False -> model
  }
}

fn do_redo(model: Model) -> Model {
  case undo.can_redo(model.undo_stack) {
    True -> {
      let stack = undo.redo(model.undo_stack)
      Model(..model, source: undo.current(stack), undo_stack: stack)
    }
    False -> model
  }
}

fn log_event(model: Model, evt: Event) -> Model {
  let entry = string.inspect(evt)
  let trimmed = case string.length(entry) > 80 {
    True -> string.slice(entry, 0, 77) <> "..."
    False -> entry
  }
  Model(..model, event_log: [trimmed, ..list.take(model.event_log, 19)])
}

// --- View ------------------------------------------------------------------

fn view(model: Model) -> List(Node) {
  let gray = case color.from_hex("#333333") {
    Ok(c) -> c
    Error(_) ->
      case color.from_hex("#000000") {
        Ok(c) -> c
        _ -> panic
      }
  }
  [
    ui.window("main", [window.Title("Plushie Pad"), window.WindowTheme(Dark)], [
      ui.column("root", [column.Width(Fill), column.Height(Fill)], [
        ui.row("main-row", [row.Width(Fill), row.Height(Fill)], [
          sidebar(model, gray),
          editor_pane(model),
          preview_pane(model),
        ]),
        toolbar(model),
        event_log_pane(model),
      ]),
    ]),
  ]
}

fn sidebar(model: Model, border_color: color.Color) -> Node {
  ui.container(
    "sidebar-wrap",
    [
      container.Width(Fixed(200.0)),
      container.Height(Fill),
      container.Border(
        border.new() |> border.width(1.0) |> border.color(border_color),
      ),
    ],
    [
      ui.scrollable("sidebar", [scrollable.Height(Fill)], [
        ui.column(
          "files",
          [column.Spacing(4.0), column.Padding(padding.all(8.0))],
          list.map(model.files, fn(file) { file_row(model, file) }),
        ),
      ]),
    ],
  )
}

fn file_row(model: Model, file: String) -> Node {
  let is_active = model.active_file == Some(file)
  ui.container(file, [container.Padding(padding.all(4.0))], [
    ui.row("row", [row.Spacing(4.0)], [
      ui.button("select", file, case is_active {
        True -> [button.Style(button.Primary)]
        False -> [button.Style(button.Subtle)]
      }),
      ui.button("delete", "x", [button.Style(button.Danger)]),
    ]),
  ])
}

fn editor_pane(model: Model) -> Node {
  ui.text_editor("editor", model.source, [
    text_editor.Width(FillPortion(2)),
    text_editor.Height(Fill),
    text_editor.HighlightSyntax("erlang"),
    text_editor.Font(Monospace),
  ])
}

fn preview_pane(model: Model) -> Node {
  let content = case model.error, model.preview {
    Some(msg), _ -> ui.text("error", msg, [text.Size(14.0)])
    None, Some(tree) -> tree
    None, None -> ui.text_("placeholder", "Press Save to compile")
  }
  ui.container(
    "preview",
    [
      container.Width(FillPortion(2)),
      container.Height(Fill),
      container.Padding(padding.all(16.0)),
    ],
    [content],
  )
}

fn toolbar(model: Model) -> Node {
  ui.row("toolbar", [row.Padding(padding.xy(4.0, 8.0)), row.Spacing(8.0)], [
    ui.button_("save", "Save"),
    ui.checkbox("auto-save", "Auto-save", model.auto_save, []),
    ui.text_input("new-name", model.new_name, [
      text_input.Placeholder("new_name.erl"),
      text_input.OnSubmit(True),
    ]),
  ])
}

fn event_log_pane(model: Model) -> Node {
  ui.scrollable("event-log", [scrollable.Height(Fixed(120.0))], [
    ui.column(
      "log-lines",
      [column.Spacing(2.0), column.Padding(padding.all(4.0))],
      list.map(model.event_log, fn(entry) {
        ui.text(entry, entry, [text.Size(11.0), text.Font(Monospace)])
      }),
    ),
  ])
}
