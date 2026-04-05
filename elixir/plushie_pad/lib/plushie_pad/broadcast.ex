defmodule PlushiePad.Broadcast do
  @moduledoc """
  Event dispatched by `PlushiePad.Shared` to each client runtime.

  Contains the authoritative model from the shared server. The app's
  `update/2` replaces its local model with the broadcast state.
  """

  @enforce_keys [:model]
  defstruct [:model]

  @type t :: %__MODULE__{model: map()}
end
