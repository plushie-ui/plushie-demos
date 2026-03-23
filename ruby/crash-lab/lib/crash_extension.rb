# frozen_string_literal: true

require "plushie"

# Crash widget extension -- deliberately panics on command.
#
# Renders a status label normally. When the "panic" command is sent,
# the Rust side calls panic!(), which the renderer catches via
# catch_unwind. The extension is marked "poisoned" and subsequent
# renders show a red error placeholder. Other widgets keep working.
#
# Events: none (the panic is one-way).
class CrashExtension
  include Plushie::Extension

  widget :crash_widget, kind: :native_widget

  rust_crate "native/crash_widget"
  rust_constructor "crash_widget::CrashExtension::new()"

  prop :label, :string, default: ""

  command :panic
end
