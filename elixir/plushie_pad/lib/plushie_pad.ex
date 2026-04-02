defmodule PlushiePad do
  use Plushie.App

  alias Plushie.Command
  alias Plushie.Effect
  alias Plushie.Event.EffectEvent
  alias Plushie.Event.KeyEvent
  alias Plushie.Event.TimerEvent
  alias Plushie.Event.WidgetEvent
  alias Plushie.Event.WindowEvent
  alias Plushie.Type.Border
  alias Plushie.{Data, Route, Selection, Undo}

  import Plushie.UI
  import PlushiePad.Design

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
      dirty: false,
      detached: false,
      undo: Undo.new(source),
      search_query: "",
      selection: Selection.new(mode: :multi),
      route: Route.new(:editor)
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

  # Editor content changes -- tracked with undo/redo
  def update(model, %WidgetEvent{type: :input, id: "editor", value: source}) do
    old_source = model.source

    undo =
      Undo.apply(model.undo, %{
        apply: fn _old -> source end,
        undo: fn _new -> old_source end,
        coalesce: :typing,
        coalesce_window_ms: 500
      })

    %{model | source: source, dirty: true, undo: undo}
  end

  # Save button (canvas element click arrives as :click with scope)
  def update(model, %WidgetEvent{type: :click, id: "save", scope: ["save-canvas" | _]}) do
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

  # Search input for filtering experiments
  def update(model, %WidgetEvent{type: :input, id: "search", value: query}) do
    %{model | search_query: query}
  end

  # Toggle file selection via checkbox
  def update(model, %WidgetEvent{type: :toggle, id: "file-select", scope: [file | _]}) do
    %{model | selection: Selection.toggle(model.selection, file)}
  end

  # Delete selected experiments
  def update(model, %WidgetEvent{type: :click, id: "delete-selected"}) do
    selected = Selection.selected(model.selection)

    Enum.each(selected, fn file ->
      delete_experiment(file)
    end)

    files = list_experiments()

    model =
      if MapSet.member?(selected, model.active_file) do
        case files do
          [first | _] ->
            source = load_experiment(first)
            model = %{model | files: files, active_file: first, source: source}

            case compile_preview(source) do
              {:ok, tree} -> %{model | preview: tree, error: nil}
              {:error, msg} -> %{model | error: msg, preview: nil}
            end

          [] ->
            %{
              model
              | files: [],
                active_file: nil,
                source: @starter_code,
                preview: nil,
                error: nil
            }
        end
      else
        %{model | files: files}
      end

    %{model | selection: Selection.clear(model.selection)}
  end

  # Switch to a different file
  def update(model, %WidgetEvent{type: :click, id: "select", scope: [file | _]}) do
    if model.active_file != nil do
      save_experiment(model.active_file, model.source)
    end

    source = load_experiment(file)
    model = %{model | active_file: file, source: source, undo: Undo.new(source)}

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

  # Undo (Ctrl+Z)
  def update(model, %KeyEvent{key: "z", modifiers: %{command: true, shift: false}}) do
    if Undo.can_undo?(model.undo) do
      undo = Undo.undo(model.undo)
      %{model | undo: undo, source: Undo.current(undo)}
    else
      model
    end
  end

  # Redo (Ctrl+Shift+Z)
  def update(model, %KeyEvent{key: "z", modifiers: %{command: true, shift: true}}) do
    if Undo.can_redo?(model.undo) do
      undo = Undo.redo(model.undo)
      %{model | undo: undo, source: Undo.current(undo)}
    else
      model
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

  # Import file dialog
  def update(model, %WidgetEvent{type: :click, id: "import"}) do
    {model, Effect.file_open(:import, title: "Import Experiment")}
  end

  # Export file dialog
  def update(model, %WidgetEvent{type: :click, id: "export"}) do
    {model, Effect.file_save(:export, title: "Export Experiment")}
  end

  # Copy source to clipboard
  def update(model, %WidgetEvent{type: :click, id: "copy"}) do
    {model, Effect.clipboard_write(:copy, model.source)}
  end

  # Detach preview into its own window
  def update(model, %WidgetEvent{type: :click, id: "detach"}) do
    %{model | detached: true}
  end

  # Navigate to browser view
  def update(model, %WidgetEvent{type: :click, id: "show-browser"}) do
    %{model | route: Route.push(model.route, :browser)}
  end

  # Navigate back from browser view
  def update(model, %WidgetEvent{type: :click, id: "back-to-editor"}) do
    %{model | route: Route.pop(model.route)}
  end

  # Import effect result
  def update(model, %EffectEvent{tag: :import, result: {:ok, %{path: path}}}) do
    source = File.read!(path)
    %{model | source: source}
  end

  # Export effect result
  def update(model, %EffectEvent{tag: :export, result: {:ok, %{path: path}}}) do
    File.write!(path, model.source)
    model
  end

  # Effect cancelled (import/export/copy)
  def update(model, %EffectEvent{result: :cancelled}) do
    model
  end

  # Closing the detached experiment window
  def update(model, %WindowEvent{type: :close_requested, window_id: "experiment"}) do
    %{model | detached: false}
  end

  # Log everything else
  def update(model, event) do
    entry = format_event(event)
    %{model | event_log: Enum.take([entry | model.event_log], 20)}
  end

  def view(model) do
    case Route.current(model.route) do
      :editor -> editor_view(model)
      :browser -> browser_view(model)
    end
  end

  defp editor_view(model) do
    main =
      window "main", title: "Plushie Pad", theme: :dark do
        column width: :fill, height: :fill, spacing: 0 do
          row width: :fill, height: :fill, spacing: 0 do
            # Sidebar with a right border
            container "sidebar-wrap",
              border: Border.new() |> Border.width(1) |> Border.color("#333") do
              PlushiePad.FileList.new("sidebar",
                files: filtered_files(model),
                active_file: model.active_file,
                search_query: model.search_query,
                selection: model.selection
              )
            end

            # Editor
            text_editor "editor", model.source do
              width({:fill_portion, 1})
              height(:fill)
              highlight_syntax("ex")
              font(:monospace)
            end

            unless model.detached do
              preview_pane(model)
            end
          end

          row padding: {spacing(:xs), spacing(:sm)}, spacing: spacing(:sm) do
            save_button()
            button("import", "Import")
            button("export", "Export")
            button("copy", "Copy")
            button("detach", "Detach")
            button("show-browser", "Browse")
            checkbox("auto-save", model.auto_save)
            text("auto-label", "Auto-save", size: font_size(:sm))

            if MapSet.size(Selection.selected(model.selection)) > 0 do
              button("delete-selected", "Delete Selected")
            end

            text_input("new-name", model.new_name,
              placeholder: "name.ex",
              on_submit: true
            )
          end

          # Event log (custom widget)
          PlushiePad.EventLog.new("event-log", events: model.event_log)
        end
      end

    if model.detached do
      [
        main,
        window "experiment",
          title: "Experiment: #{model.active_file}",
          exit_on_close_request: false do
          container "detached-preview", padding: spacing(:md) do
            preview_content(model)
          end
        end
      ]
    else
      main
    end
  end

  defp browser_view(model) do
    window "main", title: "Plushie Pad - Browse", theme: :dark do
      column width: :fill, height: :fill, padding: spacing(:md), spacing: spacing(:sm) do
        row spacing: spacing(:sm) do
          button("back-to-editor", "Back")
          text("browser-title", "All Experiments", size: 20)
        end

        scrollable "browser-scroll", height: :fill do
          keyed_column spacing: spacing(:sm) do
            for file <- model.files do
              container file, padding: spacing(:sm) do
                row spacing: spacing(:sm) do
                  text("name", file, size: font_size(:sm))
                end
              end
            end
          end
        end
      end
    end
  end

  defp preview_pane(model) do
    container "preview",
      width: {:fill_portion, 1},
      height: :fill,
      padding: spacing(:md) do
      preview_content(model)
    end
  end

  defp preview_content(model) do
    if model.error do
      text("error", model.error, color: "#ef4444", size: font_size(:sm))
    else
      if model.preview do
        model.preview
      else
        text("placeholder", "Press Save to compile and preview")
      end
    end
  end

  defp filtered_files(model) do
    if model.search_query == "" do
      model.files
    else
      Data.query(
        Enum.map(model.files, &%{name: &1}),
        search: {[:name], model.search_query}
      ).entries
      |> Enum.map(& &1.name)
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
