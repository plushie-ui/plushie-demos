# AGENTS.md

## Elixir Demos

Each child directory is an independent Mix project. Run commands from
the demo directory unless the language-level `justfile` is driving the
sweep.

## Setup

Use Erlang/OTP 26 or newer and Elixir 1.15 or newer. Native widget
demos also require Rust and usually `PLUSHIE_RUST_SOURCE_PATH` pointing
at a plushie-rust checkout.

## Commands

Run `just preflight` in `elixir/` to verify every Elixir demo.

The language preflight runs dependency resolution, format checks,
compilation with warnings as errors, native renderer builds for demos
with `native/`, tests, and Dialyzer where the demo declares Dialyxir.

For one demo, use the same command sequence inside that demo:

```sh
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix plushie.build
mix test
mix dialyzer
```

Only run `mix plushie.build` and `mix dialyzer` when the demo supports
or needs them.
