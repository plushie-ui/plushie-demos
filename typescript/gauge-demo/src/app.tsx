// src/app.tsx -- using the gauge extension in an app
import { app, Command, isWidget } from "plushie"
import { Window, Column, Row, Text, Button, Slider } from "plushie/ui"
import { Gauge, GaugeCmds } from "./gauge.js"

interface Model {
  temperature: number
  targetTemp: number
}

export default app<Model>({
  init: { temperature: 20, targetTemp: 20 },

  settings: {
    extensionConfig: {
      gauge: { arcWidth: 8, tickCount: 10 },
    },
  },

  update(state, event) {
    // Handle events from the gauge extension
    if (
      isWidget(event) &&
      event.type === "value_changed" &&
      event.id === "temp"
    ) {
      const data = event.data as Record<string, unknown>
      return { ...state, temperature: data["value"] as number }
    }
    return state
  },

  view: (state) => (
    <Window id="main" title="Temperature Gauge">
      <Column padding={24} spacing={16} alignX="center">
        {Gauge("temp", {
          value: state.temperature,
          min: 0,
          max: 100,
          color: state.temperature > 80 ? "#e74c3c" : "#3498db",
          label: `${Math.round(state.temperature)}\u00B0C`,
          width: 200,
          height: 200,
          eventRate: 30,
        })}

        <Slider
          id="target"
          value={state.targetTemp}
          range={[0, 100]}
          onSlide={(s: Model, e) => [
            { ...s, targetTemp: e.value as number },
            GaugeCmds.animate_to("temp", { value: e.value }),
          ]}
        />

        <Row spacing={8}>
          <Button
            id="reset"
            onClick={(s: Model) => [
              { ...s, targetTemp: 20 },
              GaugeCmds.set_value("temp", { value: 20 }),
            ]}
          >
            Reset
          </Button>
        </Row>
      </Column>
    </Window>
  ),
})
