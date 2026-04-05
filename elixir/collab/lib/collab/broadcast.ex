defmodule Collab.Broadcast do
  @moduledoc """
  Event dispatched by `Collab.Shared` to each client runtime.

  Contains the authoritative model from the shared server plus the
  originator's client ID so it can skip the redundant update.
  """

  @enforce_keys [:model, :originator_id]
  defstruct [:model, :originator_id]

  @type t :: %__MODULE__{
          model: Collab.Model.t(),
          originator_id: String.t() | nil
        }
end
