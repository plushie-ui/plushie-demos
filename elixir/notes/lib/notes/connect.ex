defmodule Notes.Connect do
  @moduledoc """
  Release-safe renderer-parent entry point for the notes app.
  """

  @doc """
  Connects `Notes.App` to the renderer socket described by the environment.
  """
  @spec main() :: :ok
  def main do
    case Plushie.Connect.run(Notes.App, []) do
      :ok -> :ok
      {:error, reason} -> raise RuntimeError, "failed to connect notes app: #{inspect(reason)}"
    end
  end
end
