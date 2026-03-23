defmodule Notes.Note do
  @moduledoc """
  Immutable note record.

  Each note has a unique `id`, a `title`, a `content` body, and an
  `updated_at` timestamp. Notes are stored as a list in the app model
  and converted to maps for `Plushie.Data.query/2`.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          content: String.t(),
          updated_at: DateTime.t()
        }

  @enforce_keys [:id, :title, :content, :updated_at]
  defstruct [:id, :title, :content, :updated_at]

  @doc "Convert to a plain map for use with `Plushie.Data.query/2`."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = note) do
    %{id: note.id, title: note.title, content: note.content, updated_at: note.updated_at}
  end
end
