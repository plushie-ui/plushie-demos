#!/usr/bin/env bash
# Mode 4: Native desktop app started from Rust (plushie spawns Gleam)
# The renderer creates a socket via --listen, then spawns Gleam via structured exec args.
# Gleam connects back over the socket using plushie/connect.
cd "$(dirname "$0")/.."
bin/plushie --listen \
  --exec-bin gleam \
  --exec-arg run \
  --exec-arg -m \
  --exec-arg demo/connect
