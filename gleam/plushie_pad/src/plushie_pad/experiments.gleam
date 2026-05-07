//// Experiment file management.
////
//// Experiments live under `priv/experiments/*.erl`. Each file is an
//// Erlang module exporting `view/0`. Listing / loading / saving /
//// creating / deleting all operate on that directory.

import gleam/list
import gleam/result
import gleam/string
import simplifile

const experiments_dir = "priv/experiments"

/// List all `.erl` files in the experiments directory (basenames).
pub fn list() -> List(String) {
  case simplifile.read_directory(experiments_dir) {
    Ok(entries) -> {
      entries
      |> list.filter(fn(name) { string.ends_with(name, ".erl") })
      |> list.sort(string.compare)
    }
    Error(_) -> []
  }
}

/// Load the source of the named experiment. Returns an empty string
/// on error rather than panicking so the editor has something to show.
pub fn load(name: String) -> String {
  simplifile.read(experiments_dir <> "/" <> name)
  |> result.unwrap("")
}

/// Save source for the named experiment. Errors are ignored here;
/// a production pad would surface them via the event log.
pub fn save(name: String, source: String) -> Nil {
  let _ = simplifile.write(experiments_dir <> "/" <> name, source)
  Nil
}

/// Delete the named experiment. Idempotent: missing files are not
/// an error.
pub fn delete(name: String) -> Nil {
  let _ = simplifile.delete(experiments_dir <> "/" <> name)
  Nil
}

/// Create a new empty experiment with a default view/0 body. Returns
/// the generated starter source.
pub fn starter_source(module_name: String) -> String {
  "-module("
  <> module_name
  <> ").\n"
  <> "-export([view/0]).\n\n"
  <> "view() ->\n"
  <> "    pad_helpers:column(<<\"root\">>,\n"
  <> "        [{padding, pad_helpers:padding_all(16.0)}, {spacing, 8.0}],\n"
  <> "        [\n"
  <> "            pad_helpers:text_size(<<\"title\">>, <<\"New experiment\">>, 20.0)\n"
  <> "        ]).\n"
}

/// Derive a module name from a filename (strip `.erl` suffix).
pub fn module_name_of(filename: String) -> String {
  case string.ends_with(filename, ".erl") {
    True -> string.drop_end(filename, 4)
    False -> filename
  }
}
