//! Event log pane.
//!
//! Shows a rolling window of the most recent events the pad saw.
//! Newest events are at the top, so a busy stream doesn't force
//! the user to scroll to follow it.

use plushie::prelude::*;

pub fn view(entries: &[String]) -> View {
    let mut lines = column().id("lines").spacing(2.0).padding(Padding::all(6.0));
    for (index, entry) in entries.iter().enumerate() {
        lines = lines.child(
            text(entry)
                .id(&format!("line_{index}"))
                .font(Font::monospace())
                .size(11.0),
        );
    }

    container()
        .id("event_log")
        .width(Fill)
        .height(Length::Fixed(140.0))
        .border(Border::default().width(1.0).color(Color::hex("#333333")))
        .child(scrollable().id("scroll").height(Fill).child(lines))
        .into()
}
