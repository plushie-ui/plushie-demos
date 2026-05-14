//! Basic canvas experiment.
//!
//! Not interactive (no drag, no keyboard): just a plain drawing.
//! The point is to show that canvas layers and shape primitives
//! work inside an experiment the same way they do in a full app.

use plushie::prelude::*;
use plushie::ui::{canvas, circle, layer, line, rect};

use super::Experiment;

#[derive(Clone, Default)]
pub struct CanvasExperiment;

impl Experiment for CanvasExperiment {
    fn name(&self) -> &'static str {
        "canvas"
    }

    fn source(&self) -> &'static str {
        include_str!("canvas.rs")
    }

    fn view(&self) -> View {
        column()
            .padding(16)
            .spacing(12.0)
            .child(text("Canvas shapes").id("title").size(18.0))
            .child(
                canvas("sketch")
                    .width(320.0)
                    .height(200.0)
                    .child(
                        layer("bg").child(rect(0.0, 0.0, 320.0, 200.0).fill(Color::hex("#1a1a2e"))),
                    )
                    .child(
                        layer("shapes")
                            .child(
                                rect(20.0, 40.0, 80.0, 120.0)
                                    .fill(Color::hex("#3b82f6"))
                                    .radius(6.0),
                            )
                            .child(circle(180.0, 100.0, 50.0).fill(Color::hex("#22c55e")))
                            .child(
                                line(0.0, 180.0, 320.0, 180.0)
                                    .stroke(Color::hex("#94a3b8"))
                                    .stroke_width(2.0),
                            ),
                    ),
            )
            .into()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use plushie::test::TestSession;

    struct CanvasApp;

    impl App for CanvasApp {
        type Model = CanvasExperiment;

        fn init() -> (Self::Model, Command) {
            (CanvasExperiment, Command::none())
        }

        fn update(model: &Self::Model, _event: Event) -> (Self::Model, Command) {
            (model.clone(), Command::none())
        }

        fn view(model: &Self::Model, _w: &mut WidgetRegistrar) -> ViewList {
            window("main").child(model.view()).into()
        }
    }

    #[test]
    fn name_is_canvas() {
        assert_eq!(CanvasExperiment.name(), "canvas");
    }

    #[test]
    fn canvas_widget_exists_in_view() {
        let session = TestSession::<CanvasApp>::start();
        session.assert_exists("sketch");
    }

    #[test]
    fn title_widget_exists() {
        let session = TestSession::<CanvasApp>::start();
        session.assert_exists("title");
    }

    #[test]
    fn source_is_nonempty() {
        assert!(!CanvasExperiment.source().is_empty());
    }
}
