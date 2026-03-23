defmodule Notes.App do
  @moduledoc """
  Notes app -- demonstrates pure Elixir widgets and state helpers.

  Uses Route for navigation, Selection for multi-select, Undo for
  editor history, and Data for search and sort. All custom widgets
  are pure Elixir composites with no Rust dependency.

  Run:

      mix plushie.gui Notes.App
  """

  use Plushie.App

  alias Notes.Note
  alias Notes.Widgets.{NoteCard, ShortcutBar, Toolbar}
  alias Plushie.Event.Key
  alias Plushie.Event.Widget

  defmodule Model do
    @moduledoc false

    @type t :: %__MODULE__{
            notes: [Notes.Note.t()],
            route: Plushie.Route.t(),
            selection: Plushie.Selection.t(),
            undo: Plushie.Undo.t() | nil,
            search: String.t(),
            sort_by: :recent | :title | :oldest
          }

    @enforce_keys [:notes, :route, :selection, :undo, :search, :sort_by]
    defstruct [:notes, :route, :selection, :undo, :search, :sort_by]
  end

  @sort_options ["Recent", "A-Z", "Oldest"]

  # -- Plushie.App callbacks --------------------------------------------------

  @impl true
  def init(_opts) do
    %Model{
      notes: seed_notes(),
      route: Plushie.Route.new("/list"),
      selection: Plushie.Selection.new(mode: :multi),
      undo: nil,
      search: "",
      sort_by: :recent
    }
  end

  # -- Navigation --

  @impl true
  def update(model, %Widget{type: :click, id: "back"}), do: navigate_back(model)
  def update(model, %Widget{type: :click, id: "note_" <> note_id}), do: open_note(model, note_id)

  # -- CRUD --

  def update(model, %Widget{type: :click, id: "new_note"}), do: create_note(model)
  def update(model, %Widget{type: :click, id: "delete_selected"}), do: delete_selected(model)

  # -- Editor --

  def update(model, %Widget{type: :input, id: "editor_title", value: val}),
    do: update_title(model, val)

  def update(model, %Widget{type: :input, id: "editor_content", value: val}),
    do: update_content(model, val)

  # -- Search & sort --

  def update(model, %Widget{type: :input, id: "search", value: val}),
    do: %{model | search: val}

  def update(model, %Widget{type: :select, id: "sort", value: val}),
    do: %{model | sort_by: sort_key(val)}

  # -- Selection --

  def update(model, %Widget{type: :toggle, id: "select_" <> note_id}),
    do: %{model | selection: Plushie.Selection.toggle(model.selection, note_id)}

  # -- Undo/redo buttons --

  def update(model, %Widget{type: :click, id: "undo"}), do: perform_undo(model)
  def update(model, %Widget{type: :click, id: "redo"}), do: perform_redo(model)

  # -- Keyboard shortcuts --

  def update(model, %Key{type: :press, key: "n", modifiers: %{command: true}}),
    do: create_note(model)

  def update(model, %Key{type: :press, key: "z", modifiers: %{command: true}}),
    do: perform_undo(model)

  def update(model, %Key{type: :press, key: "y", modifiers: %{command: true}}),
    do: perform_redo(model)

  def update(model, %Key{type: :press, key: :escape}),
    do: handle_escape(model)

  # -- Catch-all --

  def update(model, _event), do: model

  @impl true
  def subscribe(_model) do
    [Plushie.Subscription.on_key_press(:keys)]
  end

  @impl true
  def view(model) do
    import Plushie.UI

    window "main", title: "Plushie Notes", size: {600, 500} do
      column spacing: 0, height: :fill, width: :fill do
        case Plushie.Route.current(model.route) do
          "/list" -> list_view(model)
          _editor -> editor_view(model)
        end
      end
    end
  end

  # -- Handlers ---------------------------------------------------------------

  defp seed_notes do
    now = DateTime.utc_now()

    [
      %Note{
        id: "welcome",
        title: "Welcome to Plushie Notes",
        content: "This app demonstrates pure Elixir widgets and state helpers.",
        updated_at: now
      },
      %Note{
        id: "shortcuts",
        title: "Keyboard shortcuts",
        content: "Ctrl+N new note, Ctrl+Z undo, Ctrl+Y redo, Esc go back.",
        updated_at: DateTime.add(now, -3600)
      },
      %Note{
        id: "widgets",
        title: "Custom widgets",
        content: "NoteCard, Toolbar, and ShortcutBar are pure Elixir composites.",
        updated_at: DateTime.add(now, -7200)
      }
    ]
  end

  defp create_note(model) do
    note = %Note{
      id: random_id(),
      title: "Untitled",
      content: "",
      updated_at: DateTime.utc_now()
    }

    %{
      model
      | notes: [note | model.notes],
        route: Plushie.Route.push(model.route, "/editor", %{note_id: note.id}),
        undo: Plushie.Undo.new(note.content)
    }
  end

  defp open_note(model, note_id) do
    case Enum.find(model.notes, &(&1.id == note_id)) do
      nil ->
        model

      note ->
        %{
          model
          | route: Plushie.Route.push(model.route, "/editor", %{note_id: note_id}),
            undo: Plushie.Undo.new(note.content)
        }
    end
  end

  defp navigate_back(model) do
    %{model | route: Plushie.Route.pop(model.route)}
  end

  defp delete_selected(model) do
    selected = Plushie.Selection.selected(model.selection)

    if MapSet.size(selected) == 0 do
      model
    else
      %{
        model
        | notes: Enum.reject(model.notes, &MapSet.member?(selected, &1.id)),
          selection: Plushie.Selection.clear(model.selection)
      }
    end
  end

  defp update_title(model, title) do
    note_id = current_note_id(model)

    %{
      model
      | notes:
          Enum.map(model.notes, fn note ->
            if note.id == note_id,
              do: %{note | title: title, updated_at: DateTime.utc_now()},
              else: note
          end)
    }
  end

  defp update_content(model, content) do
    note_id = current_note_id(model)
    old_content = if model.undo, do: Plushie.Undo.current(model.undo), else: ""

    %{
      model
      | notes:
          Enum.map(model.notes, fn note ->
            if note.id == note_id,
              do: %{note | content: content, updated_at: DateTime.utc_now()},
              else: note
          end),
        undo:
          Plushie.Undo.apply(model.undo || Plushie.Undo.new(""), %{
            apply: fn _current -> content end,
            undo: fn _current -> old_content end,
            label: "edit",
            coalesce: :content_edit,
            coalesce_window_ms: 500
          })
    }
  end

  defp perform_undo(model) do
    if model.undo && Plushie.Undo.can_undo?(model.undo) do
      new_undo = Plushie.Undo.undo(model.undo)
      restored = Plushie.Undo.current(new_undo)
      note_id = current_note_id(model)

      %{
        model
        | undo: new_undo,
          notes:
            Enum.map(model.notes, fn note ->
              if note.id == note_id,
                do: %{note | content: restored, updated_at: DateTime.utc_now()},
                else: note
            end)
      }
    else
      model
    end
  end

  defp perform_redo(model) do
    if model.undo && Plushie.Undo.can_redo?(model.undo) do
      new_undo = Plushie.Undo.redo(model.undo)
      restored = Plushie.Undo.current(new_undo)
      note_id = current_note_id(model)

      %{
        model
        | undo: new_undo,
          notes:
            Enum.map(model.notes, fn note ->
              if note.id == note_id,
                do: %{note | content: restored, updated_at: DateTime.utc_now()},
                else: note
            end)
      }
    else
      model
    end
  end

  defp handle_escape(model) do
    case Plushie.Route.current(model.route) do
      "/list" ->
        selected = Plushie.Selection.selected(model.selection)

        cond do
          MapSet.size(selected) > 0 ->
            %{model | selection: Plushie.Selection.clear(model.selection)}

          model.search != "" ->
            %{model | search: ""}

          true ->
            model
        end

      _editor ->
        navigate_back(model)
    end
  end

  defp current_note_id(model) do
    Plushie.Route.params(model.route)[:note_id]
  end

  defp random_id do
    :crypto.strong_rand_bytes(6) |> Base.hex_encode32(case: :lower, padding: false)
  end

  # -- Query ------------------------------------------------------------------

  @doc false
  @spec filtered_notes(Model.t()) :: [map()]
  def filtered_notes(model) do
    records = Enum.map(model.notes, &Note.to_map/1)

    search =
      case String.trim(model.search) do
        "" -> nil
        q -> {[:title, :content], q}
      end

    sort =
      case model.sort_by do
        :title -> {:asc, :title}
        :oldest -> {:asc, :updated_at}
        _recent -> {:desc, :updated_at}
      end

    %{entries: entries} = Plushie.Data.query(records, search: search, sort: sort, page_size: 100)
    entries
  end

  # -- Views ------------------------------------------------------------------

  defp list_view(model) do
    import Plushie.UI

    selected = Plushie.Selection.selected(model.selection)
    selected_count = MapSet.size(selected)

    # Build toolbar actions -- delete button appears when items are selected
    actions =
      if selected_count > 0,
        do: [{"delete_selected", "Delete (#{selected_count})"}, {"new_note", "+ New"}],
        else: [{"new_note", "+ New"}]

    notes = filtered_notes(model)

    # Return a list of children for the outer column.
    # Each expression becomes a sibling in the layout.
    [
      Toolbar.new("toolbar", title: "Plushie Notes", actions: actions),
      row padding: {8, 16}, spacing: 8, width: :fill do
        text_input("search", model.search, placeholder: "Search notes...", width: :fill)
        pick_list("sort", @sort_options, sort_label(model.sort_by))
      end,
      Plushie.Widget.Rule.new("list_divider"),
      scrollable "note_list", height: :fill, width: :fill do
        column padding: {8, 16}, spacing: 4, width: :fill do
          if notes == [] do
            text("empty", "No notes found.", size: 14, color: "#888888")
          end

          for note_map <- notes do
            NoteCard.new("note_#{note_map.id}",
              title: note_map.title,
              preview: String.slice(note_map.content, 0, 80),
              timestamp: format_time(note_map.updated_at),
              selected: Plushie.Selection.selected?(model.selection, note_map.id)
            )
          end
        end
      end,
      ShortcutBar.new("shortcuts", hints: list_hints(selected_count))
    ]
  end

  defp editor_view(model) do
    import Plushie.UI

    note_id = current_note_id(model)
    note = Enum.find(model.notes, &(&1.id == note_id))

    if note do
      # Undo/redo actions appear only when the stack has entries
      actions =
        [
          if(model.undo && Plushie.Undo.can_undo?(model.undo), do: {"undo", "Undo"}),
          if(model.undo && Plushie.Undo.can_redo?(model.undo), do: {"redo", "Redo"})
        ]
        |> Enum.reject(&is_nil/1)

      [
        Toolbar.new("toolbar", title: note.title, show_back: true, actions: actions),
        column padding: 16, spacing: 12, height: :fill, width: :fill do
          text_input("editor_title", note.title, placeholder: "Title", width: :fill)

          text_editor("editor_content", note.content,
            placeholder: "Start writing...",
            width: :fill,
            height: :fill
          )
        end,
        ShortcutBar.new("shortcuts", hints: editor_hints(model))
      ]
    else
      # Missing note -- fallback widgets
      [
        Toolbar.new("toolbar", title: "Not Found", show_back: true),
        text("missing", "This note no longer exists.", size: 14, color: "#888888"),
        ShortcutBar.new("shortcuts", hints: [{"Esc", "back"}])
      ]
    end
  end

  @spec sort_key(String.t()) :: :recent | :title | :oldest
  defp sort_key("A-Z"), do: :title
  defp sort_key("Oldest"), do: :oldest
  defp sort_key(_), do: :recent

  @spec sort_label(:recent | :title | :oldest) :: String.t()
  defp sort_label(:title), do: "A-Z"
  defp sort_label(:oldest), do: "Oldest"
  defp sort_label(_), do: "Recent"

  @spec format_time(DateTime.t()) :: String.t()
  defp format_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %-d, %H:%M")
  end

  @spec list_hints(non_neg_integer()) :: [{String.t(), String.t()}]
  defp list_hints(selected_count) do
    hints = []
    hints = if selected_count > 0, do: [{"Esc", "deselect"} | hints], else: hints
    hints = [{"Ctrl+N", "new"} | hints]
    Enum.reverse(hints)
  end

  @spec editor_hints(Model.t()) :: [{String.t(), String.t()}]
  defp editor_hints(model) do
    hints = [{"Esc", "back"}]

    hints =
      if model.undo && Plushie.Undo.can_undo?(model.undo),
        do: hints ++ [{"Ctrl+Z", "undo"}],
        else: hints

    hints =
      if model.undo && Plushie.Undo.can_redo?(model.undo),
        do: hints ++ [{"Ctrl+Y", "redo"}],
        else: hints

    hints
  end
end
