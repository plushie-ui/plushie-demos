defmodule PlushiePad.Hello do
  use Plushie.App

  alias Plushie.Event.WidgetEvent

  import Plushie.UI

  def init(_opts), do: %{count: 0}

  def update(model, %WidgetEvent{type: :click, id: "increment"}) do
    %{model | count: model.count + 1}
  end

  def update(model, %WidgetEvent{type: :click, id: "decrement"}) do
    %{model | count: model.count - 1}
  end

  def update(model, _event), do: model

  def view(model) do
    window "main", title: "Counter" do
      column padding: 16, spacing: 8 do
        text("count", "Count: #{model.count}")

        row spacing: 8 do
          button("increment", "+")
          button("decrement", "-")
        end
      end
    end
  end
end
