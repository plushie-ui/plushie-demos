//! Form experiment.
//!
//! Covers three input widgets at once: text input, checkbox, and
//! slider. The current values are echoed underneath so it's
//! obvious the pad is propagating events into the experiment's
//! state.

use plushie::prelude::*;

use super::Experiment;

pub struct Form {
    name: String,
    subscribed: bool,
    volume: f32,
}

impl Default for Form {
    fn default() -> Self {
        Self {
            name: String::new(),
            subscribed: false,
            volume: 25.0,
        }
    }
}

impl Experiment for Form {
    fn name(&self) -> &'static str {
        "form"
    }

    fn source(&self) -> &'static str {
        include_str!("form.rs")
    }

    fn view(&self) -> View {
        column()
            .padding(16)
            .spacing(12.0)
            .width(Fill)
            .child(text("Form controls").id("title").size(18.0))
            .child(
                text_input("name", &self.name)
                    .placeholder("Your name"),
            )
            .child(checkbox("subscribe", self.subscribed).label("Subscribe to updates"))
            .child(slider("volume", (0.0, 100.0), self.volume).step(1.0))
            .child(
                text(&format!(
                    "name = {:?}, subscribed = {}, volume = {}",
                    self.name, self.subscribed, self.volume as i32
                ))
                .id("echo")
                .size(12.0),
            )
            .into()
    }

    fn update(&mut self, event: &Event) -> bool {
        match event.widget_match() {
            Some(Input("name", value)) => {
                self.name = value.to_string();
                true
            }
            Some(Toggle("subscribe", checked)) => {
                self.subscribed = checked;
                true
            }
            Some(Slide("volume", v)) => {
                self.volume = v as f32;
                true
            }
            _ => false,
        }
    }
}
