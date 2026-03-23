# frozen_string_literal: true

require "plushie"

class Notes
  # Card widget for displaying a note in the list view.
  # Pure Ruby composite -- no Rust, no binary rebuild.
  class NoteCard
    include Plushie::Extension
    include Plushie::UI

    widget :note_card, kind: :widget

    prop :title, :string, default: ""
    prop :preview, :string, default: ""
    prop :timestamp, :string, default: ""
    prop :selected, :boolean, default: false

    def render(id, props)
      mouse_area("#{id}_card", on_press: true, cursor: :pointer) do
        container("#{id}_inner", padding: 12) do
          row("#{id}_row", spacing: 12, width: "fill") do
            checkbox("select_#{id}", props[:selected])

            column("#{id}_body", spacing: 4, width: "fill") do
              text("#{id}_title", props[:title] || "Untitled",
                size: 16)
              unless props[:preview] && props[:preview].empty?
                text("#{id}_preview", props[:preview],
                  size: 13, color: "#888888")
              end
              unless props[:timestamp] && props[:timestamp].empty?
                text("#{id}_time", props[:timestamp],
                  size: 11, color: "#aaaaaa")
              end
            end
          end
        end
      end
    end
  end
end
