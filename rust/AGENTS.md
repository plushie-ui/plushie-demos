# AGENTS.md

## Rust Demos

The Rust area currently contains the Plushie Pad demo. It is a normal
Cargo project and should stay independent from the host SDK demos.

## Setup

Use the stable Rust toolchain.

## Commands

Run `just preflight` in `rust/` to verify Rust demos.

For one demo:

```sh
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-targets --all-features
```
