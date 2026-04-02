defmodule PlushiePad.Design do
  alias Plushie.Type.{StyleMap, Border, Shadow}

  # Spacing scale
  def spacing(:xs), do: 4
  def spacing(:sm), do: 8
  def spacing(:md), do: 12
  def spacing(:lg), do: 16
  def spacing(:xl), do: 24

  # Font sizes
  def font_size(:sm), do: 12
  def font_size(:md), do: 14
  def font_size(:lg), do: 18
  def font_size(:xl), do: 24

  # Border radius
  def radius(:sm), do: 4
  def radius(:md), do: 8
  def radius(:lg), do: 12

  # Reusable styles
  def card_style do
    StyleMap.new()
    |> StyleMap.background("#ffffff")
    |> StyleMap.border(
      Border.new()
      |> Border.color("#e5e7eb")
      |> Border.width(1)
      |> Border.rounded(radius(:md))
    )
    |> StyleMap.shadow(
      Shadow.new()
      |> Shadow.color("#0000001a")
      |> Shadow.offset(0, 2)
      |> Shadow.blur_radius(4)
    )
  end
end
