defmodule PlushiePad.FileList do
  use Plushie.Widget

  widget :file_list
  prop :files, :any
  prop :active_file, :any

  def render(id, props) do
    import Plushie.UI

    column id: id, width: 200, height: :fill, padding: 8, spacing: 8 do
      text("sidebar-title", "Experiments", size: 14)

      scrollable "file-scroll", height: :fill do
        keyed_column spacing: 2 do
          for file <- props.files do
            container file do
              row spacing: 4 do
                button("select", file,
                  width: :fill,
                  style: if(file == props.active_file, do: :primary, else: :text)
                )

                button("delete", "x")
              end
            end
          end
        end
      end
    end
  end
end
