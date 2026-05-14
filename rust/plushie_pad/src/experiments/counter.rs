//! Stateful counter experiment.
//!
//! Shows the classic plus/minus/reset counter pattern. Useful for
//! verifying that the pad actually routes events through to the
//! experiment: if the number changes, routing works.

use plushie::prelude::*;

use super::Experiment;

#[derive(Clone, Default)]
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
            .child(
                text(&format!("Count: {}", self.count))
                    .id("count")
                    .size(20.0),
            )
            .child(row().spacing(8.0).children([
                button("inc", "+"),
                button("dec", "-"),
                button("reset", "Reset"),
            ]))
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

    struct CounterApp;

    impl App for CounterApp {
        type Model = Counter;

        fn init() -> (Self::Model, Command) {
            (Counter::default(), Command::none())
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
    fn starts_at_zero() {
        let session = TestSession::<CounterApp>::start();
        assert_eq!(session.model().count, 0);
    }

    #[test]
    fn inc_increments() {
        let mut session = TestSession::<CounterApp>::start();
        session.click("inc");
        assert_eq!(session.model().count, 1);
    }

    #[test]
    fn dec_decrements() {
        let mut session = TestSession::<CounterApp>::start();
        session.click("dec");
        assert_eq!(session.model().count, -1);
    }

    #[test]
    fn reset_zeroes_after_increments() {
        let mut session = TestSession::<CounterApp>::start();
        session.click("inc");
        session.click("inc");
        session.click("inc");
        session.click("reset");
        assert_eq!(session.model().count, 0);
    }

    #[test]
    fn mixed_inc_dec() {
        let mut session = TestSession::<CounterApp>::start();
        session.click("inc");
        session.click("inc");
        session.click("dec");
        assert_eq!(session.model().count, 1);
    }

    #[test]
    fn can_go_negative() {
        let mut session = TestSession::<CounterApp>::start();
        session.click("dec");
        session.click("dec");
        assert_eq!(session.model().count, -2);
    }

    #[test]
    fn view_text_tracks_count() {
        let mut session = TestSession::<CounterApp>::start();
        session.assert_text("count", "Count: 0");
        session.click("inc");
        session.assert_text("count", "Count: 1");
        session.click("dec");
        session.assert_text("count", "Count: 0");
    }

    #[test]
    fn unrelated_click_returns_false() {
        let mut counter = Counter::default();
        let changed = counter.update(&click_event("other"));
        assert!(!changed);
        assert_eq!(counter.count, 0);
    }

    #[test]
    fn inc_returns_true() {
        let mut counter = Counter::default();
        assert!(counter.update(&click_event("inc")));
    }

    #[test]
    fn name_is_counter() {
        assert_eq!(Counter::default().name(), "counter");
    }
}
