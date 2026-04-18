use plushie_widget_sdk::iced::{self, Element, Theme};
use plushie_widget_sdk::prelude::*;
use serde_json::json;
use std::collections::HashMap;

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

    fn prepare(
        &mut self,
        node: &TreeNode,
        _window_id: &str,
        _theme: &Theme,
    ) {
        let props = &node.props;
        let value = prop_f32(props, "value").unwrap_or(0.0);
        let state = self
            .states
            .entry(node.id.clone())
            .or_insert_with(|| GaugeState::new(value));
        state.current_value = value;
    }

    fn render<'a>(
        &'a self,
        node: &'a TreeNode,
        _ctx: &RenderCtx<'a, R>,
    ) -> Element<'a, Message, Theme, R> {
        let props = &node.props;
        let value = prop_f32(props, "value").unwrap_or(0.0);
        let min = prop_f32(props, "min").unwrap_or(0.0);
        let max = prop_f32(props, "max").unwrap_or(100.0);
        let label = prop_str(props, "label").unwrap_or_default();

        let color = prop_str(props, "color")
            .and_then(|s| parse_hex_color(&s))
            .unwrap_or(iced::Color::from_rgb(0.2, 0.5, 0.8));

        let w = prop_f32(props, "width")
            .map(iced::Length::Fixed)
            .unwrap_or(iced::Length::Fixed(200.0));
        let h = prop_f32(props, "height")
            .map(iced::Length::Fixed)
            .unwrap_or(iced::Length::Fixed(200.0));

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

                        return Some(vec![OutgoingEvent::widget_event(
                            "value_changed",
                            node_id,
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
                Some(vec![])
            }
            _ => None,
        }
    }
}

/// Parse a hex color string (#RRGGBB or #RRGGBBAA) to an iced Color.
fn parse_hex_color(hex: &str) -> Option<iced::Color> {
    let hex = hex.strip_prefix('#')?;
    if hex.len() < 6 {
        return None;
    }
    let r = u8::from_str_radix(&hex[0..2], 16).ok()? as f32 / 255.0;
    let g = u8::from_str_radix(&hex[2..4], 16).ok()? as f32 / 255.0;
    let b = u8::from_str_radix(&hex[4..6], 16).ok()? as f32 / 255.0;
    let a = if hex.len() >= 8 {
        u8::from_str_radix(&hex[6..8], 16).ok()? as f32 / 255.0
    } else {
        1.0
    };
    Some(iced::Color::from_rgba(r, g, b, a))
}
