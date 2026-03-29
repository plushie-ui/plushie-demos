# TypeScript Demos

Example applications for
[plushie-typescript](https://github.com/plushie-ui/plushie-typescript).

## Demos

| Demo | Description |
|------|-------------|
| [data-explorer](data-explorer/) | Data query pipeline + SEA standalone packaging -- browse, search, sort countries |
| [collab](collab/) | Collaborative scratchpad -- 6 ways to run the same app (native, WebSocket, SSH, WASM) |
| [crash-test](crash-test/) | Error resilience -- Rust panic isolation and TypeScript runtime recovery |
| [gauge-demo](gauge-demo/) | Native Rust widget with commands -- interactive gauge |
| [sparkline-dashboard](sparkline-dashboard/) | Render-only native Rust widget with canvas -- live system monitor |
| [examples](https://github.com/plushie-ui/plushie-typescript/tree/main/examples) | Single-file apps: Counter, Todo, Notes, Clock, Canvas, and more |

## Setup

Each demo is a standalone project. `cd` into the demo directory and
follow its README.

All demos require the plushie binary. Either download a precompiled
binary (`npx plushie download`) or build from source. Extension demos
Native widget demos also require the plushie Rust source for building
custom binaries.
