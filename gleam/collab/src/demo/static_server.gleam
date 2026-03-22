//// Mode 1: Static file server for the client-side WASM app.
////
//// Serves static files from the static/ directory over HTTP using mist.
//// The entire app runs in the browser -- Gleam compiles to JS and drives
//// plushie-wasm (iced in WebAssembly) for rendering. No server-side
//// state; each browser tab is independent.
////
//// Run: gleam run -m demo/static_server

import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/io
import gleam/option.{None}
import gleam/string
import mist

pub fn main() {
  let assert Ok(_) =
    mist.new(handle_request)
    |> mist.port(8080)
    |> mist.bind("0.0.0.0")
    |> mist.start()

  io.println("Static server listening on http://0.0.0.0:8080")
  process.sleep_forever()
}

fn handle_request(
  req: Request(mist.Connection),
) -> response.Response(mist.ResponseData) {
  let segments = request.path_segments(req)
  serve_static(segments)
}

/// Serve static files from the static/ directory.
pub fn serve_static(
  segments: List(String),
) -> response.Response(mist.ResponseData) {
  let path = case segments {
    [] -> "static/index.html"
    _ -> "static/" <> string.join(segments, "/")
  }

  let content_type = guess_content_type(path)

  case mist.send_file(path, offset: 0, limit: None) {
    Ok(file_body) ->
      response.new(200)
      |> response.set_header("content-type", content_type)
      |> response.set_body(file_body)
    Error(_) ->
      response.new(404)
      |> response.set_body(mist.Bytes(
        bytes_tree.from_string("Not found"),
      ))
  }
}

/// Guess MIME type from file extension.
fn guess_content_type(path: String) -> String {
  case string.split(path, ".") |> last_element {
    "html" -> "text/html; charset=utf-8"
    "js" -> "application/javascript"
    "mjs" -> "application/javascript"
    "css" -> "text/css"
    "wasm" -> "application/wasm"
    "json" -> "application/json"
    "png" -> "image/png"
    "svg" -> "image/svg+xml"
    "ico" -> "image/x-icon"
    _ -> "application/octet-stream"
  }
}

fn last_element(items: List(String)) -> String {
  case items {
    [] -> ""
    [x] -> x
    [_, ..rest] -> last_element(rest)
  }
}
