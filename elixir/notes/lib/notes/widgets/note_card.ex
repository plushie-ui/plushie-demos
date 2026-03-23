defmodule Notes.Widgets.NoteCard do
  @moduledoc """
  Note list item with a selection checkbox, clickable title, and preview.

  Pure Elixir composite widget -- no Rust, no binary rebuild.

  The checkbox ID is `"select_<note_id>"` (for selection toggling).
  The title button ID is `"note_<note_id>"` (for opening the note).

  ## Props

  - `title` -- note title (string)
  - `preview` -- content preview, first ~80 chars (string)
  - `timestamp` -- formatted date string (string)
  - `selected` -- whether the checkbox is checked (boolean, default false)
  """

  use Plushie.Extension, :widget

  widget(:note_card)

  prop(:title, :string, default: "")
  prop(:preview, :string, default: "")
  prop(:timestamp, :string, default: "")
  prop(:selected, :boolean, default: false)

  def render(id, props) do
    import Plushie.UI

    # The id arriving here is "note_<note_id>", so we derive
    # "select_<note_id>" by replacing the prefix.
    note_id = String.replace_prefix(id, "note_", "")

    row id: "#{id}_row", padding: {10, 0}, spacing: 12, width: :fill, align_y: :center do
      checkbox("select_#{note_id}", props.selected)

      column id: "#{id}_body", spacing: 4, width: :fill do
        button(id, props.title)

        if props.preview != "" do
          text("#{id}_preview", props.preview, size: 13, color: "#888888")
        end

        if props.timestamp != "" do
          text("#{id}_time", props.timestamp, size: 11, color: "#aaaaaa")
        end
      end
    end
  end
end
