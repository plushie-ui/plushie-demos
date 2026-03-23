use plushie_ext::prelude::*;

pub struct CrasherExtension;

impl CrasherExtension {
    pub fn new() -> Self {
        Self
    }
}

impl WidgetExtension for CrasherExtension {
    fn type_names(&self) -> &[&str] {
        &["crasher"]
    }

    fn config_key(&self) -> &str {
        "crasher"
    }

    fn render<'a>(
        &self,
        node: &'a TreeNode,
        _env: &WidgetEnv<'a>,
    ) -> Element<'a, Message> {
        let props = node.props();
        if prop_bool(props, "panic_on_render").unwrap_or(false) {
            panic!("deliberate render panic for crash testing");
        }
        let msg = prop_str(props, "message").unwrap_or("Crasher widget (alive)");
        container(text(msg).size(14))
            .padding(8)
            .style(|_theme| container::Style {
                background: Some(iced::Background::Color(Color::from_rgb(
                    0.9, 1.0, 0.9,
                ))),
                ..Default::default()
            })
            .into()
    }

    fn handle_command(
        &mut self,
        _node_id: &str,
        op: &str,
        _payload: &Value,
        _caches: &mut ExtensionCaches,
    ) -> Vec<OutgoingEvent> {
        if op == "panic" {
            panic!("deliberate command panic for crash testing");
        }
        vec![]
    }
}
