# frozen_string_literal: true

require "plushie"

class Notes
  # Toolbar widget for the top of each view.
  # Pure Ruby composite -- no Rust, no binary rebuild.
  class Toolbar
    include Plushie::Widget
    include Plushie::UI

    widget :toolbar, kind: :widget

    prop :title, :string, default: ""
    prop :show_back, :boolean, default: false
    prop :actions, :any, default: []

    def render(id, props)
      Plushie::UI::Context.push([])
      node = container("#{id}_bar", padding: [8, 16]) do
        row("#{id}_row", spacing: 12, width: "fill") do
          button("back", "<") if props[:show_back]
          text("#{id}_title", props[:title], size: 20)
          space("#{id}_spacer", width: "fill")
          (props[:actions] || []).each do |action_id, label|
            button(action_id, label)
          end
        end
      end
      Plushie::UI::Context.pop
      node
    end
  end
end
