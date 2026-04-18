//! Crash native widget for plushie.
//!
//! Minimal widget that renders a green box and can be deliberately
//! panicked via the `panic` command. Demonstrates the renderer's
//! `catch_unwind` panic isolation: after the panic, this widget is
//! replaced with a red placeholder while the rest of the app continues.

use plushie_widget_sdk::iced::widget::container as iced_container;
use plushie_widget_sdk::iced::{Border, Color as IcedColor, Length as IcedLength, Theme as IcedTheme};
use plushie_widget_sdk::prelude::*;

/// Crash widget: renders a green status box.
pub struct CrashExtension;

impl CrashExtension {
    pub fn new() -> Self {
        Self
    }
}

impl Default for CrashExtension {
    fn default() -> Self {
        Self::new()
    }
}

impl<R: PlushieRenderer> PlushieWidget<R> for CrashExtension {
    fn type_names(&self) -> &[&str] {
        &["crash_widget"]
    }

    fn namespace(&self) -> &str {
        "crash_widget"
    }

    fn fresh_for_session(&self) -> Box<dyn PlushieWidget<R>> {
        Box::new(CrashExtension::new())
    }

    fn render<'a>(
        &'a self,
        node: &'a TreeNode,
        _ctx: &RenderCtx<'a, R>,
    ) -> Element<'a, Message, IcedTheme, R> {
        let label = prop_str(&node.props, "label").unwrap_or_else(|| "Widget OK".to_string());

        container(text(label).size(14).color(IcedColor::WHITE))
            .width(IcedLength::Fill)
            .height(IcedLength::Fixed(50.0))
            .center(IcedLength::Fill)
            .style(|_theme| iced_container::Style {
                background: Some(IcedColor::from_rgb(0.2, 0.7, 0.3).into()),
                border: Border {
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
                panic!("Deliberate panic in handle_widget_op (catch_unwind isolates this)")
            }
            _ => None,
        }
    }
}
