//! Form experiment.
//!
//! Covers three input widgets at once: text input, checkbox, and
//! slider. The current values are echoed underneath so it's
//! obvious the pad is propagating events into the experiment's
//! state.

use plushie::prelude::*;

use super::Experiment;

#[derive(Clone)]
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
            .child(text_input("name", &self.name).placeholder("Your name"))
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

#[cfg(test)]
mod tests {
    use super::*;
    use plushie::test::TestSession;

    struct FormApp;

    impl App for FormApp {
        type Model = Form;

        fn init() -> (Self::Model, Command) {
            (Form::default(), Command::none())
        }

        fn update(model: &Self::Model, event: Event) -> (Self::Model, Command) {
            let mut model = model.clone();
            model.update(&event);
            (model, Command::none())
        }

        fn view(model: &Self::Model, _w: &mut WidgetRegistrar) -> ViewList {
            window("main").child(model.view()).into()
        }
    }

    #[test]
    fn starts_with_empty_name() {
        let session = TestSession::<FormApp>::start();
        assert_eq!(session.model().name, "");
    }

    #[test]
    fn starts_unsubscribed() {
        let session = TestSession::<FormApp>::start();
        assert!(!session.model().subscribed);
    }

    #[test]
    fn starts_at_default_volume() {
        let session = TestSession::<FormApp>::start();
        assert!((session.model().volume - 25.0).abs() < f32::EPSILON);
    }

    #[test]
    fn name_input_updates_model() {
        let mut session = TestSession::<FormApp>::start();
        session.type_text("name", "Arthur Dent");
        assert_eq!(session.model().name, "Arthur Dent");
    }

    #[test]
    fn subscribe_toggle_flips_state() {
        let mut session = TestSession::<FormApp>::start();
        session.set_toggle("subscribe", true);
        assert!(session.model().subscribed);
        session.set_toggle("subscribe", false);
        assert!(!session.model().subscribed);
    }

    #[test]
    fn slider_updates_volume() {
        let mut session = TestSession::<FormApp>::start();
        session.slide("volume", 75.0);
        assert!((session.model().volume - 75.0).abs() < f32::EPSILON);
    }

    #[test]
    fn echo_text_reflects_all_fields() {
        let mut session = TestSession::<FormApp>::start();
        session.type_text("name", "Zaphod");
        session.set_toggle("subscribe", true);
        session.slide("volume", 42.0);
        session.assert_text("echo", r#"name = "Zaphod", subscribed = true, volume = 42"#);
    }

    #[test]
    fn name_is_form() {
        assert_eq!(Form::default().name(), "form");
    }
}
