defmodule PlushiePad do
  use Plushie.App

  alias Plushie.Event.WidgetEvent

  import Plushie.UI

  @starter_code """
  defmodule Pad.Experiments.Hello do
    import Plushie.UI

    def render do
      column padding: 16, spacing: 8 do
        text("greeting", "Hello, Plushie!", size: 24)
        button("btn", "Click Me")
      end
    end
  end
  """

  def init(_opts) do
    model = %{
      source: @starter_code,
      preview: nil,
      error: nil
    }

    case compile_preview(model.source) do
      {:ok, tree} -> %{model | preview: tree}
      {:error, msg} -> %{model | error: msg}
    end
  end

  def update(model, %WidgetEvent{type: :input, id: "editor", value: source}) do
    %{model | source: source}
  end

  def update(model, %WidgetEvent{type: :click, id: "save"}) do
    case compile_preview(model.source) do
      {:ok, tree} -> %{model | preview: tree, error: nil}
      {:error, msg} -> %{model | error: msg, preview: nil}
    end
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

  defp compile_preview(source) do
    case Code.string_to_quoted(source) do
      {:error, {meta, message, token}} ->
        line = Keyword.get(meta, :line, "?")
        {:error, "Line #{line}: #{message}#{token}"}

      {:ok, _ast} ->
        try do
          Code.put_compiler_option(:ignore_module_conflict, true)
          [{module, _}] = Code.compile_string(source)

          if function_exported?(module, :render, 0) do
            {:ok, module.render()}
          else
            {:error, "Module must export a render/0 function"}
          end
        rescue
          e -> {:error, Exception.message(e)}
        after
          Code.put_compiler_option(:ignore_module_conflict, false)
        end
    end
  end
end
