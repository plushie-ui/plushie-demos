//! Basic canvas experiment.
//!
//! Not interactive (no drag, no keyboard): just a plain drawing.
//! The point is to show that canvas layers and shape primitives
//! work inside an experiment the same way they do in a full app.

use plushie::prelude::*;
use plushie::ui::{canvas, circle, layer, line, rect};

use super::Experiment;

#[derive(Default)]
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
                        layer("bg").child(
                            rect(0.0, 0.0, 320.0, 200.0).fill(Color::hex("#1a1a2e")),
                        ),
                    )
                    .child(
                        layer("shapes")
                            .child(
                                rect(20.0, 40.0, 80.0, 120.0)
                                    .fill(Color::hex("#3b82f6"))
                                    .radius(6.0),
                            )
                            .child(
                                circle(180.0, 100.0, 50.0)
                                    .fill(Color::hex("#22c55e")),
                            )
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
