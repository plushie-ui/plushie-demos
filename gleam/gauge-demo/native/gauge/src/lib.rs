use plushie_widget_sdk::prelude::*;
use std::collections::HashMap;

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Per-node state
// ---------------------------------------------------------------------------

struct GaugeState {
    rust_value: f32,
}

impl GaugeState {
    fn new(value: f32) -> Self {
        Self { rust_value: value }
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Parse a "#rrggbb" or "#rrggbbaa" hex string into an iced Color.
fn hex_to_color(hex: &str) -> Option<Color> {
    let hex = hex.strip_prefix('#').unwrap_or(hex);
    if hex.len() != 6 && hex.len() != 8 {
        return None;
    }
    let r = u8::from_str_radix(&hex[0..2], 16).ok()? as f32 / 255.0;
    let g = u8::from_str_radix(&hex[2..4], 16).ok()? as f32 / 255.0;
    let b = u8::from_str_radix(&hex[4..6], 16).ok()? as f32 / 255.0;
    let a = if hex.len() == 8 {
        u8::from_str_radix(&hex[6..8], 16).ok()? as f32 / 255.0
    } else {
        1.0
    };
    Some(Color::from_rgba(r, g, b, a))
}

// ---------------------------------------------------------------------------
// PlushieWidget trait
// ---------------------------------------------------------------------------

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

    fn prepare(&mut self, node: &TreeNode, _window_id: &str, _theme: &Theme) {
        let value = prop_f32(&node.props, "value").unwrap_or(0.0);
        let state = self.states
            .entry(node.id.clone())
            .or_insert_with(|| GaugeState::new(value));
        state.rust_value = value;
    }

    fn render<'a>(&'a self, node: &'a TreeNode, _ctx: &RenderCtx<'a, R>) -> Element<'a, Message, Theme, R> {
        use plushie_widget_sdk::iced;

        let value = prop_f32(&node.props, "value").unwrap_or(0.0);
        let min = prop_f32(&node.props, "min").unwrap_or(0.0);
        let max = prop_f32(&node.props, "max").unwrap_or(100.0);
        let color = prop_str(&node.props, "color")
            .as_deref()
            .and_then(hex_to_color)
            .unwrap_or(Color::from_rgb(
                0x33 as f32 / 255.0,
                0x66 as f32 / 255.0,
                0xcc as f32 / 255.0,
            ));
        let label = prop_str(&node.props, "label").unwrap_or_default();
        let width = prop_f32(&node.props, "width").map(Length::Fixed).unwrap_or(Length::Fixed(200.0));
        let height = prop_f32(&node.props, "height").map(Length::Fixed).unwrap_or(Length::Fixed(200.0));

        let range = max - min;
        let pct = if range > 0.0 {
            ((value - min) / range).clamp(0.0, 1.0)
        } else {
            0.0
        };
        let display = format!("{:.0}%", pct * 100.0);

        container(
            iced::widget::column![text(label).size(16), text(display).size(32).color(color)]
                .align_x(alignment::Horizontal::Center),
        )
        .width(width)
        .height(height)
        .align_x(alignment::Horizontal::Center)
        .align_y(alignment::Vertical::Center)
        .into()
    }

    fn handle_widget_op(
        &mut self,
        node_id: &str,
        op: &str,
        payload: &Value,
    ) -> Option<Vec<OutgoingEvent>> {
        match op {
            "set_value" | "animate_to" => {
                if let Some(v) = payload.get("value").and_then(|v| v.as_f64()) {
                    if let Some(state) = self.states.get_mut(node_id) {
                        state.rust_value = f64_to_f32(v);
                    }
                }
                // No event emitted: the host side updates its model
                // optimistically before the command arrives. Echoing
                // an event back would race with rapid interactions.
                Some(vec![])
            }
            _ => None,
        }
    }
}
