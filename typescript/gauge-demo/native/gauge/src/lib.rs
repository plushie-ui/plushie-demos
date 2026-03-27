//! Gauge widget extension for plushie.
//!
//! Renders a temperature gauge using iced container and text widgets.
//! Demonstrates the full WidgetExtension lifecycle: prepare, render,
//! handle_command (with event echo), and new_instance.

use plushie_ext::prelude::*;
use serde_json::json;

/// Gauge extension -- renders a numeric gauge with label and color.
pub struct GaugeExtension;

impl GaugeExtension {
    pub fn new() -> Self {
        Self
    }
}

/// Per-node state stored in ExtensionCaches.
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
        state.current_value = value;
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
            plushie_ext::iced::widget::column![
                text(label).size(16),
                text(display).size(32).color(color),
            ]
            .align_x(plushie_ext::iced::alignment::Horizontal::Center),
        )
        .width(w)
        .height(h)
        .center(plushie_ext::iced::Length::Fill)
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
            "set_value" => {
                if let Some(state) =
                    caches.get_mut::<GaugeState>(self.config_key(), node_id)
                {
                    if let Some(v) =
                        payload.get("value").and_then(|v| v.as_f64())
                    {
                        state.current_value = v as f32;

                        // Echo the confirmed value back to TypeScript.
                        // The TypeScript update() handles this event and
                        // sets model.temperature -- the extension is the
                        // source of truth for the actual value.
                        return vec![
                            OutgoingEvent::extension_event(
                                "value_changed".to_string(),
                                node_id.to_string(),
                                Some(json!({"value": v})),
                            )
                            .with_window_id("main"),
                        ];
                    }
                }
                vec![]
            }
            "animate_to" => {
                if let Some(state) =
                    caches.get_mut::<GaugeState>(self.config_key(), node_id)
                {
                    if let Some(v) =
                        payload.get("value").and_then(|v| v.as_f64())
                    {
                        state.target_value = v as f32;
                    }
                }
                vec![]
            }
            _ => vec![],
        }
    }
}
