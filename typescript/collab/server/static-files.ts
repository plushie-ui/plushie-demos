/**
 * Static file serving for the browser client.
 *
 * Serves files from the static/ directory. Used by the WebSocket
 * and SSH server modes.
 */

import { readFileSync, existsSync } from "node:fs"
import { join, extname } from "node:path"
import type { IncomingMessage, ServerResponse } from "node:http"

const STATIC_DIR = new URL("../static", import.meta.url).pathname

const MIME_TYPES: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript",
  ".mjs": "application/javascript",
  ".css": "text/css",
  ".json": "application/json",
  ".wasm": "application/wasm",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
}

export function serveStatic(
  req: IncomingMessage,
  res: ServerResponse,
): void {
  const url = req.url ?? "/"
  const path = url === "/" ? "/index.html" : url.split("?")[0]!

  // Prevent path traversal
  if (path.includes("..")) {
    res.writeHead(403)
    res.end("Forbidden")
    return
  }

  const filePath = join(STATIC_DIR, path)
  if (!existsSync(filePath)) {
    res.writeHead(404)
    res.end("Not found")
    return
  }

  try {
    const data = readFileSync(filePath)
    const ext = extname(filePath)
    const contentType = MIME_TYPES[ext] ?? "application/octet-stream"
    res.writeHead(200, { "Content-Type": contentType })
    res.end(data)
  } catch {
    res.writeHead(500)
    res.end("Internal server error")
  }
}
