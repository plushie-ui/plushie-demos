//! Preview pane.
//!
//! Wraps the selected experiment's view in a container with the
//! explicit ID `preview`. Every event that originates inside the
//! experiment therefore carries `preview` somewhere in its scope,
//! which is what `PadApp::update` uses to decide whether to route
//! the event to the current experiment.

use plushie::prelude::*;

use crate::experiments::Experiment;

pub fn view(experiment: &dyn Experiment) -> View {
    container()
        .id("preview")
        .width(FillPortion(2))
        .height(Fill)
        .padding(8)
        .border(Border::default().width(1.0).color(Color::hex("#333333")))
        .child(experiment.view())
        .into()
}
