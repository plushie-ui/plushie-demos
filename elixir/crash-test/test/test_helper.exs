# Resolve the plushie binary (downloaded or built with extensions).
binary = Plushie.Binary.path!()
Application.put_env(:plushie, :test_binary_path, binary)

# Start the shared session pool for the mock test backend.
{:ok, _} =
  Plushie.Test.SessionPool.start_link(
    name: Plushie.TestPool,
    renderer: binary,
    mode: :mock,
    max_sessions: 8
  )

ExUnit.start()
