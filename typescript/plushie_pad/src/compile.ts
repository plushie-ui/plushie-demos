/**
 * Runtime compilation of experiment source.
 *
 * Each experiment's source is treated as a JavaScript expression
 * returning a UINode. The `ui` binding (the `plushie/ui` namespace)
 * is injected automatically, so experiments don't need imports.
 *
 * The source body is wrapped in `return (source)` inside a generated
 * function and called with `ui` as the sole argument. This keeps the
 * eval surface narrow: one parameter, one return, no shared closure.
 */

import type { UINode } from "plushie"
import * as ui from "plushie/ui"

export interface CompileOk {
  readonly ok: true
  readonly node: UINode
}

export interface CompileError {
  readonly ok: false
  readonly message: string
}

export type CompileResult = CompileOk | CompileError

/**
 * Compile an experiment's source and evaluate it, returning the
 * resulting view node. Any parse or runtime error is captured as a
 * CompileError with the message from the thrown Error.
 */
export function compileAndRender(source: string): CompileResult {
  try {
    // eslint-disable-next-line @typescript-eslint/no-implied-eval
    const fn = new Function("ui", `"use strict"; return (${source});`)
    const node = fn(ui) as UINode
    if (!node || typeof node !== "object" || typeof (node as { id?: unknown }).id !== "string") {
      return { ok: false, message: "Experiment did not return a view node. The last expression must be a UINode (for example `ui.column(...)`)." }
    }
    return { ok: true, node }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    return { ok: false, message }
  }
}
