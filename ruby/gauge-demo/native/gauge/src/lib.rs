//! Gauge widget extension for plushie.
//!
//! Renders a temperature gauge using iced container and text widgets.
//! Demonstrates the WidgetExtension trait with prepare, render,
//! handle_command, and new_instance.

use plushie_ext::iced;
use plushie_ext::prelude::*;

/// Gauge extension -- renders a numeric gauge with label and color.
pub struct GaugeExtension;

impl GaugeExtension {
    pub fn new() -> Self {
        Self
    }
}

/// Per-node state stored in ExtensionCaches.
///
/// Tracks Rust-side value for commands that need to update state
/// without a full tree round-trip (e.g. animate_to).
struct GaugeState {
    /// The value as set by the most recent set_value command.
    /// Overwritten by prepare() each frame from the Ruby-side prop,
    /// so this only matters between command receipt and next render.
    rust_value: f32,
}

impl GaugeState {
    fn new(value: f32) -> Self {
        Self { rust_value: value }
    }
}

impl WidgetExtension for GaugeExtension {
    fn type_names(&self) -> &[&str] {
        &["gauge"]
    }

    fn config_key(&self) -> &str {
        "gauge"
    }

    fn new_instance(&self) -> Box<dyn WidgetExtension> {
        Box::new(GaugeExtension::new())
    }

    fn prepare(
        &mut self,
        node: &TreeNode,
        caches: &mut ExtensionCaches,
        _theme: &Theme,
    ) {
        let value = prop_f32(node.props(), "value").unwrap_or(0.0);
        let state = caches.get_or_insert::<GaugeState>(
            self.config_key(),
            &node.id,
            || GaugeState::new(value),
        );
        // Sync from Ruby props each frame
        state.rust_value = value;
    }

    fn render<'a>(
        &self,
        node: &'a TreeNode,
        _env: &WidgetEnv<'a>,
    ) -> Element<'a, Message> {
        let props = node.props();
        let value = prop_f32(props, "value").unwrap_or(0.0);
        let min = prop_f32(props, "min").unwrap_or(0.0);
        let max = prop_f32(props, "max").unwrap_or(100.0);
        let color = prop_color(props, "color")
            .unwrap_or(Color::from_rgb(0.2, 0.5, 0.8));
        let label = prop_str(props, "label").unwrap_or_default();
        let w = prop_length(props, "width", Length::Fixed(200.0));
        let h = prop_length(props, "height", Length::Fixed(200.0));

        let pct = ((value - min) / (max - min)).clamp(0.0, 1.0);
        let display = format!("{:.0}%", pct * 100.0);

        container(
            iced::widget::column![
                text(label).size(16),
                text(display).size(32).color(color),
            ]
            .align_x(iced::alignment::Horizontal::Center),
        )
        .width(w)
        .height(h)
        .center(iced::Length::Fill)
        .into()
    }

    fn handle_command(
        &mut self,
        node_id: &str,
        op: &str,
        payload: &Value,
        caches: &mut ExtensionCaches,
    ) -> Vec<OutgoingEvent> {
        match op {
            "set_value" | "animate_to" => {
                if let Some(state) =
                    caches.get_mut::<GaugeState>(self.config_key(), node_id)
                {
                    if let Some(v) =
                        payload.get("value").and_then(|v| v.as_f64())
                    {
                        state.rust_value = v as f32;
                    }
                }
                // No event emitted -- the Ruby side updates the model
                // optimistically in the handler that sent this command.
                // Echoing an event back would create a race condition
                // with rapid button clicks.
                vec![]
            }
            _ => vec![],
        }
    }
}
