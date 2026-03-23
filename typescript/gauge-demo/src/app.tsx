/**
 * Temperature monitor app using a native Rust gauge extension.
 *
 * Demonstrates:
 * - Native widget extension (gauge rendered in Rust/iced)
 * - Extension commands (set_value, animate_to)
 * - Extension events (value_changed from Rust back to TypeScript)
 * - Settings with extension_config
 *
 * The temperature field only updates when the Rust extension confirms
 * the change via a value_changed event. Button handlers set targetTemp
 * optimistically and send extension commands; the Rust side processes
 * the command and echoes the new value back.
 */

import { app, isWidget } from "plushie"
import { Window, Column, Row, Text, Button, Slider } from "plushie/ui"
import { Gauge, GaugeCmds } from "./gauge.js"

// -- Model ------------------------------------------------------------------

export interface Model {
  temperature: number
  targetTemp: number
  history: number[]
}

/** Maximum history entries to retain. */
const MAX_HISTORY = 50

export function init(): Model {
  return { temperature: 20, targetTemp: 20, history: [20] }
}

// -- Helpers ----------------------------------------------------------------

/** Human-readable status for a temperature reading. */
export function temperatureStatus(temp: number): string {
  if (temp >= 80) return "Critical"
  if (temp >= 60) return "Warning"
  if (temp >= 40) return "Normal"
  return "Cool"
}

/** Color corresponding to the temperature status. */
export function statusColor(temp: number): string {
  if (temp >= 80) return "#e74c3c"
  if (temp >= 60) return "#e67e22"
  if (temp >= 40) return "#27ae60"
  return "#3498db"
}

function appendHistory(history: number[], value: number): number[] {
  return [...history, value].slice(-MAX_HISTORY)
}

// -- Handlers ---------------------------------------------------------------
//
// Button handlers set targetTemp only. The temperature field changes when
// the Rust extension responds with a value_changed event (handled in update).

const setTarget = (s: Model, e: { value: unknown }): [Model, unknown] => [
  { ...s, targetTemp: e.value as number },
  GaugeCmds.animate_to("temp", { value: e.value }),
]

export const resetTemp = (s: Model): [Model, unknown] => [
  { ...s, targetTemp: 20 },
  GaugeCmds.set_value("temp", { value: 20 }),
]

export const setHigh = (s: Model): [Model, unknown] => [
  { ...s, targetTemp: 90 },
  GaugeCmds.set_value("temp", { value: 90 }),
]

// -- View -------------------------------------------------------------------

export function view(model: Model) {
  const temp = model.temperature

  return (
    <Window id="main" title="Temperature Gauge">
      <Column padding={24} spacing={16} alignX="center">
        <Text id="title" size={24}>
          Temperature Monitor
        </Text>

        {Gauge("temp", {
          value: temp,
          min: 0,
          max: 100,
          color: statusColor(temp),
          label: `${Math.round(temp)}\u00B0C`,
          width: 200,
          height: 200,
          eventRate: 30,
        })}

        <Text
          id="status"
          color={statusColor(temp)}
          content={`Status: ${temperatureStatus(temp)}`}
        />

        <Text
          id="reading"
          content={`Current: ${Math.round(temp)}\u00B0C | Target: ${Math.round(model.targetTemp)}\u00B0C`}
        />

        <Slider
          id="target"
          value={model.targetTemp}
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
          content={`History: ${model.history.map((t) => `${Math.round(t)}\u00B0`).join(", ")}`}
        />
      </Column>
    </Window>
  )
}

// -- App --------------------------------------------------------------------

export default app<Model>({
  init: init(),

  settings: {
    extensionConfig: {
      gauge: { arcWidth: 8, tickCount: 10 },
    },
  },

  update(state, event) {
    // Handle value_changed events from the Rust gauge extension.
    // This is the only way temperature changes -- the extension is
    // the source of truth. Button handlers only set targetTemp and
    // send extension commands; the Rust side processes the command
    // and echoes the confirmed value back.
    if (
      isWidget(event) &&
      event.type === "value_changed" &&
      event.id === "temp"
    ) {
      const data = event.data as Record<string, unknown>
      const newTemp = data["value"] as number
      return {
        ...state,
        temperature: newTemp,
        history: appendHistory(state.history, newTemp),
      }
    }
    return state
  },

  view,
})
