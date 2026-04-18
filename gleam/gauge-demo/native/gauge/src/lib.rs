use plushie_widget_sdk::iced::widget::column;
use plushie_widget_sdk::iced::{Color as IcedColor, Length as IcedLength, Theme as IcedTheme};
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
// PlushieWidget trait
// ---------------------------------------------------------------------------

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

    fn prepare(&mut self, node: &TreeNode, _window_id: &str, _theme: &IcedTheme) {
        let value = prop_f32(&node.props, "value").unwrap_or(0.0);
        let state = self
            .states
            .entry(node.id.clone())
            .or_insert_with(|| GaugeState::new(value));
        state.rust_value = value;
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
            .unwrap_or_else(|| {
                IcedColor::from_rgb(
                    0x33 as f32 / 255.0,
                    0x66 as f32 / 255.0,
                    0xcc as f32 / 255.0,
                )
            });
        let label = prop_str(props, "label").unwrap_or_default();
        let width = Length::extract(props, "width")
            .map(|l| iced_convert::length(&l))
            .unwrap_or(IcedLength::Fixed(200.0));
        let height = Length::extract(props, "height")
            .map(|l| iced_convert::length(&l))
            .unwrap_or(IcedLength::Fixed(200.0));

        let range = max - min;
        let pct = if range > 0.0 {
            ((value - min) / range).clamp(0.0, 1.0)
        } else {
            0.0
        };
        let display = format!("{:.0}%", pct * 100.0);

        container(
            column![text(label).size(16), text(display).size(32).color(color)]
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
