/**
 * Shared state manager for collaborative modes.
 *
 * Holds the authoritative model and a registry of connected clients.
 * When any client sends an event, runs update() and broadcasts the
 * new model to all clients. Dark mode is per-client -- each client
 * stores its own preference and merges it before rendering.
 */

import { init, update } from "./collab.js"
import type { Model } from "./collab.js"

/** Event from the wire protocol (simplified for the server). */
export interface WireEvent {
  readonly family: string
  readonly id: string
  readonly value?: unknown
}

/** Callback to send a model snapshot to a client. */
export type SendSnapshot = (model: Model) => void

interface ClientEntry {
  send: SendSnapshot
  darkMode: boolean
}

export class Shared {
  private model: Model
  private clients = new Map<string, ClientEntry>()
  private nextId = 0

  constructor() {
    this.model = init()
  }

  /** Register a new client. Returns the client ID. */
  connect(send: SendSnapshot): string {
    const id = `client_${++this.nextId}`
    this.clients.set(id, { send, darkMode: false })
    this.updateStatus()
    this.sendTo(id)
    return id
  }

  /** Unregister a client. */
  disconnect(clientId: string): void {
    this.clients.delete(clientId)
    this.updateStatus()
    this.broadcastAll()
  }

  /** Handle a wire event from a client. */
  handleEvent(clientId: string, event: WireEvent): void {
    const client = this.clients.get(clientId)
    if (!client) return

    // Dark mode toggle: per-client, don't broadcast
    if (event.family === "toggle" && event.id === "theme") {
      client.darkMode = !client.darkMode
      this.sendTo(clientId)
      return
    }

    // Apply event to the shared model via the app's update function
    const updated = update(this.model, event.family, event.id, event.value)
    if (updated === this.model) return
    this.model = updated
    this.broadcastAll()
  }

  /** Get the current model (for testing). */
  getModel(): Readonly<Model> {
    return this.model
  }

  /** Get the number of connected clients. */
  get clientCount(): number {
    return this.clients.size
  }

  // -- Private ----------------------------------------------------------------

  private updateStatus(): void {
    const n = this.clients.size
    this.model = {
      ...this.model,
      status: n === 0 ? "" : `${n} connected`,
    }
  }

  private sendTo(clientId: string): void {
    const client = this.clients.get(clientId)
    if (!client) return
    client.send({ ...this.model, darkMode: client.darkMode })
  }

  private broadcastAll(): void {
    for (const [id] of this.clients) {
      this.sendTo(id)
    }
  }
}
