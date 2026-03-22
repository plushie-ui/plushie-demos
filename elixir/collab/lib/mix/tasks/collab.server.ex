defmodule Mix.Tasks.Collab.Server do
  @moduledoc "Start the collaborative server (SSH on 2222, HTTP+WS on 8080)."
  @shortdoc "Start collaborative server"

  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    {:ok, shared} = Collab.Shared.start_link()
    Mix.shell().info("Shared state server started")

    Collab.SshServer.start_ssh_daemon(shared, 2222)
    Mix.shell().info("SSH server listening on localhost:2222")

    {:ok, _} = Collab.WebsocketServer.start_http(shared, 8080)
    Mix.shell().info("WebSocket server listening on http://localhost:8080")

    Process.sleep(:infinity)
  end
end
