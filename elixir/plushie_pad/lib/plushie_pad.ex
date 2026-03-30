defmodule PlushiePad do
  use Plushie.App

  alias Plushie.Event.WidgetEvent

  import Plushie.UI

  def init(_opts) do
    %{
      source: "# Write some Plushie code here\n",
      preview: nil,
      error: nil
    }
  end

  def update(model, %WidgetEvent{type: :input, id: "editor", value: source}) do
    %{model | source: source}
  end

  def update(model, _event), do: model

  def view(model) do
    window "main", title: "Plushie Pad" do
      column width: :fill, height: :fill do
        row width: :fill, height: :fill do
          text_editor "editor", model.source do
            width {:fill_portion, 1}
            height :fill
            highlight_syntax "ex"
            font :monospace
          end

          container "preview", width: {:fill_portion, 1}, height: :fill, padding: 16 do
            if model.error do
              text("error", model.error, color: :red)
            else
              if model.preview do
                model.preview
              else
                text("placeholder", "Press Save to compile and preview")
              end
            end
          end
        end

        row padding: 8 do
          button("save", "Save")
        end
      end
    end
  end
end
