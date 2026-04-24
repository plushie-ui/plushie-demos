/**
 * File-backed experiment store. Experiments live as .js source files
 * under the experiments/ directory alongside the pad's own source.
 *
 * Files are read, written, listed, and deleted as plain strings. No
 * sandboxing or validation: the pad trusts the user with the
 * experiment directory.
 */

import { existsSync, mkdirSync, readdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const HERE = dirname(fileURLToPath(import.meta.url))
export const DIR = resolve(HERE, "..", "experiments")

/** List every experiment filename (sorted). */
export function list(): string[] {
  if (!existsSync(DIR)) return []
  return readdirSync(DIR)
    .filter((f) => f.endsWith(".js"))
    .sort()
}

/** Load an experiment's source. Returns "" if the file doesn't exist. */
export function load(name: string): string {
  const path = join(DIR, name)
  if (!existsSync(path)) return ""
  return readFileSync(path, "utf8")
}

/** Write an experiment's source to disk atomically. */
export function save(name: string, source: string): void {
  mkdirSync(DIR, { recursive: true })
  const path = join(DIR, name)
  const tmp = `${path}.tmp`
  writeFileSync(tmp, source, "utf8")
  renameSync(tmp, path)
}

/** Remove an experiment file if it exists. */
export function remove(name: string): void {
  const path = join(DIR, name)
  if (existsSync(path)) rmSync(path)
}

/** A starter source for a fresh experiment. */
export function starterSource(label: string): string {
  return `// Experiment: ${label}
// The last expression in this file is the rendered view node.
// The \`ui\` binding is injected automatically; no imports needed.

ui.column({ padding: 16, spacing: 8, id: "root" }, [
  ui.text("Hello from ${label}!", { id: "greeting", size: 24 }),
  ui.text("Edit me and press Save.", { id: "hint" }),
])
`
}
