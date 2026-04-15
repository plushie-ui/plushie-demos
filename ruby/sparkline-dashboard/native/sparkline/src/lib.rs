use plushie_widget_sdk::iced;
use plushie_widget_sdk::prelude::*;

pub struct SparklineExtension;

impl SparklineExtension {
    pub fn new() -> Self {
        Self
    }
}

impl PlushieWidget<iced::Renderer> for SparklineExtension {
    fn type_names(&self) -> &[&str] {
        &["sparkline"]
    }

    fn namespace(&self) -> &str {
        "sparkline"
    }

    fn clone_for_session(&self) -> Box<dyn PlushieWidget<iced::Renderer>> {
        Box::new(SparklineExtension::new())
    }

    fn cleanup(&mut self, _node_id: &str, _window_id: &str) {}

    fn render<'a>(
        &'a self,
        node: &'a TreeNode,
        _ctx: &RenderCtx<'a, iced::Renderer>,
    ) -> Element<'a, Message, Theme, iced::Renderer> {
        let props = &node.props;

        let data: Vec<f64> = props
            .get("data")
            .and_then(|v| v.as_array())
            .map(|arr| arr.iter().filter_map(|v| v.as_f64()).collect())
            .unwrap_or_default();

        let stroke_width = prop_f32(props, "stroke_width").unwrap_or(2.0);
        let fill = prop_bool(props, "fill").unwrap_or(false);
        let height = prop_f32(props, "height").unwrap_or(60.0);

        let color = prop_str(props, "color")
            .and_then(|s| parse_hex_color(&s))
            .unwrap_or(Color::from_rgb(0.298, 0.686, 0.314));

        canvas::Canvas::new(SparklineDraw {
            data,
            color,
            stroke_width,
            fill,
        })
        .width(Length::Fill)
        .height(Length::Fixed(height))
        .into()
    }
}

/// Canvas program that draws the sparkline chart.
struct SparklineDraw {
    data: Vec<f64>,
    color: Color,
    stroke_width: f32,
    fill: bool,
}

impl<Message> canvas::Program<Message> for SparklineDraw {
    type State = ();

    fn draw(
        &self,
        _state: &(),
        renderer: &iced::Renderer,
        _theme: &Theme,
        bounds: iced::Rectangle,
        _cursor: iced::mouse::Cursor,
    ) -> Vec<canvas::Geometry> {
        if self.data.len() < 2 {
            return vec![];
        }

        let mut frame = canvas::Frame::new(renderer, bounds.size());
        let w = bounds.width;
        let h = bounds.height;

        let min = self.data.iter().cloned().fold(f64::INFINITY, f64::min);
        let max = self.data.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        let range = (max - min).max(1.0);

        let step = w / (self.data.len() - 1) as f32;

        // Build the line path
        let mut builder = canvas::path::Builder::new();
        for (i, &val) in self.data.iter().enumerate() {
            let x = i as f32 * step;
            let y = h - ((val - min) / range) as f32 * h;
            if i == 0 {
                builder.move_to(Point::new(x, y));
            } else {
                builder.line_to(Point::new(x, y));
            }
        }
        let path = builder.build();

        // Draw the line
        frame.stroke(
            &path,
            canvas::Stroke::default()
                .with_color(self.color)
                .with_width(self.stroke_width),
        );

        // Optional: fill under the line
        if self.fill {
            let mut fill_builder = canvas::path::Builder::new();
            for (i, &val) in self.data.iter().enumerate() {
                let x = i as f32 * step;
                let y = h - ((val - min) / range) as f32 * h;
                if i == 0 {
                    fill_builder.move_to(Point::new(x, y));
                } else {
                    fill_builder.line_to(Point::new(x, y));
                }
            }
            fill_builder.line_to(Point::new(w, h));
            fill_builder.line_to(Point::new(0.0, h));
            fill_builder.close();
            let fill_path = fill_builder.build();

            let mut fill_color = self.color;
            fill_color.a = 0.15;
            frame.fill(&fill_path, fill_color);
        }

        vec![frame.into_geometry()]
    }
}

/// Parse a hex color string (#RRGGBB or #RRGGBBAA) to an iced Color.
fn parse_hex_color(hex: &str) -> Option<Color> {
    let hex = hex.strip_prefix('#')?;
    if hex.len() < 6 {
        return None;
    }
    let r = u8::from_str_radix(&hex[0..2], 16).ok()? as f32 / 255.0;
    let g = u8::from_str_radix(&hex[2..4], 16).ok()? as f32 / 255.0;
    let b = u8::from_str_radix(&hex[4..6], 16).ok()? as f32 / 255.0;
    let a = if hex.len() >= 8 {
        u8::from_str_radix(&hex[6..8], 16).ok()? as f32 / 255.0
    } else {
        1.0
    };
    Some(Color::from_rgba(r, g, b, a))
}
