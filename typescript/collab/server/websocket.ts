/**
 * Mode 2: WebSocket server with shared state.
 *
 * Starts an HTTP server that serves the WASM browser client and a
 * WebSocket endpoint. All connected browser tabs share the same model.
 *
 * Usage:
 *   npx tsx server/websocket.ts
 *   open http://localhost:8080/websocket.html
 */

import { createServer } from "node:http"
import { WebSocketServer } from "ws"
import type { WebSocket } from "ws"
import { encodeSnapshot, encodeSettings, normalize } from "plushie/client"
import { Shared, renderTree } from "../src/shared.js"
import type { Model } from "../src/collab.js"
import { serveStatic } from "./static-files.js"

const PORT = 8080
const shared = new Shared()

// -- HTTP + WebSocket server --------------------------------------------------

const server = createServer((req, res) => {
  serveStatic(req, res)
})

const wss = new WebSocketServer({ server, path: "/ws" })

wss.on("connection", (ws: WebSocket) => {
  let clientId: string | null = null
  let handshakeDone = false

  // Send settings to initiate the wire protocol handshake
  const settings = encodeSettings("pending", {
    default_event_rate: 30,
  })
  ws.send(JSON.stringify(settings))

  ws.on("message", (data: Buffer | string) => {
    try {
      const msg = JSON.parse(
        typeof data === "string" ? data : data.toString("utf-8"),
      ) as Record<string, unknown>

      // Wait for hello response to complete handshake
      if (!handshakeDone && msg["type"] === "hello") {
        handshakeDone = true
        clientId = shared.connect((model: Model) => {
          sendSnapshot(ws, clientId!, model)
        })
        return
      }

      if (!handshakeDone || !clientId) return

      // Route events to shared state
      if (msg["type"] === "event") {
        shared.handleEvent(clientId, {
          family: msg["family"] as string,
          id: msg["id"] as string,
          value: msg["value"],
        })
      }
    } catch {
      // Ignore malformed messages
    }
  })

  ws.on("close", () => {
    if (clientId) shared.disconnect(clientId)
  })
})

function sendSnapshot(ws: WebSocket, session: string, model: Model): void {
  if (ws.readyState !== ws.OPEN) return
  const tree = renderTree(model)
  const normalized = normalize(tree)
  const snapshot = encodeSnapshot(session, normalized)
  ws.send(JSON.stringify(snapshot))
}

server.listen(PORT, "127.0.0.1", () => {
  console.log(`WebSocket server: http://127.0.0.1:${PORT}`)
  console.log(`Browser client:   http://127.0.0.1:${PORT}/websocket.html`)
})
