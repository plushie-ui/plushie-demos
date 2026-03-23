defmodule CrashTest do
  @moduledoc """
  Crash resilience demo for Plushie.

  Exercises three failure paths to show how the framework recovers:

  1. **Elixir `update/2` crash** -- `RuntimeError` in an event handler.
     The runtime catches it and rolls back the model to its
     pre-exception state.

  2. **Elixir `view/1` crash** -- `RuntimeError` during rendering.
     The runtime catches it and preserves the previous tree.
     The model rolls back so the crash is one-shot.

  3. **Rust extension panic** -- `panic!()` in `handle_command`.
     The renderer isolates it via `catch_unwind` and replaces the
     widget with a red placeholder. The rest of the app continues.

  A working counter proves the app keeps functioning through all
  crashes.

  ## Running

      mix plushie.gui CrashTest.App
  """
end
