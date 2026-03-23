# frozen_string_literal: true

require "plushie"
require_relative "crash_extension"

Plushie.configure do |config|
  config.extensions = [CrashExtension]
end

# Crash Lab -- demonstrates error resilience in Plushie.
#
# Two failure modes, two recovery mechanisms:
#
# 1. Rust extension panic: the renderer's catch_unwind catches it,
#    marks the extension as "poisoned", and shows a red placeholder.
#    Remove the widget from the tree and re-add it to recover.
#
# 2. Ruby app error: the runtime rescues StandardError in update
#    and view. In update, the previous model is preserved. In view,
#    the previous rendered tree stays on screen.
class CrashLab
  include Plushie::App

  Model = Plushie::Model.define(
    :count,           # increments to prove the app is alive
    :extension_alive, # whether crash_widget is in the tree
    :view_broken      # whether to raise in view
  )

  def init(_opts)
    Model.new(count: 0, extension_alive: true, view_broken: false)
  end

  def update(model, event)
    case event
    # Counter -- proves the app survives errors
    in Event::Widget[type: :click, id: "count"]
      model.with(count: model.count + 1)

    # Extension panic -- sends a command that panics in Rust
    in Event::Widget[type: :click, id: "panic_ext"]
      [model, Command.extension_command("crasher", "panic", {})]

    # Toggle extension -- remove/restore to clear poisoned state
    in Event::Widget[type: :click, id: "toggle_ext"]
      model.with(extension_alive: !model.extension_alive)

    # Ruby update error -- this raise is caught by the runtime
    in Event::Widget[type: :click, id: "raise_update"]
      raise "intentional error in update handler"

    # Ruby view error -- sets flag, view raises on next render
    in Event::Widget[type: :click, id: "raise_view"]
      model.with(view_broken: true)

    # Recover view -- clears the flag so view succeeds again
    in Event::Widget[type: :click, id: "recover"]
      model.with(view_broken: false)

    else
      model
    end
  end

  def view(model)
    # Raise before building any UI if the flag is set.
    # The runtime preserves the previous view tree, which has
    # the "Recover" button the user can click to clear the flag.
    raise "intentional error in view" if model.view_broken

    window("main", title: "Crash Lab") do
      column("root", padding: 20, spacing: 16, width: "fill") do
        text("title", "Crash Lab", size: 24)
        text("subtitle",
          "Error resilience demo -- crash things and watch them recover.",
          size: 13, color: "#888888")

        # Counter -- always works
        row("counter_row", spacing: 12) do
          text("clicks", "Clicks: #{model.count}", size: 16)
          button("count", "+1")
        end

        rule("sep1")

        # -- Extension panic section --
        text("ext_heading", "Extension Panic", size: 18)

        if model.extension_alive
          _plushie_leaf("crash_widget", "crasher",
            label: "CrashWidget is healthy")
          row("ext_buttons", spacing: 8) do
            button("panic_ext", "Panic Extension")
            button("toggle_ext", "Remove from Tree")
          end
        else
          text("ext_removed",
            "Extension removed. Click Restore to re-add it with a fresh state.",
            size: 13, color: "#888888")
          button("toggle_ext", "Restore Extension")
        end

        rule("sep2")

        # -- Ruby error section --
        text("ruby_heading", "Ruby Errors", size: 18)

        # Recover button rendered here -- BEFORE any potential error
        # point. When the view is broken, this button remains visible
        # in the preserved previous tree.
        button("recover", "Recover View")

        row("error_buttons", spacing: 8) do
          button("raise_update", "Raise in Update")
          button("raise_view", "Raise in View")
        end

        text("footer",
          "This line proves the view rendered successfully.",
          size: 12, color: "#27ae60")
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  Plushie.run(CrashLab)
end
