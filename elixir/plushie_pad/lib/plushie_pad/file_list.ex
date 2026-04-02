defmodule PlushiePad.FileList do
  use Plushie.Widget

  widget(:file_list)
  prop(:files, :any)
  prop(:active_file, :any)
  prop(:search_query, :any)
  prop(:selection, :any)

  def view(id, props) do
    import Plushie.UI

    search_query = props[:search_query] || ""
    selection = props[:selection]

    column id: id, width: 200, height: :fill, padding: 8, spacing: 8 do
      text("sidebar-title", "Experiments", size: 14)

      text_input("search", search_query, placeholder: "Search...")

      scrollable "file-scroll", height: :fill do
        keyed_column spacing: 2 do
          for file <- props.files do
            container file do
              row spacing: 4 do
                if selection do
                  checkbox("file-select", Plushie.Selection.selected?(selection, file))
                end

                button("select", file,
                  width: :fill,
                  style:
                    cond do
                      file == props.active_file ->
                        :primary

                      selection && Plushie.Selection.selected?(selection, file) ->
                        :secondary

                      true ->
                        :text
                    end
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
