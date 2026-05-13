defmodule GaugeDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :gauge_demo,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases(),
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:plushie, "~> 0.7"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:file_system, "~> 1.0", only: :dev, runtime: false}
    ]
  end

  defp releases do
    [
      gauge_demo: [
        include_executables_for: [:unix]
      ]
    ]
  end
end
