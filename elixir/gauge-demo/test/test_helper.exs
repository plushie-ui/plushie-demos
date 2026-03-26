binary = Plushie.Binary.path!()
Application.put_env(:plushie, :test_binary_path, binary)

{:ok, _} =
  Plushie.Test.SessionPool.start_link(
    name: Plushie.TestPool,
    renderer: binary,
    mode: :headless,
    rust_log: "off",
    max_sessions: 8
  )

ExUnit.start()
