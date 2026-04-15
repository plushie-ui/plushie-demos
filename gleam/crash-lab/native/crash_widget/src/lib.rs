use plushie_widget_sdk::prelude::*;

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

pub struct CrashExtension;

impl CrashExtension {
    pub fn new() -> Self {
        Self
    }
}

impl<R: PlushieRenderer> PlushieWidget<R> for CrashExtension {
    fn type_names(&self) -> &[&str] {
        &["crash_widget"]
    }

    fn namespace(&self) -> &str {
        "crash_widget"
    }

    fn clone_for_session(&self) -> Box<dyn PlushieWidget<R>> {
        Box::new(CrashExtension::new())
    }

    fn render<'a>(&'a self, node: &'a TreeNode, _ctx: &RenderCtx<'a, R>) -> Element<'a, Message, Theme, R> {
        let label = prop_str(&node.props, "label").unwrap_or_default();
        let color = Color::from_rgb(0.298, 0.686, 0.314); // green

        container(text(label).size(16).color(color))
            .padding(12)
            .into()
    }

    fn handle_widget_op(
        &mut self,
        _node_id: &str,
        op: &str,
        _payload: &Value,
    ) -> Option<Vec<OutgoingEvent>> {
        match op {
            "panic" => panic!("intentional panic from crash_widget"),
            _ => None,
        }
    }
}
