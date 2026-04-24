# Plushie Pad (Ruby)

A live Ruby experiment editor. The pad dogfoods the Plushie Ruby
SDK: type Ruby code in the editor, hit Save, and the pad evaluates
and renders the result in the preview pane. Each experiment is a
plain Ruby module that defines `Experiment.view`.

## Why plain Ruby?

Ruby ships an evaluator in its standard library (`Kernel#eval`,
`Module.module_eval`). The pad builds a fresh anonymous module per
compile, evaluates the user's source inside it, and calls
`view` on the resulting `Experiment` constant. No FFI, no subprocess,
no separate toolchain.

## Layout

```
bin/plushie_pad                 # launcher script
experiments/
  hello.rb                      # starter experiment
lib/
  plushie_pad.rb                # top-level require + module namespace
  plushie_pad/
    app.rb                      # main Elm loop (init/update/view/subscribe)
    compile.rb                  # module_eval wrapper
    experiments.rb              # list/load/save/delete on experiments/
Gemfile                         # Gemfile pinning the local plushie SDK
Rakefile                        # test + standard tasks
```

## Running

From this directory:

```bash
bundle install
bundle exec bin/plushie_pad
```

The Plushie renderer binary must be available. Set
`PLUSHIE_BINARY_PATH` to point at your local build, or set
`PLUSHIE_RUST_SOURCE_PATH=../../../plushie-rust` and run
`rake plushie:build` in the `plushie-ruby` gem first.

## Features

- Sidebar: lists every experiment, click to switch, delete button per row.
- Editor: syntax-highlighted `text_editor` with Ruby highlighting.
- Preview: evaluates the active source on save and renders the node.
- Toolbar: Save button, auto-save toggle, "new experiment name" input.
- Event log: last twenty events emitted by the preview.
- Undo/redo: Ctrl+Z / Ctrl+Shift+Z on the editor buffer, coalescing keystrokes.
- Save shortcut: Ctrl+S.
- Escape clears the compile error banner.

## Status

The pad mirrors the Gleam and Elixir pads' feature set adapted for
Ruby idioms. It relies on the following Plushie Ruby SDK features:

- `Plushie::App` mixin
- `Plushie::Model.define` with `#with`
- Typed builder classes for every widget used
- `Plushie::Command` (focus, task)
- `Plushie::Subscription.every` and `Plushie::Subscription.on_key_press`
- `Plushie::Undo` with coalesced push

See `docs/reference/` in the `plushie-ruby` repo for the full SDK
surface.
