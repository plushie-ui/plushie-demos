//! Crash box native widget for plushie.
//!
//! A simple widget that renders a colored box with a label. When the
//! "panic" command is received, it intentionally panics. The renderer
//! catches the panic via catch_unwind, marks the widget as poisoned,
//! and shows an error placeholder for subsequent renders.
//!
//! This demonstrates that a bug in one widget cannot crash the
//! renderer or affect other widgets.

use plushie_ext::prelude::*;

/// Crash box widget -- panics on command to demonstrate isolation.
pub struct CrashBoxExtension;

impl CrashBoxExtension {
    pub fn new() -> Self {
        Self
    }
}

impl<R: PlushieRenderer> PlushieWidget<R> for CrashBoxExtension {
    fn type_names(&self) -> &[&str] {
        &["crash_box"]
    }

    fn namespace(&self) -> &str {
        "crash_box"
    }

    fn clone_for_session(&self) -> Box<dyn PlushieWidget<R>> {
        Box::new(CrashBoxExtension::new())
    }

    fn render<'a>(
        &'a self,
        node: &'a TreeNode,
        _ctx: &RenderCtx<'a, R>,
    ) -> Element<'a, Message, Theme, R> {
        let props = node.props();
        let label = prop_str(props, "label").unwrap_or_default();
        let color = prop_color(props, "color")
            .unwrap_or(Color::from_rgb(0.18, 0.80, 0.44));

        container(text(label).size(14).color(color))
            .width(Length::Fill)
            .height(Length::Fixed(60.0))
            .center(plushie_ext::iced::Length::Fill)
            .into()
    }

    fn handle_widget_op(
        &mut self,
        _node_id: &str,
        op: &str,
        _payload: &Value,
    ) -> Option<Vec<OutgoingEvent>> {
        match op {
            "panic" => {
                panic!("intentional panic from crash_box widget -- this is expected")
            }
            _ => None,
        }
    }
}
