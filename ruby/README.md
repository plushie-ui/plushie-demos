# Ruby demos

Example Plushie applications written in Ruby using the
[plushie-ruby](https://github.com/plushie-ui/plushie-ruby) SDK.

## Prerequisites

- [Ruby](https://www.ruby-lang.org/) (3.2+)
- [Rust](https://rustup.rs/) (for extension demos only)
- [plushie](https://github.com/plushie-ui/plushie) renderer binary

## Demos

### [examples](https://github.com/plushie-ui/plushie-ruby/tree/main/examples) (in main repo)

Single-file apps covering individual features: Counter, Todo, Notes,
Clock, Shortcuts, AsyncFetch, ColorPicker, Catalog, and RatePlushie.
Good starting points for learning the API -- events, commands, canvas
drawing, theming, custom widgets.

These live in the main plushie-ruby repo and run with `bundle exec ruby`.

### [collab](collab/)

Multi-transport collaborative scratchpad. Demonstrates 4 ways to run
the exact same Plushie app:

- **Native (Ruby spawns renderer)** -- standard desktop mode
- **Native (renderer spawns Ruby)** -- reverse startup via `--exec`
- **SSH** -- native renderer connecting through an SSH tunnel
- **WebSocket** -- shared state, multiple browser tabs see the same data

The dark-mode toggle is per-client; everything else is collaborative.

See [collab/README.md](collab/README.md) for setup instructions.

### [notes](notes/)

Notes app with pure Ruby composite widgets and state helpers. No Rust
required. Demonstrates Route (navigation), Selection (multi-select),
Undo (editor history), DataQuery (search and sort), and keyboard
shortcuts with a context-aware hint bar.

See [notes/README.md](notes/README.md) for setup instructions.

### [gauge-demo](gauge-demo/)

Temperature monitor with a native Rust gauge extension. Demonstrates
extension commands (`set_value`, `animate_to`), Rust-side state
management with `ExtensionCaches`, and the optimistic update pattern.

See [gauge-demo/README.md](gauge-demo/README.md) for setup instructions.

### [sparkline-dashboard](sparkline-dashboard/)

Live system monitor with a native Rust sparkline extension. Demonstrates
prop-driven canvas rendering, timer subscriptions, and multiple
extension widget instances.

See [sparkline-dashboard/README.md](sparkline-dashboard/README.md)
for setup instructions.
