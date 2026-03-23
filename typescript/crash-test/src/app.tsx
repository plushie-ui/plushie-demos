/**
 * Crash test -- demonstrates plushie's error resilience.
 *
 * Two layers of crash protection:
 *
 * 1. Rust extension panic: the renderer wraps extension calls in
 *    catch_unwind. A panic poisons the extension; subsequent renders
 *    show an error placeholder. Other widgets keep working.
 *
 * 2. TypeScript runtime error: the runtime wraps handler/update/view
 *    in try/catch. An exception keeps the previous model, skips the
 *    render, and logs the error. The app keeps processing events.
 *
 * After any crash, the counter still increments -- proving the app
 * is alive. Click Reset to recover from view errors.
 */

import { app } from "plushie"
import { Window, Column, Row, Text, Button } from "plushie/ui"
import { CrashBox, CrashBoxCmds } from "./crash-box.js"

// -- Model ------------------------------------------------------------------

export interface Model {
  count: number
  throwInView: boolean
  status: string
}

export function init(): Model {
  return { count: 0, throwInView: false, status: "Ready" }
}

// -- Handlers ---------------------------------------------------------------

export const increment = (s: Model): Model => ({
  ...s,
  count: s.count + 1,
})

export const decrement = (s: Model): Model => ({
  ...s,
  count: s.count - 1,
})

/**
 * Send a "panic" command to the Rust extension.
 *
 * The renderer catches the panic and poisons the extension. The
 * crash_box widget shows an error placeholder on subsequent renders.
 * Everything else keeps working.
 */
export const triggerPanic = (s: Model): [Model, unknown] => [
  { ...s, status: "Rust panic triggered -- widget is poisoned" },
  CrashBoxCmds.panic("crash-widget"),
]

/**
 * Throw an error inside a handler.
 *
 * The runtime catches it, keeps the previous model (so this status
 * message never actually appears), and logs the error. The app keeps
 * running as if nothing happened.
 */
export const triggerHandlerThrow = (_s: Model): Model => {
  throw new Error("intentional error in handler")
}

/**
 * Set a flag that causes view() to throw on the next render.
 *
 * The runtime catches the view error and keeps the previous tree
 * rendered. The UI freezes on the last good render, but handlers
 * still run -- clicking Reset clears the flag and view() recovers.
 */
export const triggerViewThrow = (s: Model): Model => ({
  ...s,
  throwInView: true,
  status: "View will throw on next render -- click Reset to recover",
})

/** Clear the view error flag and reset status. */
export const reset = (s: Model): Model => ({
  ...s,
  throwInView: false,
  status: "Recovered",
})

// -- View -------------------------------------------------------------------

export function view(model: Model) {
  // This throw is intentional -- it demonstrates that the runtime
  // catches view errors and keeps the previous tree rendered.
  if (model.throwInView) {
    throw new Error("intentional error in view")
  }

  return (
    <Window id="main" title="Crash Test">
      <Column padding={20} spacing={16}>
        <Text id="title" size={22}>
          Crash Test
        </Text>

        {/* Counter -- proves the app is still alive after crashes */}
        <Row spacing={8}>
          <Button id="dec" onClick={decrement}>
            -
          </Button>
          <Text id="count" size={20}>
            {String(model.count)}
          </Text>
          <Button id="inc" onClick={increment}>
            +
          </Button>
        </Row>

        {/* Rust extension widget -- shows error placeholder after panic */}
        {CrashBox("crash-widget", {
          label: "Extension OK",
          color: "#2ecc71",
        })}

        {/* Crash buttons */}
        <Row spacing={8}>
          <Button id="panic" onClick={triggerPanic}>
            Panic Widget
          </Button>
          <Button id="throw_handler" onClick={triggerHandlerThrow}>
            Throw Handler
          </Button>
          <Button id="throw_view" onClick={triggerViewThrow}>
            Throw View
          </Button>
          <Button id="reset" onClick={reset}>
            Reset
          </Button>
        </Row>

        <Text id="status" size={13} color="#888888">
          {model.status}
        </Text>
      </Column>
    </Window>
  )
}

// -- App --------------------------------------------------------------------

export default app<Model>({
  init: init(),
  view,
})
