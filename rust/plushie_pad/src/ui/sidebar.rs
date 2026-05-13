//! Sidebar listing the available experiments.
//!
//! Each row is a button with an ID of `pick_<index>`. The pad's
//! `update` matches those IDs to select the experiment. Using a
//! numeric index (rather than the display name) keeps the ID
//! short and avoids worrying about whitespace or punctuation in
//! the sidebar label.

use plushie::prelude::*;

use crate::experiments::Experiment;

pub fn view(experiments: &[Box<dyn Experiment>], selected: usize) -> View {
    let mut list = column().id("list").spacing(4.0).padding(Padding::all(8.0));
    for (index, exp) in experiments.iter().enumerate() {
        let id = format!("pick_{index}");
        let style = if index == selected {
            Style::primary()
        } else {
            Style::text()
        };
        list = list.child(button(&id, exp.name()).width(Fill).style(style));
    }

    container()
        .id("sidebar")
        .width(Length::Fixed(180.0))
        .height(Fill)
        .border(Border::default().width(1.0).color(Color::hex("#333333")))
        .child(scrollable().id("scroll").height(Fill).child(list))
        .into()
}
