//! "Hello, world" experiment.
//!
//! The smallest possible thing: a greeting and a button that
//! tells the pad "I was clicked" by flipping a counter in the
//! experiment's own state.

use plushie::prelude::*;

use super::Experiment;

#[derive(Default)]
pub struct Hello {
    waves: u32,
}

impl Experiment for Hello {
    fn name(&self) -> &'static str {
        "hello"
    }

    fn source(&self) -> &'static str {
        include_str!("hello.rs")
    }

    fn view(&self) -> View {
        column()
            .spacing(12.0)
            .padding(16)
            .child(text("Hello, world!").size(24.0))
            .child(text(&format!("waves: {}", self.waves)).id("waves").size(14.0))
            .child(button("wave", "Wave"))
            .into()
    }

    fn update(&mut self, event: &Event) -> bool {
        if let Some(Click("wave")) = event.widget_match() {
            self.waves += 1;
            return true;
        }
        false
    }
}
