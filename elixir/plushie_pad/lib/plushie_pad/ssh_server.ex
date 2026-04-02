defmodule PlushiePad.SshServer do
  def start(shared, port \\ 2222) do
    :ok = Application.ensure_started(:crypto)
    :ok = Application.ensure_started(:asn1)
    :ok = Application.ensure_started(:public_key)
    :ok = Application.ensure_started(:ssh)

    system_dir = ensure_host_key()
    user_dir = Path.expand("~/.ssh")

    {:ok, _} =
      :ssh.daemon({127, 0, 0, 1}, port,
        system_dir: String.to_charlist(system_dir),
        user_dir: String.to_charlist(user_dir),
        auth_methods: ~c"publickey",
        subsystems: [{~c"plushie", {PlushiePad.SshChannel, [shared]}}]
      )

    IO.puts("SSH server listening on localhost:#{port}")
  end

  defp ensure_host_key do
    dir = Path.join(["priv", "ssh"])
    File.mkdir_p!(dir)
    key_file = Path.join(dir, "ssh_host_ed25519_key")

    unless File.exists?(key_file) do
      case System.find_executable("ssh-keygen") do
        nil -> generate_key_erlang(key_file)
        _ -> System.cmd("ssh-keygen", ["-t", "ed25519", "-f", key_file, "-N", "", "-q"])
      end

      IO.puts("Generated SSH host key: #{key_file}")
    end

    dir
  end

  defp generate_key_erlang(path) do
    key = :public_key.generate_key({:namedCurve, :ed25519})
    pem = :public_key.pem_encode([:public_key.pem_entry_encode(:ECPrivateKey, key)])
    File.write!(path, pem)
  end
end
