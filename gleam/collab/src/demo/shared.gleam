//// Shared state actor for collaborative modes.
////
//// Holds the authoritative model and a set of connected clients.
//// When any client sends an event, the actor runs update(), re-renders
//// the view, and broadcasts the new snapshot to ALL connected clients.
//// The dark_mode field is per-client and not broadcast.

import demo/collab
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/otp/actor
import plushie/event.{type Event}

/// Message type for the shared actor.
pub type SharedMsg {
  /// A client connected. Store their send function.
  ClientConnect(id: String, sender: Subject(ClientMsg))
  /// A client disconnected.
  ClientDisconnect(id: String)
  /// A client sent an event.
  ClientEvent(id: String, event: Event)
}

/// Messages sent TO individual clients.
pub type ClientMsg {
  /// The shared model changed -- here's the new snapshot.
  ModelChanged(collab.Model)
}

/// Internal state of the shared actor.
type SharedState {
  SharedState(model: collab.Model, clients: Dict(String, Subject(ClientMsg)))
}

/// Start the shared actor. Returns a Subject for sending SharedMsg.
pub fn start() -> Result(Subject(SharedMsg), actor.StartError) {
  let #(initial_model, _cmd) = collab.init()

  let result =
    actor.new(SharedState(model: initial_model, clients: dict.new()))
    |> actor.on_message(handle_message)
    |> actor.start()

  case result {
    Ok(started) -> Ok(started.data)
    Error(err) -> Error(err)
  }
}

fn handle_message(
  state: SharedState,
  msg: SharedMsg,
) -> actor.Next(SharedState, SharedMsg) {
  case msg {
    ClientConnect(id, sender) -> {
      let clients = dict.insert(state.clients, id, sender)
      let count = dict.size(clients)
      let model =
        collab.Model(
          ..state.model,
          status: int.to_string(count) <> " connected",
        )
      // Send current state to the new client
      process.send(sender, ModelChanged(model))
      // Update status for all existing clients
      broadcast_model(clients, model)
      actor.continue(SharedState(model: model, clients: clients))
    }

    ClientDisconnect(id) -> {
      let clients = dict.delete(state.clients, id)
      let count = dict.size(clients)
      let model =
        collab.Model(
          ..state.model,
          status: int.to_string(count) <> " connected",
        )
      broadcast_model(clients, model)
      actor.continue(SharedState(model: model, clients: clients))
    }

    ClientEvent(_id, event) -> {
      // Run the app's update function
      let #(new_model, _cmd) = collab.update(state.model, event)
      // Preserve status (managed by the actor, not the app)
      let count = dict.size(state.clients)
      let new_model =
        collab.Model(..new_model, status: int.to_string(count) <> " connected")
      // Broadcast to all clients
      broadcast_model(state.clients, new_model)
      actor.continue(SharedState(model: new_model, clients: state.clients))
    }
  }
}

fn broadcast_model(
  clients: Dict(String, Subject(ClientMsg)),
  model: collab.Model,
) {
  dict.each(clients, fn(_id, sender) {
    process.send(sender, ModelChanged(model))
  })
}
