defmodule Collab.MixProject do
  use Mix.Project

  def project do
    [
      app: :collab,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: ["lib"],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :ssh, :crypto, :public_key, :inets, :ssl]
    ]
  end

  defp deps do
    [
      {:plushie, path: "../../../toddy-elixir"},
      {:bandit, "~> 1.0"},
      {:websock_adapter, "~> 0.5"},
      {:plug, "~> 1.15"},
      {:jason, "~> 1.4"},
      {:file_system, "~> 1.0"}
    ]
  end
end
