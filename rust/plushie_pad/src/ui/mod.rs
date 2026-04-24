//! Pad-specific UI helpers.
//!
//! The pad is itself a Plushie app, so its view is built from the
//! same widget functions every experiment uses. Splitting the
//! panes out keeps `app.rs` focused on the Elm loop and makes
//! each pane easy to tweak in isolation.

pub mod event_log;
pub mod preview;
pub mod sidebar;
pub mod source_view;
