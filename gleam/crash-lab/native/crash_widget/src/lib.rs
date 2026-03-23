use plushie_ext::prelude::*;

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

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
        "crash_widget"
    }

    fn new_instance(&self) -> Box<dyn WidgetExtension> {
        Box::new(CrashExtension::new())
    }

    fn render<'a>(&self, node: &'a TreeNode, _env: &WidgetEnv<'a>) -> Element<'a, Message> {
        let props = node.props.as_object();
        let label = prop_str(props, "label").unwrap_or_default();
        let color = Color::from_rgb(0.298, 0.686, 0.314); // green

        container(text(label).size(16).color(color))
            .padding(12)
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
            "panic" => panic!("intentional panic from crash_widget extension"),
            _ => vec![],
        }
    }
}
