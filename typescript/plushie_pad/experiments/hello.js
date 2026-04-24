// Experiment: hello
// The last expression in this file is the rendered view node.
// The `ui` binding is injected automatically; no imports needed.

ui.column({ padding: 16, spacing: 8, id: "root" }, [
  ui.text("Hello from hello!", { id: "greeting", size: 24 }),
  ui.text("Edit me and press Save.", { id: "hint" }),
])
