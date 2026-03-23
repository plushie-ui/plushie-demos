defmodule Notes.Widgets.ShortcutBar do
  @moduledoc """
  Context-aware keyboard shortcut hint bar.

  Pure Elixir composite widget -- no Rust, no binary rebuild.

  Displayed at the bottom of each view. Hints change based on what
  actions are currently available (e.g. undo only appears when the
  undo stack has entries).

  ## Props

  - `hints` -- list of `{key, action}` tuples, e.g. `[{"Ctrl+N", "new"}]`.
    The key is rendered in a lighter color, the action in a darker color.
  """

  use Plushie.Extension, :widget

  widget(:shortcut_bar)

  prop(:hints, :any, default: [])

  def render(id, props) do
    import Plushie.UI

    row padding: {6, 16}, spacing: 16 do
      for {{key, action}, i} <- Enum.with_index(props.hints) do
        row id: "#{id}_h#{i}", spacing: 4 do
          text("#{id}_key_#{i}", key, size: 11, color: "#999999")
          text("#{id}_act_#{i}", action, size: 11, color: "#666666")
        end
      end
    end
  end
end
