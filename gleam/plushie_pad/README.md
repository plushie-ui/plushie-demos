# Plushie Pad (Gleam)

A live Erlang experiment editor. The pad dogfoods the Plushie Gleam
SDK: type code in the editor, hit save, and the pad compiles and
renders the result in the preview pane. Each experiment is an Erlang
module exporting `view/0`.

## Why Erlang experiments?

The pad compiles user-typed source at runtime. BEAM ships an
Erlang compiler in stdlib, but there is no Gleam compiler callable
from a running program, so experiments are written in Erlang.

See `docs/reference/erlang-interop.md` in the plushie-gleam repo
for the Gleam-to-Erlang mapping and the `pad_helpers` module
pattern this pad uses.

## Layout

```
src/
  plushie_pad.gleam              # entry point
  plushie_pad/
    app.gleam                    # main Elm loop
    compile.gleam                # Gleam wrapper for the compile FFI
    experiments.gleam            # list/load/save/delete on priv/experiments
  pad_helpers.erl                # ergonomic widget constructors for experiments
  plushie_pad_compile_ffi.erl    # erl_scan / erl_parse / compile:forms / load
priv/experiments/
  hello.erl                      # starter experiment
bin/preflight                    # local CI
```

## Status

Work in progress. The source here lays out the pad's architecture as
described in the plushie-gleam guides. Some helpers
(`undo.push_with_coalesce`, `app.with_subscribe`, `plushie.wait`,
`text_editor.HighlightSyntax`, `text_input.Placeholder`) don't yet
exist on the Gleam SDK; see the follow-up list in
`~/plushie-gleam-docs/callouts.md` and
`~/projects/plushie-sdk-parity/follow-up.md` for the missing pieces.

The pad will build once the SDK changes land. In the meantime it
serves as a reference for guide authors: the file layout and
module boundaries match what the guides teach.
