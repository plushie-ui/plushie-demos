# frozen_string_literal: true

require "plushie"

# Collaborative scratchpad app.
#
# Follows the Elm architecture: init/update/view with immutable
# model updates. The same code runs in native desktop, WebSocket
# shared-state, and SSH modes.
#
# In collaborative modes (WebSocket), name, notes, and count are
# shared across all connected clients. The dark_mode toggle is
# per-client. The status field is set externally by the server
# adapter to show the current connection count.
class Collab
  include Plushie::App

  Model = Plushie::Model.define(
    :name, :notes, :count, :dark_mode, :status
  )

  def init(_opts)
    Model.new(name: "", notes: "", count: 0, dark_mode: false, status: "")
  end

  def update(model, event)
    case event
    in Event::Widget[type: :click, id: "inc"]
      model.with(count: model.count + 1)
    in Event::Widget[type: :click, id: "dec"]
      model.with(count: model.count - 1)
    in Event::Widget[type: :input, id: "name", value:]
      model.with(name: value)
    in Event::Widget[type: :input, id: "notes", value:]
      model.with(notes: value)
    in Event::Widget[type: :toggle, id: "theme", value:]
      model.with(dark_mode: value)
    else
      model
    end
  end

  def view(model)
    theme = model.dark_mode ? "dark" : "light"

    window("main", title: "Plushie Demo", size: [500, 450]) do
      themer("theme_root", theme: theme) do
        container("bg", width: "fill", height: "fill") do
          column("root", padding: 20, spacing: 16, width: "fill") do
            text("header", "Plushie Demo", size: 24)
            text("status", model.status) unless model.status.empty?

            text_input("name", model.name, placeholder: "Your name")

            row("counter_row", spacing: 8) do
              button("dec", "-")
              text("count", "Count: #{model.count}")
              button("inc", "+")
            end

            checkbox("theme", model.dark_mode, label: "Dark mode")

            text_input("notes", model.notes,
              placeholder: "Shared notes...",
              width: "fill")
          end
        end
      end
    end
  end

  def settings
    {default_event_rate: 30}
  end
end

# Run as native desktop app when executed directly
if $PROGRAM_NAME == __FILE__
  Plushie.run(Collab)
end
