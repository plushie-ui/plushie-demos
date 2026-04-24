//! Experiment gallery.
//!
//! Each experiment is a small self-contained app fragment. The pad
//! switches between them at runtime without recompiling, and shows
//! the real source of the selected experiment via `include_str!`.
//!
//! Adding a new experiment:
//!
//! 1. Create `src/experiments/my_experiment.rs` exposing a
//!    `pub struct MyExperiment` with `Default` plus an
//!    `impl Experiment` block.
//! 2. Add the module line below.
//! 3. Add one entry to `build_gallery()`.
//!
//! The `Experiment::source` method pins the source pane to the
//! on-disk file via `include_str!`, so the text shown to the user
//! always matches the built code.

use plushie::prelude::*;

pub mod canvas;
pub mod counter;
pub mod form;
pub mod hello;
pub mod list;

/// A single demo the pad can swap in at runtime.
///
/// Experiments own their transient state. The pad drives them:
/// `view` returns the render for the preview pane, `update` is
/// called once per event scoped into the preview, and `source`
/// points at the `.rs` file that produced `view`.
pub trait Experiment: Send {
    /// Short display name shown in the sidebar.
    fn name(&self) -> &'static str;

    /// The experiment's source code, read at compile time via
    /// `include_str!` so the preview pane and the shown text
    /// never drift.
    fn source(&self) -> &'static str;

    /// Build a single view fragment. The pad wraps this in its
    /// own scope container, so IDs declared here live under
    /// `preview/...`.
    fn view(&self) -> View;

    /// Handle an event that was scoped under the preview. Return
    /// `true` if the event changed state and the view should be
    /// considered dirty. The default is "ignore".
    fn update(&mut self, _event: &Event) -> bool {
        false
    }
}

/// Returns every experiment the pad knows about, in sidebar order.
pub fn build_gallery() -> Vec<Box<dyn Experiment>> {
    vec![
        Box::new(hello::Hello::default()),
        Box::new(counter::Counter::default()),
        Box::new(list::ListExperiment::default()),
        Box::new(canvas::CanvasExperiment::default()),
        Box::new(form::Form::default()),
    ]
}
