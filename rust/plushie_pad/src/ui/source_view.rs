//! Read-only source pane.
//!
//! The Rust pad does not compile user input at runtime (unlike the
//! Elixir and Gleam pads). Instead, each experiment ships its own
//! `.rs` file and the source pane displays it through a scrollable
//! text block. The only way to edit an experiment is to change
//! the source on disk and rebuild the pad.

use plushie::prelude::*;

pub fn view(source: &str) -> View {
    container()
        .id("source")
        .width(FillPortion(2))
        .height(Fill)
        .padding(8)
        .border(Border::default().width(1.0).color(Color::hex("#333333")))
        .child(
            scrollable().id("scroll").height(Fill).child(
                text(source)
                    .id("content")
                    .font(Font::monospace())
                    .size(12.0),
            ),
        )
        .into()
}
