//! Plushie Pad (Rust) entry point.
//!
//! Opens the pad window and hands control to the Plushie runner.
//! The pad itself is implemented in the `app` module; everything
//! else is experiments and supporting UI helpers.

mod app;
mod experiments;
mod ui;

use app::PadApp;

fn main() -> plushie::Result {
    plushie::run::<PadApp>()
}
