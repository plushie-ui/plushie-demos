/**
 * Live dashboard with sparkline charts for simulated system metrics.
 */

import { app, Subscription, isTimer } from "plushie"
import { Window, Column, Row, Text, Button, Container } from "plushie/ui"
import { Sparkline } from "./sparkline.js"

export interface Model {
  cpuSamples: number[]
  memSamples: number[]
  netSamples: number[]
  running: boolean
  tickCount: number
}

const MAX_SAMPLES = 100

function capSamples(samples: number[], value: number): number[] {
  return [...samples, value].slice(-MAX_SAMPLES)
}

/** Generate a simulated CPU sample with sine-wave variation. */
function cpuSample(tick: number): number {
  const base = 30 + Math.random() * 39
  const wave = Math.sin(tick * 0.1) * 15
  return Math.round((base + wave) * 10) / 10
}

/** Generate a simulated memory sample that oscillates. */
function memSample(tick: number): number {
  const raw = 40 + Math.random() * 9 + tick * 0.05
  const value = (raw % 80) + 20
  return Math.round(value * 10) / 10
}

/** Generate a simulated network sample (random). */
function netSample(): number {
  return Math.round(Math.random() * 100)
}

// -- Handlers -----------------------------------------------------------------

const toggleRunning = (s: Model): Model => ({
  ...s,
  running: !s.running,
})

const clearSamples = (s: Model): Model => ({
  ...s,
  cpuSamples: [],
  memSamples: [],
  netSamples: [],
  tickCount: 0,
})

// -- App ----------------------------------------------------------------------

export default app<Model>({
  init: {
    cpuSamples: [],
    memSamples: [],
    netSamples: [],
    running: true,
    tickCount: 0,
  },

  subscriptions: (state) =>
    state.running ? [Subscription.every(500, "sample")] : [],

  update(state, event) {
    if (isTimer(event, "sample") && state.running) {
      return {
        ...state,
        cpuSamples: capSamples(state.cpuSamples, cpuSample(state.tickCount)),
        memSamples: capSamples(state.memSamples, memSample(state.tickCount)),
        netSamples: capSamples(state.netSamples, netSample()),
        tickCount: state.tickCount + 1,
      }
    }
    return state
  },

  view: (state) => (
    <Window id="main" title="Sparkline Dashboard">
      <Column padding={20} spacing={16}>
        <Text id="title" size={24}>
          System Monitor
        </Text>

        {/* Controls */}
        <Row spacing={12}>
          <Button id="toggle_running" onClick={toggleRunning}>
            {state.running ? "Pause" : "Resume"}
          </Button>
          <Button id="clear" onClick={clearSamples}>
            Clear
          </Button>
          <Text id="status" size={14} color="#888888">
            {`${state.cpuSamples.length} samples`}
          </Text>
        </Row>

        {/* Sparkline charts */}
        {sparklineCard("cpu", "CPU Usage", state.cpuSamples, "#4CAF50", true)}
        {sparklineCard("mem", "Memory", state.memSamples, "#2196F3", true)}
        {sparklineCard("net", "Network I/O", state.netSamples, "#FF9800", false)}
      </Column>
    </Window>
  ),
})

// -- View helpers -------------------------------------------------------------

function sparklineCard(
  id: string,
  label: string,
  data: number[],
  color: string,
  fill: boolean,
) {
  const lastValue = data.length > 0 ? data[data.length - 1]! : null

  return (
    <Container padding={12}>
      <Column spacing={4}>
        <Row spacing={8}>
          <Text id={`${id}_label`} size={14} color="#666666">
            {label}
          </Text>
          {lastValue !== null && (
            <Text id={`${id}_value`} size={14} color={color}>
              {String(lastValue)}
            </Text>
          )}
        </Row>

        {Sparkline(`${id}_spark`, {
          data,
          color,
          stroke_width: 2.0,
          fill,
          height: 60.0,
        })}
      </Column>
    </Container>
  )
}
