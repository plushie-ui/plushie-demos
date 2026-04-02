defmodule PlushiePad.MixProject do
  use Mix.Project

  def project do
    [
      app: :plushie_pad,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto, :asn1, :public_key, :ssh]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plushie, "== 0.6.0"}
    ]
  end
end
