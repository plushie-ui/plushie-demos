//! Crash widget extension -- deliberately panics on command.
//!
//! Renders a status label in green when healthy. When the "panic"
//! command arrives, the handler calls panic!() which the renderer
//! catches via catch_unwind. The extension is poisoned and
//! subsequent renders show a red error placeholder.

use plushie_ext::iced;
use plushie_ext::prelude::*;

pub struct CrashExtension;

impl CrashExtension {
    pub fn new() -> Self {
        Self
    }
}

impl WidgetExtension for CrashExtension {
    fn type_names(&self) -> &[&str] {
        &["crash_widget"]
    }

    fn config_key(&self) -> &str {
        "crash"
    }

    fn new_instance(&self) -> Box<dyn WidgetExtension> {
        Box::new(CrashExtension::new())
    }

    fn render<'a>(
        &self,
        node: &'a TreeNode,
        _env: &WidgetEnv<'a>,
    ) -> Element<'a, Message> {
        let label = prop_str(node.props(), "label")
            .unwrap_or_else(|| "CrashWidget".to_string());

        container(
            text(label)
                .size(16)
                .color(Color::from_rgb(0.2, 0.7, 0.3)),
        )
        .width(iced::Length::Fill)
        .padding(16)
        .into()
    }

    fn handle_command(
        &mut self,
        _node_id: &str,
        op: &str,
        _payload: &Value,
        _caches: &mut ExtensionCaches,
    ) -> Vec<OutgoingEvent> {
        match op {
            "panic" => {
                panic!("intentional panic from crash_widget extension");
            }
            _ => vec![],
        }
    }
}
