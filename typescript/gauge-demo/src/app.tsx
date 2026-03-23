// src/app.tsx -- Temperature monitor using a native Rust gauge extension
import { app } from "plushie"
import { Window, Column, Row, Text, Button, Slider } from "plushie/ui"
import { Gauge, GaugeCmds } from "./gauge.js"

export interface Model {
  temperature: number
  targetTemp: number
  history: number[]
}

/** Maximum history entries to retain. */
const MAX_HISTORY = 50

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

function appendHistory(history: number[], value: number): number[] {
  return [...history, value].slice(-MAX_HISTORY)
}

// Button handlers update the model optimistically AND send extension
// commands to sync the Rust-side state. The model updates immediately
// for responsive UI; the extension command keeps the Rust extension's
// internal state in sync.
const setTarget = (s: Model, e: { value: unknown }): [Model, unknown] => [
  { ...s, targetTemp: e.value as number },
  GaugeCmds.animate_to("temp", { value: e.value }),
]

const resetTemp = (s: Model): [Model, unknown] => [
  {
    ...s,
    temperature: 20,
    targetTemp: 20,
    history: appendHistory(s.history, 20),
  },
  GaugeCmds.set_value("temp", { value: 20 }),
]

const setHigh = (s: Model): [Model, unknown] => [
  {
    ...s,
    temperature: 90,
    targetTemp: 90,
    history: appendHistory(s.history, 90),
  },
  GaugeCmds.set_value("temp", { value: 90 }),
]

export default app<Model>({
  init: { temperature: 20, targetTemp: 20, history: [20] },

  settings: {
    extensionConfig: {
      gauge: { arcWidth: 8, tickCount: 10 },
    },
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
