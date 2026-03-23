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

// -- Handlers (inline, for standalone mode) -----------------------------------

const increment = (s: Model): Model => ({ ...s, count: s.count + 1 })
const decrement = (s: Model): Model => ({ ...s, count: s.count - 1 })
const toggleTheme = (s: Model): Model => ({ ...s, darkMode: !s.darkMode })

const setName = (s: Model, e: { value: unknown }): Model => ({
  ...s,
  name: e.value as string,
})

const setNotes = (s: Model, e: { value: unknown }): Model => ({
  ...s,
  notes: e.value as string,
})

// -- View ---------------------------------------------------------------------

export function view(model: Model) {
  return (
    <Window id="main" title="Collab">
      <Themer theme={model.darkMode ? "dark" : "light"}>
        <Column padding={16} spacing={12}>
          <Text id="title" size={20}>
            Collaborative Scratchpad
          </Text>

          {model.status !== "" && (
            <Text id="status" size={12} color="#888888" content={model.status} />
          )}

          <TextInput
            id="name"
            value={model.name}
            placeholder="Your name"
            onInput={setName}
          />

          <Row spacing={8}>
            <Button id="dec" onClick={decrement}>
              -
            </Button>
            <Text id="count" size={18} content={String(model.count)} />
            <Button id="inc" onClick={increment}>
              +
            </Button>
          </Row>

          <Checkbox
            id="theme"
            label="Dark mode"
            checked={model.darkMode}
            onToggle={toggleTheme}
          />

          <TextEditor
            id="notes"
            content={model.notes}
            placeholder="Shared notes..."
            height={200}
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
