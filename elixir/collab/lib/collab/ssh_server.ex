defmodule Collab.SshServer do
  @moduledoc """
  SSH daemon for the collaborative demo.

  Starts an Erlang :ssh daemon that accepts SSH connections. Each
  SSH client gets a channel adapter that speaks the plushie JSON
  wire protocol and participates in the shared GenServer alongside
  WebSocket clients.

  Architecture:
    Native plushie --SSH--> :ssh daemon --> channel adapter --> Shared
    Browser (wasm) --WS--> Bandit ------> ws handler --------> Shared

  Both SSH and WebSocket clients share the same server, so changes
  from any client propagate to all others in real time.
  """

  def start_ssh_daemon(shared, port) do
    :ok = Application.ensure_started(:crypto)
    :ok = Application.ensure_started(:asn1)
    :ok = Application.ensure_started(:public_key)
    :ok = Application.ensure_started(:ssh)

    system_dir = ensure_host_keys()

    {:ok, _} =
      :ssh.daemon({127, 0, 0, 1}, port,
        system_dir: String.to_charlist(system_dir),
        no_auth_needed: true,
        subsystems: [
          {~c"plushie", {Collab.SshChannel, [shared]}}
        ]
      )
  end

  defp ensure_host_keys do
    dir = Path.join(System.tmp_dir!(), "plushie_demo_ssh_keys")
    File.mkdir_p!(dir)
    rsa_key = Path.join(dir, "ssh_host_rsa_key")

    unless File.exists?(rsa_key) do
      System.cmd("ssh-keygen", ["-t", "rsa", "-b", "2048", "-f", rsa_key, "-N", "", "-q"])
    end

    dir
  end
end
