/**
 * The Plushie Pad app.
 *
 * A live TypeScript experiment editor: type source on the left, see
 * it render on the right, save to disk, switch between experiments,
 * undo / redo with Ctrl+Z / Ctrl+Shift+Z, auto-save after a pause,
 * and log every event that fires in the preview.
 */

import { app, Subscription, isKey, isTimer, isWidget, target } from "plushie"
import type { DeepReadonly, Event, Handler, SubscriptionType, UINode, WindowNode } from "plushie"
import {
  Button,
  Checkbox,
  Column,
  Container,
  Row,
  Scrollable,
  Text,
  TextEditor,
  TextInput,
  Window,
} from "plushie/ui"

import { compileAndRender } from "./compile.js"
import * as Experiments from "./experiments.js"

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

interface UndoEntry {
  readonly before: string
  readonly after: string
  readonly timestamp: number
}

interface UndoStack {
  readonly past: readonly UndoEntry[]
  readonly future: readonly UndoEntry[]
}

export interface Model {
  readonly source: string
  readonly preview: UINode | null
  readonly error: string | null
  readonly eventLog: readonly string[]
  readonly files: readonly string[]
  readonly activeFile: string | null
  readonly newName: string
  readonly autoSave: boolean
  readonly dirty: boolean
  readonly undoStack: UndoStack
}

const STARTER_LABEL = "hello"

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

function initModel(): Model {
  const files = Experiments.list()
  const activeFile = files[0] ?? null
  const source = activeFile ? Experiments.load(activeFile) : Experiments.starterSource(STARTER_LABEL)
  const [preview, error] = render(source)
  return {
    source,
    preview,
    error,
    eventLog: [],
    files,
    activeFile,
    newName: "",
    autoSave: false,
    dirty: false,
    undoStack: { past: [], future: [] },
  }
}

function render(source: string): [UINode | null, string | null] {
  const result = compileAndRender(source)
  return result.ok ? [result.node, null] : [null, result.message]
}

// ---------------------------------------------------------------------------
// Undo / redo
// ---------------------------------------------------------------------------

const COALESCE_MS = 500

function pushUndo(stack: UndoStack, before: string, after: string): UndoStack {
  if (before === after) return stack
  const now = Date.now()
  const last = stack.past.at(-1)
  if (last && now - last.timestamp < COALESCE_MS) {
    const coalesced: UndoEntry = { before: last.before, after, timestamp: now }
    return { past: [...stack.past.slice(0, -1), coalesced], future: [] }
  }
  return { past: [...stack.past, { before, after, timestamp: now }], future: [] }
}

function undo(stack: UndoStack, current: string): [UndoStack, string] {
  const last = stack.past.at(-1)
  if (!last) return [stack, current]
  return [
    { past: stack.past.slice(0, -1), future: [{ before: last.before, after: current, timestamp: Date.now() }, ...stack.future] },
    last.before,
  ]
}

function redo(stack: UndoStack, current: string): [UndoStack, string] {
  const next = stack.future[0]
  if (!next) return [stack, current]
  return [
    { past: [...stack.past, { before: current, after: next.after, timestamp: Date.now() }], future: stack.future.slice(1) },
    next.after,
  ]
}

// ---------------------------------------------------------------------------
// Update helpers
// ---------------------------------------------------------------------------

function saveAndRender(state: DeepReadonly<Model>): Model {
  const [preview, error] = render(state.source)
  if (state.activeFile && error === null) {
    Experiments.save(state.activeFile, state.source)
  }
  return { ...(state as Model), preview, error, dirty: error ? state.dirty : false }
}

function switchFile(state: DeepReadonly<Model>, file: string): Model {
  if (state.activeFile) Experiments.save(state.activeFile, state.source)
  const source = Experiments.load(file)
  const [preview, error] = render(source)
  return {
    ...(state as Model),
    activeFile: file,
    source,
    preview,
    error,
    dirty: false,
    undoStack: { past: [], future: [] },
  }
}

function deleteFile(state: DeepReadonly<Model>, file: string): Model {
  Experiments.remove(file)
  const files = Experiments.list()
  if (state.activeFile !== file) {
    return { ...(state as Model), files }
  }
  const fallback = files[0]
  if (fallback) return switchFile({ ...(state as Model), files }, fallback)
  return {
    ...(state as Model),
    files: [],
    activeFile: null,
    source: Experiments.starterSource(STARTER_LABEL),
    preview: null,
    error: null,
    dirty: false,
  }
}

function createNew(state: DeepReadonly<Model>): Model {
  const raw = state.newName.trim()
  if (raw === "") return state as Model
  const name = raw.endsWith(".js") ? raw : `${raw}.js`
  const label = name.replace(/\.js$/, "")
  const source = Experiments.starterSource(label)
  Experiments.save(name, source)
  const [preview, error] = render(source)
  return {
    ...(state as Model),
    files: Experiments.list(),
    activeFile: name,
    source,
    preview,
    error,
    newName: "",
    dirty: false,
    undoStack: { past: [], future: [] },
  }
}

function logEvent(state: DeepReadonly<Model>, event: Event): Model {
  const entry = JSON.stringify({ kind: event.kind, ...(isWidget(event) ? { target: target(event), type: event.type } : {}) })
  const truncated = entry.length > 80 ? `${entry.slice(0, 77)}...` : entry
  return { ...(state as Model), eventLog: [truncated, ...state.eventLog].slice(0, 20) }
}

// ---------------------------------------------------------------------------
// View helpers
// ---------------------------------------------------------------------------

function sidebar(state: DeepReadonly<Model>): UINode {
  return Container({
    id: "sidebar-wrap",
    width: 200,
    height: "fill",
    style: { border: { color: "#333333", width: 1 } },
    children: [
      Scrollable({
        id: "sidebar",
        height: "fill",
        children: [
          Column({
            id: "files",
            spacing: 4,
            padding: 8,
            children: state.files.map((file) => fileRow(state, file)),
          }),
        ],
      }),
    ],
  })
}

function fileRow(state: DeepReadonly<Model>, file: string): UINode {
  const selectStyle = state.activeFile === file ? "primary" : "secondary"
  return Container({
    id: file,
    padding: 4,
    children: [
      Row({
        id: "row",
        spacing: 4,
        children: [
          Button({ id: "select", style: selectStyle, onClick: selectFile(file) as Handler<unknown>, children: file }),
          Button({ id: "delete", style: "danger", onClick: deleteFileHandler(file) as Handler<unknown>, children: "x" }),
        ],
      }),
    ],
  })
}

function editorPane(state: DeepReadonly<Model>): UINode {
  return TextEditor({
    id: "editor",
    value: state.source,
    width: { fillPortion: 2 },
    height: "fill",
    highlightSyntax: "javascript",
    font: "monospace",
    onInput: handleEdit as Handler<unknown>,
  } as never)
}

function previewPane(state: DeepReadonly<Model>): UINode {
  const body: UINode = state.error
    ? Text({ id: "error", size: 14, color: "#ef4444", children: state.error })
    : state.preview ?? Text({ id: "placeholder", children: "Press Save to compile" })
  return Container({
    id: "preview",
    width: { fillPortion: 2 },
    height: "fill",
    padding: 16,
    children: [body],
  })
}

function toolbar(state: DeepReadonly<Model>): UINode {
  return Row({
    id: "toolbar",
    padding: [8, 4],
    spacing: 8,
    children: [
      Button({ id: "save", onClick: handleSaveClick as Handler<unknown>, children: "Save" }),
      Checkbox({ id: "auto-save", value: state.autoSave, label: "Auto-save", onToggle: handleAutoSaveToggle as Handler<unknown> }),
      TextInput({
        id: "new-name",
        value: state.newName,
        placeholder: "new_name.js",
        onInput: handleNewNameInput as Handler<unknown>,
        onSubmit: true,
      }),
    ],
  })
}

function eventLogPane(state: DeepReadonly<Model>): UINode {
  return Scrollable({
    id: "event-log",
    height: 120,
    children: [
      Column({
        id: "log-lines",
        spacing: 2,
        padding: 4,
        children: state.eventLog.map((entry, i) =>
          Text({ id: `line-${String(i)}`, size: 11, font: "monospace", children: entry }),
        ),
      }),
    ],
  })
}

// ---------------------------------------------------------------------------
// Inline handlers
// ---------------------------------------------------------------------------

const handleEdit: Handler<Model> = (state, event) => {
  const next = typeof event.value === "string" ? event.value : state.source
  return {
    ...(state as Model),
    source: next,
    dirty: true,
    undoStack: pushUndo(state.undoStack as UndoStack, state.source, next),
  }
}

const handleSaveClick: Handler<Model> = (state) => saveAndRender(state)

const handleAutoSaveToggle: Handler<Model> = (state, event) => ({
  ...(state as Model),
  autoSave: typeof event.value === "boolean" ? event.value : !state.autoSave,
})

const handleNewNameInput: Handler<Model> = (state, event) => ({
  ...(state as Model),
  newName: typeof event.value === "string" ? event.value : state.newName,
})

function selectFile(file: string): Handler<Model> {
  return (state) => switchFile(state, file)
}

function deleteFileHandler(file: string): Handler<Model> {
  return (state) => deleteFile(state, file)
}

// ---------------------------------------------------------------------------
// App definition
// ---------------------------------------------------------------------------

export const padApp = app<Model>({
  init: initModel(),

  subscriptions(state) {
    const subs: SubscriptionType[] = [Subscription.onKeyPress()]
    if (state.autoSave && state.dirty) {
      subs.push(Subscription.every(1000, "auto_save"))
    }
    return subs
  },

  update(state, event) {
    if (isTimer(event, "auto_save")) {
      return saveAndRender(state)
    }

    if (isWidget(event) && event.id === "new-name" && event.type === "submit") {
      return createNew(state)
    }

    if (isKey(event, "press")) {
      const { key, modifiers } = event
      if (key === "z" && modifiers.command && !modifiers.shift) {
        const [nextStack, source] = undo(state.undoStack as UndoStack, state.source)
        return { ...(state as Model), undoStack: nextStack, source }
      }
      if (key === "z" && modifiers.command && modifiers.shift) {
        const [nextStack, source] = redo(state.undoStack as UndoStack, state.source)
        return { ...(state as Model), undoStack: nextStack, source }
      }
      if (key === "s" && modifiers.command) {
        return saveAndRender(state)
      }
      if (key === "Escape") {
        return { ...(state as Model), error: null }
      }
    }

    return logEvent(state, event)
  },

  view(state) {
    return Window({
      id: "main",
      title: "Plushie Pad",
      theme: "dark",
      children: [
        Column({
          id: "root",
          width: "fill",
          height: "fill",
          children: [
            Row({
              id: "main-row",
              width: "fill",
              height: "fill",
              children: [sidebar(state), editorPane(state), previewPane(state)],
            }),
            toolbar(state),
            eventLogPane(state),
          ],
        }),
      ],
    }) as WindowNode
  },

  settings: {
    defaultTextSize: 14,
    theme: "dark",
  },
})
