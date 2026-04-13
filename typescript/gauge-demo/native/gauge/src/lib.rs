//! Gauge native widget for plushie.
//!
//! Renders a temperature gauge using iced container and text widgets.
//! Demonstrates the full PlushieWidget lifecycle: prepare, render,
//! handle_widget_op (with event echo), and clone_for_session.

use plushie_widget_sdk::prelude::*;
use serde_json::json;
use std::collections::HashMap;

/// Gauge widget - renders a numeric gauge with label and color.
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

/// Per-node state owned by the widget.
struct GaugeState {
    current_value: f32,
    target_value: f32,
}

impl GaugeState {
    fn new(value: f32) -> Self {
        Self {
            current_value: value,
            target_value: value,
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

    fn clone_for_session(&self) -> Box<dyn PlushieWidget<R>> {
        Box::new(GaugeExtension::new())
    }

    fn prepare(
        &mut self,
        node: &TreeNode,
        _window_id: &str,
        _theme: &Theme,
    ) {
        let value = prop_f32(node.props(), "value").unwrap_or(0.0);
        let state = self.states
            .entry(node.id.clone())
            .or_insert_with(|| GaugeState::new(value));
        state.current_value = value;
    }

    fn render<'a>(
        &'a self,
        node: &'a TreeNode,
        _ctx: &RenderCtx<'a, R>,
    ) -> Element<'a, Message, Theme, R> {
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
            plushie_widget_sdk::iced::widget::column![
                text(label).size(16),
                text(display).size(32).color(color),
            ]
            .align_x(plushie_widget_sdk::iced::alignment::Horizontal::Center),
        )
        .width(w)
        .height(h)
        .center(plushie_widget_sdk::iced::Length::Fill)
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
                    if let Some(v) =
                        payload.get("value").and_then(|v| v.as_f64())
                    {
                        state.current_value = v as f32;

                        // Echo the confirmed value back to TypeScript.
                        // The TypeScript update() handles this event and
                        // sets model.temperature - the widget is the
                        // source of truth for the actual value.
                        return Some(vec![
                            OutgoingEvent::widget_event(
                                "value_changed".to_string(),
                                node_id.to_string(),
                                Some(json!({"value": v})),
                            )
                            .with_window_id("main"),
                        ]);
                    }
                }
                Some(vec![])
            }
            "animate_to" => {
                if let Some(state) = self.states.get_mut(node_id) {
                    if let Some(v) =
                        payload.get("value").and_then(|v| v.as_f64())
                    {
                        state.target_value = v as f32;
                    }
                }
                Some(vec![])
            }
            _ => None,
        }
    }
}
