//! Crash native widget for plushie.
//!
//! Renders a status label in green when healthy. When the "panic"
//! command arrives, the handler calls panic!() which the renderer
//! catches via catch_unwind. The widget is poisoned and subsequent
//! renders show a red error placeholder.

use plushie_widget_sdk::iced::{Color as IcedColor, Length as IcedLength, Theme as IcedTheme};
use plushie_widget_sdk::prelude::*;

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
        let label = prop_str(&node.props, "label").unwrap_or_else(|| "CrashWidget".to_string());

        container(text(label).size(16).color(IcedColor::from_rgb(0.2, 0.7, 0.3)))
            .width(IcedLength::Fill)
            .padding(16)
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
                panic!("intentional panic from crash_widget");
            }
            _ => None,
        }
    }
}
