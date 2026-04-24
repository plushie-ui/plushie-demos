# Plushie Pad (TypeScript)

A live experiment editor: type code on the left, see it render on
the right. Save to disk, switch between experiments, undo and redo,
auto-save, and watch events log in real time.

The Plushie TypeScript guides thread this project from chapter 3
onward. Reading the guides alongside the source is the best way to
see how the Elm architecture composes in a non-trivial TypeScript
app.

## Running

```sh
pnpm install
pnpm start
```

The `plushie` package is resolved from the sibling
`plushie-typescript` checkout via `file:../../../plushie-typescript`
in `package.json`. Download the renderer binary before the first
run if needed:

```sh
npx plushie download
```

## Layout

- `src/app.ts`: the `app()` definition with `init`, `update`,
  `view`, `subscriptions`.
- `src/compile.ts`: runtime compilation of an experiment's source.
  The source is evaluated as a single expression with `ui`
  (the `plushie/ui` namespace) injected as a parameter.
- `src/experiments.ts`: filesystem helpers for listing, loading,
  saving, and deleting `.js` files under `experiments/`.
- `experiments/`: the experiment files. Every `.js` in this
  directory shows up in the sidebar. Edit, save, compile.

## Keyboard shortcuts

- `Cmd+S`: save the current experiment.
- `Cmd+Z`: undo the last edit in the editor.
- `Cmd+Shift+Z`: redo.
- `Escape`: clear the error banner.

## Experiment format

An experiment file is a single JavaScript expression that
evaluates to a `UINode`. The `ui` namespace is injected
automatically, so imports are unnecessary:

```javascript
ui.column({ padding: 16, id: "root" }, [
  ui.text("Hello!", { id: "greeting", size: 24 }),
  ui.button("Click Me", { id: "btn" }),
])
```

The last expression in the file is the rendered node. Any parse or
runtime error is displayed in the preview pane.
