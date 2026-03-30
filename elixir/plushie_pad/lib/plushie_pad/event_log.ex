defmodule PlushiePad.EventLog do
  use Plushie.Widget

  widget :event_log

  prop :events, :any

  state expanded: true

  @impl Plushie.Widget.Handler
  def render(id, props, state) do
    import Plushie.UI

    column id: id, spacing: 4 do
      row spacing: 8 do
        button("toggle-log", if(state.expanded, do: "Hide Log", else: "Show Log"))
        text("count", "#{length(props.events)} events", size: 12)
      end

      if state.expanded do
        scrollable "log-scroll", height: 120 do
          column spacing: 2, padding: 4 do
            for {entry, i} <- Enum.with_index(props.events) do
              text("log-#{i}", entry, size: 12, font: :monospace)
            end
          end
        end
      end
    end
  end

  @impl Plushie.Widget.Handler
  def handle_event(%Plushie.Event.WidgetEvent{type: :click, id: "toggle-log"}, state) do
    {:update_state, %{state | expanded: not state.expanded}}
  end

  def handle_event(_event, _state), do: :ignored
end
