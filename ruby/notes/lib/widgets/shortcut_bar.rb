# frozen_string_literal: true

require "plushie"

class Notes
  # Context-aware keyboard shortcut hint bar.
  # Pure Ruby composite -- no Rust, no binary rebuild.
  class ShortcutBar
    include Plushie::Extension
    include Plushie::UI

    widget :shortcut_bar, kind: :widget

    prop :hints, :any, default: []

    def render(id, props)
      container("#{id}_bar", padding: [6, 16]) do
        row("#{id}_row", spacing: 20) do
          (props[:hints] || []).each_with_index do |hint, i|
            text("#{id}_hint_#{i}", hint, size: 11, color: "#888888")
          end
        end
      end
    end
  end
end
