# Sparkline Dashboard

Live system monitor dashboard built with [Plushie](https://github.com/plushie-ui/plushie-ruby)
and a custom Rust sparkline extension.

Demonstrates:

- Native Rust widget extensions via `include Plushie::Extension`
- Canvas-based custom rendering on the Rust side
- Timer subscriptions for live data updates
- Elm architecture (init/update/view/subscribe)

## Prerequisites

- Ruby 3.2+
- Rust toolchain ([rustup](https://rustup.rs/))
- Plushie SDK (path dependency to `../../../plushie-ruby`)

## Setup

    bundle install

## Build the custom renderer

The sparkline widget is a native Rust extension. Build a custom
renderer binary that includes it:

    bundle exec rake plushie:build

For a release (optimized) build:

    bundle exec rake plushie:build[release]

## Run

    bundle exec ruby lib/dashboard.rb

## Test

    bundle exec rake test

## How it works

The app has two halves:

**Ruby side** (`lib/sparkline_extension.rb`): declares the sparkline widget
type, its props (data, color, stroke_width, fill, height), and the Rust
crate that renders it.

**Rust side** (`native/sparkline/src/lib.rs`): implements `WidgetExtension`
to render a canvas-based line chart from the props. Uses iced's
`canvas::Program` trait for custom drawing.

The dashboard app (`lib/dashboard.rb`) uses timer subscriptions to
generate simulated metrics every 500ms. Each tick adds a sample to the
model; the view passes the samples as props to the sparkline extension
widgets. The Rust renderer reads the data array and draws the chart.
