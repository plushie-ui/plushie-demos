# frozen_string_literal: true

require "plushie"
require "securerandom"
require_relative "notes/note"
require_relative "widgets/note_card"
require_relative "widgets/toolbar"
require_relative "widgets/shortcut_bar"

# Notes app -- demonstrates pure Ruby widgets and state helpers.
#
# Uses Route for navigation, Selection for multi-select, Undo for
# editor history, and DataQuery for search and sort. All custom
# widgets are pure Ruby composites with no Rust dependency.
class Notes
  include Plushie::App

  Model = Plushie::Model.define(
    :notes,       # Array<Note>
    :route,       # Route::State
    :selection,   # Selection::State
    :undo,        # Undo::State (tracks editor content)
    :search,      # String
    :sort_by      # Symbol (:recent, :title, :oldest)
  )

  SORT_OPTIONS = ["Recent", "A-Z", "Oldest"].freeze

  def init(_opts)
    Model.new(
      notes: seed_notes,
      route: Plushie::Route.new("/list"),
      selection: Plushie::Selection.new(mode: :multi),
      undo: nil,
      search: "",
      sort_by: :recent
    )
  end

  def update(model, event)
    case event
    # -- Navigation --
    in Event::Widget[type: :click, id: "back"]
      navigate_back(model)
    in Event::Widget[type: :click, id: /\Anote_/]
      open_note(model, event.id.delete_prefix("note_"))

    # -- Note CRUD --
    in Event::Widget[type: :click, id: "new_note"]
      create_note(model)
    in Event::Widget[type: :click, id: "delete_selected"]
      delete_selected(model)

    # -- Editor --
    in Event::Widget[type: :input, id: "editor_title"]
      update_title(model, event.data["value"])
    in Event::Widget[type: :input, id: "editor_content"]
      update_content(model, event.data["value"])

    # -- Search & Sort --
    in Event::Widget[type: :input, id: "search"]
      model.with(search: event.data["value"])
    in Event::Widget[type: :select, id: "sort"]
      model.with(sort_by: sort_key(event.data["value"]))

    # -- Selection --
    in Event::Widget[type: :toggle, id: /\Aselect_/]
      note_id = event.id.delete_prefix("select_")
      model.with(selection: Plushie::Selection.toggle(model.selection, note_id))

    # -- Keyboard shortcuts --
    in Event::Key[key: "n", modifiers: {ctrl: true}]
      create_note(model)
    in Event::Key[key: "z", modifiers: {ctrl: true}]
      perform_undo(model)
    in Event::Key[key: "y", modifiers: {ctrl: true}]
      perform_redo(model)
    in Event::Key[key: "Escape"]
      handle_escape(model)

    else
      model
    end
  end

  def subscribe(_model)
    [Subscription.on_key_press(:keys)]
  end

  def view(model)
    window("main", title: "Plushie Notes", size: [600, 500]) do
      column("root", spacing: 0, height: "fill", width: "fill") do
        case Plushie::Route.current(model.route)
        when "/list"
          list_view(model)
        else
          editor_view(model)
        end
      end
    end
  end

  private

  # -- Handlers --

  def seed_notes
    now = Time.now
    [
      Note.new(id: "welcome", title: "Welcome to Plushie Notes",
        content: "This app demonstrates pure Ruby widgets and state helpers.",
        updated_at: now),
      Note.new(id: "shortcuts", title: "Keyboard shortcuts",
        content: "Ctrl+N new note, Ctrl+Z undo, Ctrl+Y redo, Esc go back",
        updated_at: now - 3600),
      Note.new(id: "widgets", title: "Custom widgets",
        content: "NoteCard, Toolbar, and ShortcutBar are pure Ruby composites.",
        updated_at: now - 7200)
    ]
  end

  def create_note(model)
    note = Note.new(
      id: SecureRandom.hex(6),
      title: "Untitled",
      content: "",
      updated_at: Time.now
    )
    model
      .with(notes: [note] + model.notes)
      .with(route: Plushie::Route.push(model.route, "/editor", note_id: note.id))
      .with(undo: Plushie::Undo.new(note.content))
  end

  def open_note(model, note_id)
    note = model.notes.find { |n| n.id == note_id }
    return model unless note
    model
      .with(route: Plushie::Route.push(model.route, "/editor", note_id: note_id))
      .with(undo: Plushie::Undo.new(note.content))
  end

  def navigate_back(model)
    model.with(route: Plushie::Route.pop(model.route))
  end

  def delete_selected(model)
    selected = Plushie::Selection.selected(model.selection)
    return model if selected.empty?
    model
      .with(notes: model.notes.reject { |n| selected.include?(n.id) })
      .with(selection: Plushie::Selection.clear(model.selection))
  end

  def update_title(model, title)
    note_id = Plushie::Route.params(model.route)[:note_id]
    model.with(
      notes: model.notes.map { |n|
        (n.id == note_id) ? n.with(title: title, updated_at: Time.now) : n
      }
    )
  end

  def update_content(model, content)
    note_id = Plushie::Route.params(model.route)[:note_id]
    old_content = Plushie::Undo.current(model.undo)
    model
      .with(
        notes: model.notes.map { |n|
          (n.id == note_id) ? n.with(content: content, updated_at: Time.now) : n
        }
      )
      .with(
        undo: Plushie::Undo.apply(model.undo, {
          apply: ->(_) { content },
          undo: ->(_) { old_content },
          label: "edit",
          coalesce: :content_edit,
          coalesce_window_ms: 500
        })
      )
  end

  def perform_undo(model)
    return model unless model.undo && Plushie::Undo.can_undo?(model.undo)
    note_id = Plushie::Route.params(model.route)[:note_id]
    new_undo = Plushie::Undo.undo(model.undo)
    restored = Plushie::Undo.current(new_undo)
    model
      .with(undo: new_undo)
      .with(notes: model.notes.map { |n|
        (n.id == note_id) ? n.with(content: restored, updated_at: Time.now) : n
      })
  end

  def perform_redo(model)
    return model unless model.undo && Plushie::Undo.can_redo?(model.undo)
    note_id = Plushie::Route.params(model.route)[:note_id]
    new_undo = Plushie::Undo.redo(model.undo)
    restored = Plushie::Undo.current(new_undo)
    model
      .with(undo: new_undo)
      .with(notes: model.notes.map { |n|
        (n.id == note_id) ? n.with(content: restored, updated_at: Time.now) : n
      })
  end

  def handle_escape(model)
    case Plushie::Route.current(model.route)
    when "/list"
      selected = Plushie::Selection.selected(model.selection)
      if !selected.empty?
        model.with(selection: Plushie::Selection.clear(model.selection))
      elsif !model.search.empty?
        model.with(search: "")
      else
        model
      end
    else
      navigate_back(model)
    end
  end

  def sort_key(label)
    case label
    when "A-Z" then :title
    when "Oldest" then :oldest
    else :recent
    end
  end

  # -- Query --

  def filtered_notes(model)
    hashes = model.notes.map(&:to_h)

    search = model.search.strip.empty? ? nil : [[:title, :content], model.search]
    sort = case model.sort_by
    when :title then [:asc, :title]
    when :oldest then [:asc, :updated_at]
    else [:desc, :updated_at]
    end

    result = Plushie::DataQuery.query(hashes,
      search: search, sort: sort, page_size: 100)
    result[:entries]
  end

  # -- Views --

  def list_view(model)
    selected = Plushie::Selection.selected(model.selection)
    actions = [["new_note", "+ New"]]
    actions.unshift(["delete_selected", "Delete (#{selected.size})"]) if selected.any?

    Toolbar.new("toolbar", title: "Plushie Notes", actions: actions).build

    row("filters", spacing: 8, padding: [8, 16], width: "fill") do
      text_input("search", model.search, placeholder: "Search notes...",
        width: "fill")
      pick_list("sort", SORT_OPTIONS, sort_label(model.sort_by))
    end

    notes = filtered_notes(model)

    scrollable("note_list", height: "fill") do
      column("notes_col", padding: [4, 16], spacing: 6) do
        if notes.empty?
          text("empty", "No notes found.", size: 14, color: "#888888")
        else
          notes.each do |note_hash|
            note_id = note_hash[:id]
            NoteCard.new("note_#{note_id}",
              title: note_hash[:title],
              preview: (note_hash[:content] || "")[0, 80],
              timestamp: format_time(note_hash[:updated_at]),
              selected: Plushie::Selection.selected?(model.selection, note_id)).build
          end
        end
      end
    end

    ShortcutBar.new("shortcuts", hints: list_hints(selected)).build
  end

  def editor_view(model)
    note_id = Plushie::Route.params(model.route)[:note_id]
    note = model.notes.find { |n| n.id == note_id }

    unless note
      Toolbar.new("toolbar", title: "Not Found", show_back: true).build
      text("missing", "This note no longer exists.", size: 14, color: "#888888")
      return
    end

    actions = []
    actions << ["undo", "Undo"] if model.undo && Plushie::Undo.can_undo?(model.undo)
    actions << ["redo", "Redo"] if model.undo && Plushie::Undo.can_redo?(model.undo)

    Toolbar.new("toolbar",
      title: note.title,
      show_back: true,
      actions: actions).build

    column("editor_body", padding: 16, spacing: 12, height: "fill") do
      text_input("editor_title", note.title, placeholder: "Title")
      text_input("editor_content", note.content,
        placeholder: "Start writing...", width: "fill", height: "fill")
    end

    ShortcutBar.new("shortcuts", hints: editor_hints(model)).build
  end

  def sort_label(key)
    case key
    when :title then "A-Z"
    when :oldest then "Oldest"
    else "Recent"
    end
  end

  def format_time(time)
    return "" unless time
    time.strftime("%b %-d, %H:%M")
  end

  def list_hints(selected)
    hints = []
    hints << "Del delete (#{selected.size})" if selected.any?
    hints << "Esc deselect" if selected.any?
    hints << "Ctrl+N new"
    hints << "Ctrl+F search"
    hints
  end

  def editor_hints(model)
    hints = ["Esc back"]
    hints << "Ctrl+Z undo" if model.undo && Plushie::Undo.can_undo?(model.undo)
    hints << "Ctrl+Y redo" if model.undo && Plushie::Undo.can_redo?(model.undo)
    hints
  end
end

if $PROGRAM_NAME == __FILE__
  Plushie.run(Notes)
end
