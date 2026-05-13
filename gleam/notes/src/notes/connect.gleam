//// Renderer-parent entry point for the notes app.
////
//// The plushie renderer starts this module with `--listen` and passes
//// connection details through `PLUSHIE_SOCKET` and `PLUSHIE_TOKEN`.

import gleam/io
import gleam/option
import notes/app
import plushie
import plushie/platform
import plushie/protocol
import plushie/socket_adapter

pub fn main() {
  let socket = resolve_socket()
  let token = resolve_token()
  let format = protocol.Msgpack

  case socket_adapter.start(socket, format) {
    Ok(adapter) -> {
      let opts =
        plushie.StartOpts(
          ..plushie.default_start_opts(),
          binary_path: option.None,
          format: format,
          transport: plushie.Iostream(adapter: adapter),
          token: token,
        )

      case plushie.start(app.app(), opts) {
        Ok(instance) -> plushie.wait(instance)
        Error(err) -> {
          io.println_error(
            "Failed to start plushie: " <> plushie.start_error_to_string(err),
          )
          halt(1)
        }
      }
    }
    Error(reason) -> {
      io.println_error("Failed to connect to renderer: " <> reason)
      halt(1)
    }
  }
}

fn resolve_token() -> option.Option(String) {
  case platform.get_env("PLUSHIE_TOKEN") {
    Ok(token) -> option.Some(token)
    Error(_) -> option.None
  }
}

fn resolve_socket() -> String {
  case platform.get_env("PLUSHIE_SOCKET") {
    Ok(socket) -> socket
    Error(_) -> {
      io.println_error("PLUSHIE_SOCKET is required.")
      halt(1)
      panic as "unreachable"
    }
  }
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
