defmodule Mix.Tasks.PlushiePad.Server do
  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")
    {:ok, shared} = PlushiePad.Shared.start_link()
    PlushiePad.SshServer.start(shared)
    Process.sleep(:infinity)
  end
end
