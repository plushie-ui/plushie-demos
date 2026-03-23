//// Mode 2: WebSocket server with shared state.
////
//// Serves the plushie-wasm browser app over HTTP and establishes
//// WebSocket connections for each client. All clients share a single
//// app model via a shared actor on the BEAM. The server encodes
//// snapshots and the browser's plushie-wasm decodes them.
////
//// Architecture:
////   Browser (plushie-wasm) <--WebSocket--> Mist <--actor msg--> Shared Actor
////
//// When any client sends an event, the shared actor updates the
//// model and broadcasts the new model to all connected clients.
//// Each client's WebSocket handler re-renders with the client's
//// own dark_mode and sends the snapshot.
////
//// Run: gleam run -m demo/websocket_server

import demo/collab
import demo/shared.{type ClientMsg, type SharedMsg, ModelChanged}
import demo/static_server
import gleam/bit_array
import gleam/erlang/process.{type Subject}
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/int
import gleam/io
import gleam/option.{Some}
import gleam/result
import mist.{type WebsocketConnection, type WebsocketMessage}
import plushie/event.{WidgetToggle}
import plushie/node
import plushie/protocol
import plushie/protocol/decode as proto_decode
import plushie/protocol/encode as proto_encode

/// Per-WebSocket-connection state.
type WsState {
  WsState(
    id: String,
    shared: Subject(SharedMsg),
    dark_mode: Bool,
    last_model: collab.Model,
    client_subject: Subject(ClientMsg),
  )
}

pub fn main() {
  let assert Ok(shared) = shared.start()
  io.println("Shared actor started")

  let assert Ok(_) =
    mist.new(fn(req) { handle_request(req, shared) })
    |> mist.port(8080)
    |> mist.bind("127.0.0.1")
    |> mist.start()

  io.println("WebSocket server listening on http://localhost:8080")
  process.sleep_forever()
}

fn handle_request(
  req: Request(mist.Connection),
  shared: Subject(SharedMsg),
) -> response.Response(mist.ResponseData) {
  case request.path_segments(req) {
    ["ws"] -> handle_websocket(req, shared)
    segments -> static_server.serve_static(segments)
  }
}

/// Handle a WebSocket upgrade request. Public so ssh_server can reuse it.
pub fn handle_websocket_public(
  req: Request(mist.Connection),
  shared: Subject(SharedMsg),
) -> response.Response(mist.ResponseData) {
  handle_websocket(req, shared)
}

fn handle_websocket(
  req: Request(mist.Connection),
  shared: Subject(SharedMsg),
) -> response.Response(mist.ResponseData) {
  let client_id = "ws-" <> int.to_string(erlang_unique_integer())

  let #(initial_model, _) = collab.init()

  mist.websocket(
    request: req,
    on_init: fn(_conn) {
      let client_subject = process.new_subject()

      // Register with shared actor
      process.send(shared, shared.ClientConnect(client_id, client_subject))

      // Build a selector so we receive ClientMsg as WebSocket custom messages
      let selector =
        process.new_selector()
        |> process.select(client_subject)

      #(
        WsState(
          id: client_id,
          shared: shared,
          dark_mode: False,
          last_model: initial_model,
          client_subject: client_subject,
        ),
        Some(selector),
      )
    },
    handler: fn(state, msg, conn) { handle_ws_message(state, msg, conn) },
    on_close: fn(state) {
      process.send(state.shared, shared.ClientDisconnect(state.id))
    },
  )
}

fn handle_ws_message(
  state: WsState,
  msg: WebsocketMessage(ClientMsg),
  conn: WebsocketConnection,
) -> mist.Next(WsState, ClientMsg) {
  case msg {
    // Browser sent a text message (plushie wire protocol JSON)
    mist.Text(text) -> {
      let data = bit_array.from_string(text)
      case proto_decode.decode_message(data, protocol.Json) {
        Ok(proto_decode.EventMessage(event)) -> {
          // Handle dark_mode toggle locally (per-client, not shared)
          case event {
            WidgetToggle(id: "theme", value: checked, ..) -> {
              let new_state = WsState(..state, dark_mode: checked)
              // Re-render with new dark_mode
              let client_model =
                collab.Model(..state.last_model, dark_mode: checked)
              send_snapshot(conn, client_model)
              mist.continue(new_state)
            }
            _ -> {
              // Forward all other events to shared actor
              process.send(state.shared, shared.ClientEvent(state.id, event))
              mist.continue(state)
            }
          }
        }
        Ok(proto_decode.Hello(..)) -> {
          // Browser renderer sent hello -- ignore, snapshot already sent
          // on connect via the shared actor's ClientConnect response
          mist.continue(state)
        }
        Error(_) -> {
          mist.continue(state)
        }
      }
    }

    // Shared actor pushed a model update
    mist.Custom(ModelChanged(model)) -> {
      // Apply per-client dark_mode
      let client_model = collab.Model(..model, dark_mode: state.dark_mode)
      send_snapshot(conn, client_model)
      let new_state = WsState(..state, last_model: model)
      mist.continue(new_state)
    }

    mist.Binary(_) -> mist.continue(state)
    mist.Closed | mist.Shutdown -> mist.stop()
  }
}

/// Render a model to a tree, encode as snapshot JSON, and send over WebSocket.
fn send_snapshot(conn: WebsocketConnection, model: collab.Model) -> Nil {
  let tree = collab.view(model)
  case encode_snapshot(tree) {
    Ok(json_str) -> {
      let _ = mist.send_text_frame(conn, json_str)
      Nil
    }
    Error(_) -> Nil
  }
}

/// Encode a node tree as a snapshot JSON string (plushie wire protocol).
fn encode_snapshot(tree: node.Node) -> Result(String, Nil) {
  proto_encode.encode_snapshot(tree, "", protocol.Json)
  |> result.map(fn(bytes) {
    bit_array.to_string(bytes)
    |> result.unwrap("")
  })
  |> result.replace_error(Nil)
}

@external(erlang, "erlang", "unique_integer")
fn erlang_unique_integer() -> Int
