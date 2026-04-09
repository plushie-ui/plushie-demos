//! Crash native widget for plushie.
//!
//! Minimal widget that renders a green box and can be deliberately
//! panicked via the `panic` command. Demonstrates the renderer's
//! `catch_unwind` panic isolation -- after the panic, this widget is
//! replaced with a red placeholder while the rest of the app continues.

use plushie_ext::iced;
use plushie_ext::prelude::*;

/// Crash widget -- renders a green status box.
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

    fn render<'a>(
        &'a self,
        node: &'a TreeNode,
        _ctx: &RenderCtx<'a, R>,
    ) -> Element<'a, Message, Theme, R> {
        let props = node.props();
        let label = prop_str(props, "label").unwrap_or_else(|| "Widget OK".to_string());

        container(
            text(label)
                .size(14)
                .color(Color::WHITE),
        )
        .width(Length::Fill)
        .height(Length::Fixed(50.0))
        .center(iced::Length::Fill)
        .style(|_theme| iced::widget::container::Style {
            background: Some(
                Color::from_rgb(0.2, 0.7, 0.3).into(),
            ),
            border: iced::Border {
                radius: 6.0.into(),
                ..Default::default()
            },
            ..Default::default()
        })
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
                panic!("Deliberate panic in handle_widget_op -- catch_unwind isolates this")
            }
            _ => None,
        }
    }
}
