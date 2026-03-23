/**
 * Mode 5: SSH + WebSocket server with shared state.
 *
 * Everything from the WebSocket server (mode 2), plus an SSH daemon
 * on port 2222. Native plushie clients connect via:
 *
 *   plushie --exec "ssh -T -s -p 2222 -o StrictHostKeyChecking=no localhost plushie"
 *
 * The SSH handler speaks the plushie wire protocol (msgpack with
 * 4-byte length-prefix framing) and routes events to the same
 * shared state as the WebSocket clients.
 *
 * Usage:
 *   npx tsx server/ssh.ts
 */

import { createServer } from "node:http"
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { join } from "node:path"
import { generateKeyPairSync } from "node:crypto"
import { WebSocketServer } from "ws"
import type { WebSocket } from "ws"
import { Server as SshServer } from "ssh2"
import type { Connection, ServerChannel } from "ssh2"
import { encode as msgpackEncode, decode as msgpackDecode } from "@msgpack/msgpack"
import {
  encodeSnapshot,
  encodeSettings,
  encodePacket,
  decodePackets,
  normalize,
} from "plushie/client"
import { Shared } from "../src/shared.js"
import { view } from "../src/collab.js"
import type { Model } from "../src/collab.js"
import { serveStatic } from "./static-files.js"

const HTTP_PORT = 8080
const SSH_PORT = 2222
const HOST_KEY_DIR = "/tmp/plushie_demo_ssh_keys"

const shared = new Shared()

// -- HTTP + WebSocket ---------------------------------------------------------

const httpServer = createServer((req, res) => {
  serveStatic(req, res)
})

const wss = new WebSocketServer({ server: httpServer, path: "/ws" })

wss.on("connection", (ws: WebSocket) => {
  let clientId: string | null = null
  let handshakeDone = false

  const settings = encodeSettings("pending", { default_event_rate: 30 })
  ws.send(JSON.stringify(settings))

  ws.on("message", (data: Buffer | string) => {
    try {
      const msg = JSON.parse(
        typeof data === "string" ? data : data.toString("utf-8"),
      ) as Record<string, unknown>

      if (!handshakeDone && msg["type"] === "hello") {
        handshakeDone = true
        clientId = shared.connect((model: Model) => {
          sendWsSnapshot(ws, clientId!, model)
        })
        return
      }

      if (!handshakeDone || !clientId) return

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

function sendWsSnapshot(ws: WebSocket, session: string, model: Model): void {
  if (ws.readyState !== ws.OPEN) return
  const tree = view(model)
  const normalized = normalize(tree)
  const snapshot = encodeSnapshot(session, normalized)
  ws.send(JSON.stringify(snapshot))
}

// -- SSH daemon ---------------------------------------------------------------

function ensureHostKey(): Buffer {
  mkdirSync(HOST_KEY_DIR, { recursive: true })
  const keyPath = join(HOST_KEY_DIR, "host_rsa")

  if (existsSync(keyPath)) {
    return readFileSync(keyPath)
  }

  console.log("Generating SSH host key...")
  const { privateKey } = generateKeyPairSync("rsa", {
    modulusLength: 2048,
    privateKeyEncoding: { type: "pkcs8", format: "pem" },
    publicKeyEncoding: { type: "spki", format: "pem" },
  })
  writeFileSync(keyPath, privateKey, { mode: 0o600 })
  return Buffer.from(privateKey)
}

const sshServer = new SshServer(
  { hostKeys: [ensureHostKey()] },
  (client: Connection) => {
    client.on("authentication", (ctx) => {
      // No authentication -- demo only
      ctx.accept()
    })

    client.on("session", (accept) => {
      const session = accept()

      session.on("subsystem", (accept, _reject, info) => {
        if (info.name !== "plushie") return

        const channel: ServerChannel = accept()
        handleSshChannel(channel)
      })
    })
  },
)

function handleSshChannel(channel: ServerChannel): void {
  let clientId: string | null = null
  let handshakeDone = false
  let buffer = new Uint8Array(0)

  channel.on("error", () => {
    // Ignore write errors on destroyed channels
  })

  // Send settings to start the handshake
  const settings = encodeSettings("pending", { default_event_rate: 30 })
  const settingsBytes = msgpackEncode(settings)
  channel.write(Buffer.from(encodePacket(new Uint8Array(settingsBytes))))

  channel.on("data", (data: Buffer) => {
    // Accumulate data and decode msgpack frames
    const combined = new Uint8Array(buffer.length + data.length)
    combined.set(buffer)
    combined.set(new Uint8Array(data), buffer.length)

    const { messages, remaining } = decodePackets(combined)
    buffer = remaining

    for (const msgBytes of messages) {
      try {
        const msg = msgpackDecode(msgBytes) as Record<string, unknown>

        // Wait for hello to complete handshake
        if (!handshakeDone && msg["type"] === "hello") {
          handshakeDone = true
          clientId = shared.connect((model: Model) => {
            sendSshSnapshot(channel, clientId!, model)
          })
          continue
        }

        if (!handshakeDone || !clientId) continue

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
    }
  })

  channel.on("close", () => {
    if (clientId) shared.disconnect(clientId)
  })
}

function sendSshSnapshot(
  channel: ServerChannel,
  session: string,
  model: Model,
): void {
  if (channel.destroyed) return
  const tree = view(model)
  const normalized = normalize(tree)
  const snapshot = encodeSnapshot(session, normalized)
  const bytes = msgpackEncode(snapshot)
  channel.write(Buffer.from(encodePacket(new Uint8Array(bytes))))
}

// -- Start both servers -------------------------------------------------------

httpServer.listen(HTTP_PORT, "127.0.0.1", () => {
  console.log(`WebSocket server: http://127.0.0.1:${HTTP_PORT}`)
  console.log(`Browser client:   http://127.0.0.1:${HTTP_PORT}/websocket.html`)
})

sshServer.listen(SSH_PORT, "127.0.0.1", () => {
  console.log(`SSH server:       127.0.0.1:${SSH_PORT}`)
  console.log()
  console.log("Connect a native renderer via SSH:")
  console.log(
    `  plushie --exec "ssh -T -s -p ${SSH_PORT} -o StrictHostKeyChecking=no localhost plushie"`,
  )
})
