defmodule Notes.Connect do
  @moduledoc """
  Release-safe renderer-parent entry point for the notes app.
  """

  @doc """
  Connects `Notes.App` to the renderer socket described by the environment.
  """
  @spec main() :: :ok
  def main do
    format = :msgpack
    socket = resolve_socket!()
    token = System.get_env("PLUSHIE_TOKEN")

    {:ok, adapter} = Plushie.SocketAdapter.start_link(socket, format)

    {:ok, pid} =
      Plushie.start_link(Notes.App,
        transport: {:iostream, adapter},
        format: format,
        token: token
      )

    wait(pid)
  end

  defp resolve_socket! do
    case System.get_env("PLUSHIE_SOCKET") do
      socket when is_binary(socket) and socket != "" -> socket
      _ -> raise RuntimeError, "PLUSHIE_SOCKET is required"
    end
  end

  defp wait(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, _pid, _reason} -> :ok
    end
  end
end
