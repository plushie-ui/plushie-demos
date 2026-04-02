defmodule CrashTest.CrashExtension do
  @moduledoc """
  Minimal native widget that can be deliberately panicked.

  Renders a green box with "Widget OK" text. Has a single `panic`
  command that calls `panic!()` in Rust's `handle_command`. After
  the panic, the renderer replaces this widget with a red placeholder
  via `catch_unwind` isolation.

  The widget stays broken for the rest of the session -
  demonstrating that the panic is per-widget-instance, not per-app.
  """

  use Plushie.Widget, :native_widget

  widget(:crash_widget)

  rust_crate("native/crash_widget")
  rust_constructor("crash_widget::CrashExtension::new()")

  prop(:label, :string, default: "Widget OK")

  command(:panic)
end
