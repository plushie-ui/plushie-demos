# AGENTS.md

## Gleam Demos

Each child directory is an independent Gleam project. Prefer the
existing `bin/preflight` script inside each demo because those scripts
encode which projects need native renderer builds.

## Setup

Use Erlang/OTP 26 or newer and Gleam 1.x. Native widget demos require
Rust. Set `PLUSHIE_RUST_SOURCE_PATH` when `gleam run -m plushie/build`
needs local renderer source.

## Commands

Run `just preflight` in `gleam/` to execute each demo's
`bin/preflight`.

For one demo:

```sh
gleam format --check
gleam build
gleam test
```

Native widget demos also run:

```sh
gleam run -m plushie/build
```
