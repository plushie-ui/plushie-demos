# Python Demos

Example projects using the [plushie Python SDK](https://github.com/plushie-ui/plushie-python).

## Demos

### [gauge-demo](gauge-demo/)

Temperature monitor with a native Rust gauge widget extension.
Demonstrates extension commands (`set_value`, `animate_to`),
optimistic updates, and `pyproject.toml` extension configuration.

### [sparkline-dashboard](sparkline-dashboard/)

Live system monitor with 3 sparkline charts for CPU, memory, and
network metrics. Demonstrates a render-only Rust canvas extension,
timer subscriptions, and simulated live data.

## Cross-language comparison

The same demos exist in other languages:

| Demo | Python | TypeScript | Ruby |
|---|---|---|---|
| Gauge | [gauge-demo](gauge-demo/) | [gauge-demo](../typescript/gauge-demo/) | -- |
| Sparkline Dashboard | [sparkline-dashboard](sparkline-dashboard/) | [sparkline-dashboard](../typescript/sparkline-dashboard/) | [sparkline-dashboard](../ruby/sparkline-dashboard/) |

The Rust extension code is identical across languages -- only the
host SDK code differs.
