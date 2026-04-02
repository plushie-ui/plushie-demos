defmodule PlushiePad do
  use Plushie.App

  alias Plushie.Command
  alias Plushie.Event.KeyEvent
  alias Plushie.Event.TimerEvent
  alias Plushie.Event.WidgetEvent

  import Plushie.UI

  @experiments_dir "priv/experiments"

  @starter_code """
  defmodule Pad.Experiments.Hello do
    import Plushie.UI

    def view do
      column padding: 16, spacing: 8 do
        text("greeting", "Hello, Plushie!", size: 24)
        button("btn", "Click Me")
      end
    end
  end
  """

  def init(_opts) do
    files = list_experiments()

    {source, active} =
      case files do
        [first | _] -> {load_experiment(first), first}
        [] -> {@starter_code, nil}
      end

    model = %{
      source: source,
      preview: nil,
      error: nil,
      event_log: [],
      files: files,
      active_file: active,
      new_name: "",
      auto_save: false,
      dirty: false
    }

    case compile_preview(source) do
      {:ok, tree} -> %{model | preview: tree}
      {:error, msg} -> %{model | error: msg}
    end
  end

  def subscribe(model) do
    subs = [Plushie.Subscription.on_key_press(:keys)]

    if model.auto_save and model.dirty do
      [Plushie.Subscription.every(1000, :auto_save) | subs]
    else
      subs
    end
  end

  # Editor content changes
  def update(model, %WidgetEvent{type: :input, id: "editor", value: source}) do
    %{model | source: source, dirty: true}
  end

  # Save button (canvas version emits :canvas_element_click)
  def update(model, %WidgetEvent{type: :canvas_element_click, id: "save"}) do
    case compile_preview(model.source) do
      {:ok, tree} ->
        if model.active_file, do: save_experiment(model.active_file, model.source)
        %{model | preview: tree, error: nil}

      {:error, msg} ->
        %{model | error: msg, preview: nil}
    end
  end

  # New experiment name input
  def update(model, %WidgetEvent{type: :input, id: "new-name", value: text}) do
    %{model | new_name: text}
  end

  # Submit new experiment
  def update(model, %WidgetEvent{type: :submit, id: "new-name"}) do
    create_new_experiment(model)
  end

  # Auto-save toggle
  def update(model, %WidgetEvent{type: :toggle, id: "auto-save", value: checked}) do
    %{model | auto_save: checked}
  end

  # Switch to a different file
  def update(model, %WidgetEvent{type: :click, id: "select", scope: [file | _]}) do
    if model.active_file != nil do
      save_experiment(model.active_file, model.source)
    end

    source = load_experiment(file)
    model = %{model | active_file: file, source: source}

    case compile_preview(source) do
      {:ok, tree} -> %{model | preview: tree, error: nil}
      {:error, msg} -> %{model | error: msg, preview: nil}
    end
  end

  # Delete an experiment
  def update(model, %WidgetEvent{type: :click, id: "delete", scope: [file | _]}) do
    delete_experiment(file)
    files = list_experiments()

    if file == model.active_file do
      case files do
        [first | _] ->
          source = load_experiment(first)
          model = %{model | files: files, active_file: first, source: source}

          case compile_preview(source) do
            {:ok, tree} -> %{model | preview: tree, error: nil}
            {:error, msg} -> %{model | error: msg, preview: nil}
          end

        [] ->
          %{model | files: [], active_file: nil, source: @starter_code, preview: nil, error: nil}
      end
    else
      %{model | files: files}
    end
  end

  # Keyboard shortcuts
  def update(model, %KeyEvent{key: "s", modifiers: %{command: true}}) do
    case compile_preview(model.source) do
      {:ok, tree} ->
        if model.active_file, do: save_experiment(model.active_file, model.source)
        %{model | preview: tree, error: nil, dirty: false}

      {:error, msg} ->
        %{model | error: msg, preview: nil}
    end
  end

  def update(model, %KeyEvent{key: "n", modifiers: %{command: true}}) do
    {model, Command.focus("new-name")}
  end

  def update(model, %KeyEvent{key: :escape}) do
    %{model | error: nil}
  end

  # Auto-save timer
  def update(model, %TimerEvent{tag: :auto_save}) do
    case compile_preview(model.source) do
      {:ok, tree} ->
        if model.active_file, do: save_experiment(model.active_file, model.source)
        %{model | preview: tree, error: nil, dirty: false}

      {:error, msg} ->
        %{model | error: msg, preview: nil}
    end
  end

  # Log everything else
  def update(model, event) do
    entry = format_event(event)
    %{model | event_log: Enum.take([entry | model.event_log], 20)}
  end

  def view(model) do
    window "main", title: "Plushie Pad" do
      column width: :fill, height: :fill do
        row width: :fill, height: :fill do
          # Sidebar (custom widget)
          PlushiePad.FileList.new("sidebar",
            files: model.files,
            active_file: model.active_file
          )

          # Editor
          text_editor "editor", model.source do
            width({:fill_portion, 1})
            height(:fill)
            highlight_syntax("ex")
            font(:monospace)
          end

          # Preview
          container "preview", width: {:fill_portion, 1}, height: :fill, padding: 8 do
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

        row padding: 4, spacing: 8 do
          save_button()
          checkbox("auto-save", model.auto_save)
          text("auto-label", "Auto-save")

          text_input("new-name", model.new_name,
            placeholder: "name.ex",
            on_submit: true
          )
        end

        # Event log (custom widget)
        PlushiePad.EventLog.new("event-log", events: model.event_log)
      end
    end
  end

  defp save_button do
    canvas "save-canvas", width: 100, height: 36 do
      layer "button" do
        group "save",
          on_click: true,
          cursor: :pointer,
          focusable: true,
          a11y: %{role: :button, label: "Save experiment"},
          hover_style: %{fill: "#2563eb"},
          pressed_style: %{fill: "#1d4ed8"} do
          rect(0, 0, 100, 36,
            fill:
              linear_gradient({0, 0}, {100, 0}, [
                {0.0, "#3b82f6"},
                {1.0, "#2563eb"}
              ]),
            radius: 6
          )

          text(50, 11, "Save", fill: "#ffffff", size: 14)
        end
      end
    end
  end

  defp create_new_experiment(model) do
    name = String.trim(model.new_name)

    if name == "" or not String.ends_with?(name, ".ex") do
      model
    else
      template = """
      defmodule Pad.Experiments.#{name |> Path.rootname() |> Macro.camelize()} do
        import Plushie.UI

        def view do
          column padding: 16 do
            text("hello", "New experiment")
          end
        end
      end
      """

      save_experiment(name, template)
      files = list_experiments()

      model = %{model | files: files, active_file: name, source: template, new_name: ""}

      case compile_preview(template) do
        {:ok, tree} -> {%{model | preview: tree, error: nil}, Command.focus("editor")}
        {:error, msg} -> {%{model | error: msg, preview: nil}, Command.focus("editor")}
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

          if function_exported?(module, :view, 0) do
            {:ok, module.view()}
          else
            {:error, "Module must export a view/0 function"}
          end
        rescue
          e -> {:error, Exception.message(e)}
        after
          Code.put_compiler_option(:ignore_module_conflict, false)
        end
    end
  end

  defp format_event(%mod{} = event) do
    name = mod |> Module.split() |> List.last()

    fields =
      event
      |> Map.from_struct()
      |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
      |> Enum.join(", ")

    "%#{name}{#{fields}}"
  end

  defp list_experiments do
    File.mkdir_p!(@experiments_dir)

    @experiments_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".ex"))
    |> Enum.sort()
  end

  defp save_experiment(name, source) do
    File.mkdir_p!(@experiments_dir)
    File.write!(Path.join(@experiments_dir, name), source)
  end

  defp load_experiment(name) do
    Path.join(@experiments_dir, name) |> File.read!()
  end

  defp delete_experiment(name) do
    Path.join(@experiments_dir, name) |> File.rm!()
  end
end
