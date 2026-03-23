// src/app.tsx -- Temperature monitor using a native Rust gauge extension
import { app, isWidget } from "plushie"
import { Window, Column, Row, Text, Button, Slider } from "plushie/ui"
import { Gauge, GaugeCmds } from "./gauge.js"

export interface Model {
  temperature: number
  targetTemp: number
  history: number[]
}

function temperatureStatus(temp: number): string {
  if (temp >= 80) return "Critical"
  if (temp >= 60) return "Warning"
  if (temp >= 40) return "Normal"
  return "Cool"
}

function statusColor(temp: number): string {
  if (temp >= 80) return "#e74c3c"
  if (temp >= 60) return "#e67e22"
  if (temp >= 40) return "#27ae60"
  return "#3498db"
}

const setTarget = (s: Model, e: { value: unknown }): [Model, unknown] => [
  { ...s, targetTemp: e.value as number },
  GaugeCmds.animate_to("temp", { value: e.value }),
]

// Button handlers update the model optimistically AND send extension
// commands to sync the Rust-side state. The model updates immediately
// for responsive UI; the extension command ensures the Rust extension's
// internal state matches.
const resetTemp = (s: Model): [Model, unknown] => [
  { ...s, temperature: 20, targetTemp: 20, history: [...s.history, 20] },
  GaugeCmds.set_value("temp", { value: 20 }),
]

const setHigh = (s: Model): [Model, unknown] => [
  { ...s, temperature: 90, targetTemp: 90, history: [...s.history, 90] },
  GaugeCmds.set_value("temp", { value: 90 }),
]

export default app<Model>({
  init: { temperature: 20, targetTemp: 20, history: [20] },

  settings: {
    extensionConfig: {
      gauge: { arcWidth: 8, tickCount: 10 },
    },
  },

  update(state, event) {
    if (
      isWidget(event) &&
      event.type === "value_changed" &&
      event.id === "temp"
    ) {
      const data = event.data as Record<string, unknown>
      const newTemp = data["value"] as number
      // Skip if already at this value (optimistic update already applied)
      if (newTemp === state.temperature) return state
      return {
        ...state,
        temperature: newTemp,
        history: [...state.history, newTemp],
      }
    }
    return state
  },

  view: (state) => (
    <Window id="main" title="Temperature Gauge">
      <Column padding={24} spacing={16} alignX="center">
        <Text id="title" size={24}>
          Temperature Monitor
        </Text>

        {Gauge("temp", {
          value: state.temperature,
          min: 0,
          max: 100,
          color: statusColor(state.temperature),
          label: `${Math.round(state.temperature)}\u00B0C`,
          width: 200,
          height: 200,
          eventRate: 30,
        })}

        <Text
          id="status"
          color={statusColor(state.temperature)}
          content={`Status: ${temperatureStatus(state.temperature)}`}
        />

        <Text
          id="reading"
          content={`Current: ${Math.round(state.temperature)}\u00B0C | Target: ${Math.round(state.targetTemp)}\u00B0C`}
        />

        <Slider
          id="target"
          value={state.targetTemp}
          range={[0, 100]}
          onSlide={setTarget}
        />

        <Row spacing={8}>
          <Button id="reset" onClick={resetTemp}>
            Reset (20\u00B0C)
          </Button>
          <Button id="high" onClick={setHigh}>
            High (90\u00B0C)
          </Button>
        </Row>

        <Text
          id="history"
          size={12}
          color="#999999"
          content={`History: ${state.history.map((t) => `${Math.round(t)}\u00B0`).join(", ")}`}
        />
      </Column>
    </Window>
  ),
})
