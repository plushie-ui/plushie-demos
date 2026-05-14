defmodule GaugeDemo.Connect do
  @moduledoc """
  Release-safe renderer-parent entry point for the gauge demo.
  """

  @doc """
  Connects `GaugeDemo.TemperatureMonitor` to the renderer socket.
  """
  @spec main() :: :ok
  def main do
    case Plushie.Connect.run(GaugeDemo.TemperatureMonitor, []) do
      :ok -> :ok
      {:error, reason} -> raise RuntimeError, "failed to connect gauge demo: #{inspect(reason)}"
    end
  end
end
