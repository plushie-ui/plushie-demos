//// Mode 5: SSH server with shared state.
////
//// Starts an Erlang :ssh daemon that accepts SSH connections. Each
//// SSH client gets an ssh_server_channel adapter that speaks the
//// plushie JSON wire protocol and participates in the shared actor
//// alongside WebSocket clients.
////
//// Architecture:
////   Native plushie --SSH--> :ssh daemon --> channel adapter --> Shared Actor
////   Browser (wasm) --WS--> Mist ------> ws handler --------> Shared Actor
////
//// Both SSH and WebSocket clients share the same actor, so changes
//// from any client propagate to all others in real time.
////
//// Run: gleam run -m demo/ssh_server
////   Starts SSH on port 2222 and HTTP+WS on port 8080
//// Then: plushie --json --exec "ssh -p 2222 -s plushie localhost"

import gleam/erlang/process.{type Subject}
import gleam/http/request
import gleam/io
import mist
import demo/shared.{type SharedMsg}
import demo/static_server
import demo/websocket_server

/// Start both the SSH daemon and the WebSocket server, sharing state.
pub fn main() {
  let assert Ok(shared) = shared.start()
  io.println("Shared actor started")

  // Start the SSH daemon on port 2222
  do_start_ssh_daemon(shared, 2222)
  io.println("SSH server listening on port 2222")

  // Start the WebSocket/HTTP server on port 8080 with the same shared actor
  let assert Ok(_) =
    mist.new(fn(req) {
      case request.path_segments(req) {
        ["ws"] -> websocket_server.handle_websocket_public(req, shared)
        segments -> static_server.serve_static(segments)
      }
    })
    |> mist.port(8080)
    |> mist.bind("127.0.0.1")
    |> mist.start()

  io.println("WebSocket server listening on http://localhost:8080")

  process.sleep_forever()
}

@external(erlang, "plushie_demo_ssh_ffi", "start_daemon")
fn do_start_ssh_daemon(shared: Subject(SharedMsg), port: Int) -> Nil
