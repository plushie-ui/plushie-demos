//! Gauge native widget for plushie.
//!
//! Renders a temperature gauge using iced container and text widgets.
//! Demonstrates the PlushieWidget trait with init, prepare, render,
//! handle_widget_op, cleanup_stale, and fresh_for_session.

use plushie_widget_sdk::iced::widget::column;
use plushie_widget_sdk::iced::{Color as IcedColor, Length as IcedLength, Theme as IcedTheme};
use plushie_widget_sdk::prelude::*;
use serde_json::json;
use std::collections::{HashMap, HashSet};

/// Gauge widget: renders a numeric gauge with label and color.
pub struct GaugeExtension {
    states: HashMap<String, GaugeState>,
}

impl GaugeExtension {
    pub fn new() -> Self {
        Self {
            states: HashMap::new(),
        }
    }
}

impl Default for GaugeExtension {
    fn default() -> Self {
        Self::new()
    }
}

/// Per-node state owned by the widget.
///
/// Tracks current and target values independently. The current_value
/// is synced from Elixir props each frame via prepare(). The
/// target_value is updated by animate_to commands. The generation
/// counter signals when state changes (for future canvas caching).
struct GaugeState {
    current_value: f32,
    target_value: f32,
    generation: GenerationCounter,
}

impl GaugeState {
    fn new(value: f32) -> Self {
        Self {
            current_value: value,
            target_value: value,
            generation: GenerationCounter::new(),
        }
    }
}

impl<R: PlushieRenderer> PlushieWidget<R> for GaugeExtension {
    fn type_names(&self) -> &[&str] {
        &["gauge"]
    }

    fn namespace(&self) -> &str {
        "gauge"
    }

    fn fresh_for_session(&self) -> Box<dyn PlushieWidget<R>> {
        Box::new(GaugeExtension::new())
    }

    fn init(&mut self, _ctx: &InitCtx<'_>) {
        // Read extension_config if needed (arcWidth, tickCount, etc.)
    }

    fn prepare(&mut self, node: &TreeNode, _window_id: &str, _theme: &IcedTheme) {
        let props = &node.props;
        let value = prop_f32(props, "value").unwrap_or(0.0);
        let state = self
            .states
            .entry(node.id.clone())
            .or_insert_with(|| GaugeState::new(value));
        // Sync from Elixir props each frame
        state.current_value = value;
    }

    fn render<'a>(
        &'a self,
        node: &'a TreeNode,
        _ctx: &RenderCtx<'a, R>,
    ) -> Element<'a, Message, IcedTheme, R> {
        let props = &node.props;
        let value = prop_f32(props, "value").unwrap_or(0.0);
        let min = prop_f32(props, "min").unwrap_or(0.0);
        let max = prop_f32(props, "max").unwrap_or(100.0);
        let color = Color::extract(props, "color")
            .map(|c| iced_convert::color(&c))
            .unwrap_or_else(|| IcedColor::from_rgb(0.2, 0.5, 0.8));
        let label = prop_str(props, "label").unwrap_or_default();
        let width = Length::extract(props, "width")
            .map(|l| iced_convert::length(&l))
            .unwrap_or(IcedLength::Fixed(200.0));
        let height = Length::extract(props, "height")
            .map(|l| iced_convert::length(&l))
            .unwrap_or(IcedLength::Fixed(200.0));

        let pct = ((value - min) / (max - min)).clamp(0.0, 1.0);
        let display = format!("{:.0}%", pct * 100.0);

        container(
            column![text(label).size(16), text(display).size(32).color(color)]
                .align_x(alignment::Horizontal::Center),
        )
        .width(width)
        .height(height)
        .center(IcedLength::Fill)
        .into()
    }

    fn handle_widget_op(
        &mut self,
        node_id: &str,
        op: &str,
        payload: &Value,
    ) -> Option<Vec<OutgoingEvent>> {
        match op {
            "set_value" => {
                if let Some(state) = self.states.get_mut(node_id) {
                    if let Some(v) = payload.get("value").and_then(|v| v.as_f64()) {
                        state.current_value = v as f32;
                        state.generation.bump();

                        // Notify Elixir of the confirmed value change
                        return Some(vec![OutgoingEvent::widget_event(
                            "gauge:value_changed".to_string(),
                            node_id.to_string(),
                            Some(json!({"value": v})),
                        )]);
                    }
                }
                Some(vec![])
            }
            "animate_to" => {
                if let Some(state) = self.states.get_mut(node_id) {
                    if let Some(v) = payload.get("value").and_then(|v| v.as_f64()) {
                        state.target_value = v as f32;
                        state.generation.bump();
                    }
                }
                // No event emitted: animate_to only updates the target
                Some(vec![])
            }
            _ => None,
        }
    }

    fn cleanup_stale(&mut self, live_ids: &HashSet<(String, String)>) {
        let live: HashSet<&str> = live_ids.iter().map(|(_, id)| id.as_str()).collect();
        self.states.retain(|id, _| live.contains(id.as_str()));
    }
}
