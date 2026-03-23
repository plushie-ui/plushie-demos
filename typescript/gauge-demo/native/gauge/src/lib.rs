use plushie_core::prelude::*;
use serde_json::json;

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

impl WidgetExtension for GaugeExtension {
    fn type_names(&self) -> &[&str] {
        &["gauge"]
    }

    fn config_key(&self) -> &str {
        "gauge"
    }

    fn init(&mut self, _ctx: &InitCtx<'_>) {
        // Read extension_config if needed (arcWidth, tickCount, etc.)
    }

    fn prepare(
        &mut self,
        node: &TreeNode,
        caches: &mut ExtensionCaches,
        _theme: &Theme,
    ) {
        let props = node.props();
        let value = prop_f32(props, "value").unwrap_or(0.0);
        let state = caches.get_or_insert::<GaugeState>(
            self.config_key(),
            &node.id,
            || GaugeState::new(value),
        );
        // Sync from TypeScript props
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

        // Build gauge display using iced widgets
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
            "set_value" => {
                if let Some(state) =
                    caches.get_mut::<GaugeState>(self.config_key(), node_id)
                {
                    if let Some(v) =
                        payload.get("value").and_then(|v| v.as_f64())
                    {
                        state.current_value = v as f32;
                        state.generation.bump();

                        // Notify TypeScript of the change
                        return vec![OutgoingEvent::extension_event(
                            "value_changed".to_string(),
                            node_id.to_string(),
                            Some(json!({"value": v})),
                        )];
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
                        state.generation.bump();
                    }
                }
                vec![]
            }
            _ => vec![],
        }
    }

    fn cleanup(&mut self, node_id: &str, caches: &mut ExtensionCaches) {
        caches.remove(self.config_key(), node_id);
    }
}
