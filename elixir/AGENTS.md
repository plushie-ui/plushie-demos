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
compilation with warnings as errors, `mix plushie.download` for pure
demos, `mix plushie.build` for demos with `native/`, tests, and
Dialyzer where the demo declares Dialyxir.

For one demo, use the same command sequence inside that demo:

```sh
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix dialyzer
```

Run `mix plushie.download` before `mix test` in pure demos, and
`mix plushie.build` before `mix test` in native demos. Only run
`mix dialyzer` when the demo supports it.
