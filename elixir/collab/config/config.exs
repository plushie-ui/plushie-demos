import Config

# Download both native binary and WASM renderer.
# WASM files go to priv/static/ where the HTTP server can serve them.
config :plushie,
  artifacts: [:bin, :wasm],
  wasm_dir: "priv/static"
