# frozen_string_literal: true

require "plushie"
require_relative "compile"
require_relative "experiments"

module PlushiePad
  # The main Plushie Pad app.
  #
  # A live Ruby experiment editor: type code on the left, see it
  # render on the right, save to disk, switch between experiments,
  # undo / redo with Ctrl+Z / Ctrl+Shift+Z, auto-save after a pause,
  # and log every event that fires in the preview.
  class App
    include Plushie::App

    Model = Plushie::Model.define(
      :source,        # current editor buffer (String)
      :preview,       # last successful render (Node or nil)
      :error,         # compile error text (String or nil)
      :event_log,     # recent event strings (Array<String>)
      :files,         # experiment filenames (Array<String>)
      :active_file,   # currently selected filename (String or nil)
      :new_name,      # new-experiment name input (String)
      :auto_save,     # auto-save toggle (Boolean)
      :dirty,         # unsaved edits present (Boolean)
      :undo_stack    # Plushie::Undo stack around :source
    )

    STARTER_LABEL = "hello"

    def init(_opts)
      files = Experiments.list
      source, active = if files.any?
        [Experiments.load(files.first), files.first]
      else
        [Experiments.starter_source(STARTER_LABEL), nil]
      end
      preview, error = render(source)
      Model.new(
        source: source,
        preview: preview,
        error: error,
        event_log: [],
        files: files,
        active_file: active,
        new_name: "",
        auto_save: false,
        dirty: false,
        undo_stack: Plushie::Undo.new(source)
      )
    end

    def subscribe(model)
      subs = [Plushie::Subscription.on_key_press]
      if model.auto_save && model.dirty
        subs << Plushie::Subscription.every(1000, :auto_save)
      end
      subs
    end

    def update(model, event)
      case event
      # Editor content changed.
      in Event::Widget[type: :input, id: "editor", value: source]
        stack = Plushie::Undo.push(
          model.undo_stack,
          {
            apply: ->(_s) { source },
            undo: ->(_s) { model.source },
            label: "typing",
            coalesce: :typing,
            coalesce_window_ms: 500
          }
        )
        model.with(source: source, dirty: true, undo_stack: stack)

      # Save button.
      in Event::Widget[type: :click, id: "save"]
        save_and_render(model)

      # Auto-save tick.
      in Event::Timer[tag: :auto_save]
        save_and_render(model)

      # Auto-save toggle.
      in Event::Widget[type: :toggle, id: "auto-save", value: on]
        model.with(auto_save: on)

      # New-experiment name input.
      in Event::Widget[type: :input, id: "new-name", value: name]
        model.with(new_name: name)

      # Submit new-experiment name.
      in Event::Widget[type: :submit, id: "new-name"]
        create_new(model)

      # Sidebar: select a file.
      in Event::Widget[type: :click, id: "select", scope: [file, *]]
        switch_file(model, file)

      # Sidebar: delete a file.
      in Event::Widget[type: :click, id: "delete", scope: [file, *]]
        delete_file(model, file)

      # Ctrl+Z: undo.
      in Event::Key[type: :press, key: "z", modifiers: {command: true, shift: false}]
        do_undo(model)

      # Ctrl+Shift+Z: redo.
      in Event::Key[type: :press, key: "z", modifiers: {command: true, shift: true}]
        do_redo(model)

      # Ctrl+S: save.
      in Event::Key[type: :press, key: "s", modifiers: {command: true}]
        save_and_render(model)

      # Escape: clear the error banner.
      in Event::Key[type: :press, key: "Escape"]
        model.with(error: nil)

      # Anything else: drop into the event log.
      else
        log_event(model, event)
      end
    end

    def view(model)
      window("main", title: "Plushie Pad", theme: :dark) do
        column("root", width: :fill, height: :fill) do
          row("main-row", width: :fill, height: :fill) do
            sidebar(model)
            editor_pane(model)
            preview_pane(model)
          end
          toolbar(model)
          event_log_pane(model)
        end
      end
    end

    private

    # --- View helpers --------------------------------------------------------

    def sidebar(model)
      container("sidebar-wrap",
        width: 200,
        height: :fill,
        border: Plushie::Type::Border.from_opts(color: "#333333", width: 1)) do
        scrollable("sidebar", height: :fill) do
          column("files", spacing: 4, padding: 8) do
            model.files.each { |file| file_row(model, file) }
          end
        end
      end
    end

    def file_row(model, file)
      select_style = (model.active_file == file) ? :primary : :secondary
      container(file, padding: 4) do
        row("row", spacing: 4) do
          button("select", file, style: select_style)
          button("delete", "x", style: :danger)
        end
      end
    end

    def editor_pane(model)
      text_editor("editor", model.source,
        width: [:fill_portion, 2],
        height: :fill,
        highlight_syntax: "ruby",
        font: :monospace)
    end

    def preview_pane(model)
      container("preview",
        width: [:fill_portion, 2],
        height: :fill,
        padding: 16) do
        if model.error
          text("error", model.error, size: 14)
        elsif model.preview
          # Insert the already-rendered subtree into the current context.
          # preview is a Plushie::Node; append it to the context stack manually.
          Plushie::UI::Context.current&.push(model.preview) || model.preview
        else
          text("placeholder", "Press Save to compile")
        end
      end
    end

    def toolbar(model)
      row("toolbar", padding: [8, 4], spacing: 8) do
        button("save", "Save")
        checkbox("auto-save", model.auto_save, label: "Auto-save")
        text_input("new-name", model.new_name,
          placeholder: "new_name.rb",
          on_submit: true)
      end
    end

    def event_log_pane(model)
      scrollable("event-log", height: 120) do
        column("log-lines", spacing: 2, padding: 4) do
          model.event_log.each_with_index do |entry, i|
            text("line-#{i}", entry, size: 11, font: :monospace)
          end
        end
      end
    end

    # --- Update helpers ------------------------------------------------------

    def render(source)
      case Compile.compile_and_render(source)
      in [:ok, tree]
        [tree, nil]
      in [:error, msg]
        [nil, msg]
      end
    end

    def save_and_render(model)
      preview, error = render(model.source)
      Experiments.save(model.active_file, model.source) if model.active_file && error.nil?
      model.with(preview: preview, error: error, dirty: error ? model.dirty : false)
    end

    def switch_file(model, file)
      Experiments.save(model.active_file, model.source) if model.active_file
      source = Experiments.load(file)
      preview, error = render(source)
      model.with(
        active_file: file,
        source: source,
        preview: preview,
        error: error,
        dirty: false,
        undo_stack: Plushie::Undo.new(source)
      )
    end

    def delete_file(model, file)
      Experiments.delete(file)
      files = Experiments.list
      if model.active_file == file
        if files.any?
          switch_file(model.with(files: files), files.first)
        else
          model.with(
            files: [],
            active_file: nil,
            source: Experiments.starter_source(STARTER_LABEL),
            preview: nil,
            error: nil,
            dirty: false
          )
        end
      else
        model.with(files: files)
      end
    end

    def create_new(model)
      raw = model.new_name.strip
      return model if raw.empty?
      name = raw.end_with?(".rb") ? raw : "#{raw}.rb"
      label = File.basename(name, ".rb")
      source = Experiments.starter_source(label)
      Experiments.save(name, source)
      preview, error = render(source)
      model.with(
        files: Experiments.list,
        active_file: name,
        source: source,
        preview: preview,
        error: error,
        new_name: "",
        dirty: false,
        undo_stack: Plushie::Undo.new(source)
      )
    end

    def do_undo(model)
      return model unless Plushie::Undo.can_undo?(model.undo_stack)
      stack = Plushie::Undo.undo(model.undo_stack)
      model.with(source: Plushie::Undo.current(stack), undo_stack: stack)
    end

    def do_redo(model)
      return model unless Plushie::Undo.can_redo?(model.undo_stack)
      stack = Plushie::Undo.redo(model.undo_stack)
      model.with(source: Plushie::Undo.current(stack), undo_stack: stack)
    end

    def log_event(model, event)
      entry = event.inspect
      entry = entry[0, 77] + "..." if entry.length > 80
      model.with(event_log: ([entry] + model.event_log).first(20))
    end
  end
end
