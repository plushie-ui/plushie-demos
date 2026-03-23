/**
 * Collaborative scratchpad app.
 *
 * Pure Elm architecture: init/update/view. Knows nothing about
 * transport, networking, or shared state. The same code runs in
 * standalone desktop mode, shared-state server mode, and client-side
 * browser WASM mode.
 */

import { app } from "plushie"
import {
  Window,
  Column,
  Row,
  Text,
  Button,
  TextInput,
  TextEditor,
  Checkbox,
  Themer,
} from "plushie/ui"

export interface Model {
  name: string
  notes: string
  count: number
  darkMode: boolean
  status: string
}

// -- Init ---------------------------------------------------------------------

export function init(): Model {
  return { name: "", notes: "", count: 0, darkMode: false, status: "" }
}

// -- Update -------------------------------------------------------------------

/** Apply a widget event to the model. Used by both standalone and shared modes. */
export function update(model: Model, family: string, id: string, value?: unknown): Model {
  switch (family) {
    case "click":
      if (id === "inc") return { ...model, count: model.count + 1 }
      if (id === "dec") return { ...model, count: model.count - 1 }
      return model

    case "input":
      if (id === "name") return { ...model, name: (value as string) ?? "" }
      if (id === "notes") return { ...model, notes: (value as string) ?? "" }
      return model

    case "toggle":
      if (id === "theme") return { ...model, darkMode: !model.darkMode }
      return model

    default:
      return model
  }
}

// -- Inline handlers (for JSX in standalone mode) -----------------------------

const increment = (s: Model): Model => update(s, "click", "inc")
const decrement = (s: Model): Model => update(s, "click", "dec")
const toggleTheme = (s: Model): Model => update(s, "toggle", "theme")

const setName = (s: Model, e: { value: unknown }): Model =>
  update(s, "input", "name", e.value)

const setNotes = (s: Model, e: { value: unknown }): Model =>
  update(s, "input", "notes", e.value)

// -- View ---------------------------------------------------------------------

export function view(model: Model) {
  return (
    <Window id="main" title="Collab">
      <Themer theme={model.darkMode ? "dark" : "light"}>
        <Column padding={16} spacing={12} width="fill">
          <Text id="title" size={20}>
            Collaborative Scratchpad
          </Text>

          {model.status !== "" && (
            <Text id="status" size={12} color="#888888">
              {model.status}
            </Text>
          )}

          <TextInput
            id="name"
            value={model.name}
            placeholder="Your name"
            width="fill"
            onInput={setName}
          />

          <Row spacing={8}>
            <Button id="dec" onClick={decrement}>
              -
            </Button>
            <Text id="count" size={18}>
              {String(model.count)}
            </Text>
            <Button id="inc" onClick={increment}>
              +
            </Button>
          </Row>

          <Checkbox
            id="theme"
            label="Dark mode"
            value={model.darkMode}
            onToggle={toggleTheme}
          />

          <TextEditor
            id="notes"
            content={model.notes}
            placeholder="Shared notes..."
            height={200}
            width="fill"
            onInput={setNotes}
          />
        </Column>
      </Themer>
    </Window>
  )
}

// -- Standalone app (modes 3 and 4) -------------------------------------------

export default app<Model>({
  init: init(),
  settings: { defaultEventRate: 30 },
  view,
})
