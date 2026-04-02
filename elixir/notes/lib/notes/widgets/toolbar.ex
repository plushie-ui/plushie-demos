defmodule Notes.Widgets.Toolbar do
  @moduledoc """
  Top bar with a title, optional back button, and action buttons.

  Pure Elixir composite widget -- no Rust, no binary rebuild.

  ## Props

  - `title` -- heading text (string)
  - `show_back` -- whether to show the back button (boolean, default false)
  - `actions` -- list of `{id, label}` tuples for action buttons
  """

  use Plushie.Widget

  widget(:toolbar)

  prop(:title, :string, default: "")
  prop(:show_back, :boolean, default: false)
  prop(:actions, :any, default: [])

  def view(id, props) do
    import Plushie.UI

    row padding: {12, 0}, spacing: 12, width: :fill do
      if props.show_back do
        button("back", "\u2190")
      end

      text("#{id}_title", props.title, size: 20)

      space(width: :fill)

      for {action_id, label} <- props.actions do
        button(action_id, label)
      end
    end
  end
end
