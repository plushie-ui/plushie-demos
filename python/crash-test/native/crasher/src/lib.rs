use plushie_widget_sdk::prelude::*;

pub struct CrasherExtension;

impl CrasherExtension {
    pub fn new() -> Self {
        Self
    }
}

impl<R: PlushieRenderer> PlushieWidget<R> for CrasherExtension {
    fn type_names(&self) -> &[&str] {
        &["crasher"]
    }

    fn namespace(&self) -> &str {
        "crasher"
    }

    fn clone_for_session(&self) -> Box<dyn PlushieWidget<R>> {
        Box::new(CrasherExtension::new())
    }

    fn render<'a>(
        &'a self,
        node: &'a TreeNode,
        _ctx: &RenderCtx<'a, R>,
    ) -> Element<'a, Message, Theme, R> {
        let props = node.props();
        if prop_bool(props, "panic_on_render").unwrap_or(false) {
            panic!("deliberate render panic for crash testing");
        }
        let msg = prop_str(props, "message")
            .unwrap_or_else(|| "Crasher widget (alive)".to_string());
        container(text(msg).size(14))
            .padding(8)
            .into()
    }

    fn handle_widget_op(
        &mut self,
        _node_id: &str,
        op: &str,
        _payload: &Value,
    ) -> Option<Vec<OutgoingEvent>> {
        if op == "panic" {
            panic!("deliberate command panic for crash testing");
        }
        None
    }
}
