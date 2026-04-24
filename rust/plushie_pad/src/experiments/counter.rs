//! Stateful counter experiment.
//!
//! Shows the classic plus/minus/reset counter pattern. Useful for
//! verifying that the pad actually routes events through to the
//! experiment: if the number changes, routing works.

use plushie::prelude::*;

use super::Experiment;

#[derive(Default)]
pub struct Counter {
    count: i32,
}

impl Experiment for Counter {
    fn name(&self) -> &'static str {
        "counter"
    }

    fn source(&self) -> &'static str {
        include_str!("counter.rs")
    }

    fn view(&self) -> View {
        column()
            .spacing(12.0)
            .padding(16)
            .child(text(&format!("Count: {}", self.count)).id("count").size(20.0))
            .child(
                row()
                    .spacing(8.0)
                    .children([
                        button("inc", "+"),
                        button("dec", "-"),
                        button("reset", "Reset"),
                    ]),
            )
            .into()
    }

    fn update(&mut self, event: &Event) -> bool {
        match event.widget_match() {
            Some(Click("inc")) => {
                self.count += 1;
                true
            }
            Some(Click("dec")) => {
                self.count -= 1;
                true
            }
            Some(Click("reset")) => {
                self.count = 0;
                true
            }
            _ => false,
        }
    }
}
