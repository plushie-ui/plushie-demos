defmodule SparklineDashboard.MixProject do
  use Mix.Project

  def project do
    [
      app: :sparkline_dashboard,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
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
      {:plushie, "0.5.0"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:file_system, "~> 1.0", only: :dev, runtime: false}
    ]
  end
end
