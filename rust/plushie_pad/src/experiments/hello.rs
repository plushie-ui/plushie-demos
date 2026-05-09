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

#[cfg(test)]
mod tests {
    use super::*;
    use plushie::event::{EventType, WidgetEvent as RawWidgetEvent};
    use plushie::test::TestSession;
    use serde_json::Value;

    fn click_event(id: &str) -> Event {
        Event::Widget(RawWidgetEvent {
            event_type: EventType::Click,
            scoped_id: ScopedId::parse(id),
            value: Value::Null,
        })
    }

    struct HelloApp;

    impl App for HelloApp {
        type Model = Hello;

        fn init() -> (Self::Model, Command) {
            (Hello::default(), Command::none())
        }

        fn update(model: &mut Self::Model, event: Event) -> Command {
            model.update(&event);
            Command::none()
        }

        fn view(model: &Self::Model, _w: &mut WidgetRegistrar) -> ViewList {
            window("main").child(model.view()).into()
        }
    }

    #[test]
    fn starts_at_zero_waves() {
        let session = TestSession::<HelloApp>::start();
        assert_eq!(session.model().waves, 0);
    }

    #[test]
    fn wave_increments_counter() {
        let mut session = TestSession::<HelloApp>::start();
        session.click("wave");
        assert_eq!(session.model().waves, 1);
    }

    #[test]
    fn multiple_waves_accumulate() {
        let mut session = TestSession::<HelloApp>::start();
        session.click("wave");
        session.click("wave");
        session.click("wave");
        assert_eq!(session.model().waves, 3);
    }

    #[test]
    fn view_shows_wave_count() {
        let mut session = TestSession::<HelloApp>::start();
        session.assert_text("waves", "waves: 0");
        session.click("wave");
        session.assert_text("waves", "waves: 1");
    }

    #[test]
    fn unrelated_click_returns_false_and_leaves_state_unchanged() {
        let mut hello = Hello::default();
        let changed = hello.update(&click_event("other_button"));
        assert!(!changed);
        assert_eq!(hello.waves, 0);
    }

    #[test]
    fn wave_click_returns_true() {
        let mut hello = Hello::default();
        let changed = hello.update(&click_event("wave"));
        assert!(changed);
    }

    #[test]
    fn name_is_hello() {
        assert_eq!(Hello::default().name(), "hello");
    }

    #[test]
    fn source_contains_struct_name() {
        assert!(Hello::default().source().contains("Hello"));
    }
}
