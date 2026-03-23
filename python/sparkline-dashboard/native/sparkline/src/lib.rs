use plushie_core::iced;
use plushie_core::prelude::*;

pub struct SparklineExtension;

impl SparklineExtension {
    pub fn new() -> Self {
        Self
    }
}

impl WidgetExtension for SparklineExtension {
    fn type_names(&self) -> &[&str] {
        &["sparkline"]
    }

    fn config_key(&self) -> &str {
        "sparkline"
    }

    fn render<'a>(
        &self,
        node: &'a TreeNode,
        _env: &WidgetEnv<'a>,
    ) -> Element<'a, Message> {
        let props = node.props();

        let data: Vec<f64> = props
            .and_then(|p| p.get("data"))
            .and_then(|v| v.as_array())
            .map(|arr| arr.iter().filter_map(|v| v.as_f64()).collect())
            .unwrap_or_default();

        let stroke_width = prop_f32(props, "stroke_width").unwrap_or(2.0);
        let fill = prop_bool(props, "fill").unwrap_or(false);
        let height = prop_f32(props, "height").unwrap_or(60.0);

        let color = prop_color(props, "color").unwrap_or(Color::from_rgb(
            0.298, 0.686, 0.314,
        ));

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
