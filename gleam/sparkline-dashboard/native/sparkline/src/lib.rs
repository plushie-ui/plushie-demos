use plushie_ext::iced;
use plushie_ext::prelude::*;

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

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

    fn new_instance(&self) -> Box<dyn WidgetExtension> {
        Box::new(SparklineExtension::new())
    }

    fn render<'a>(&self, node: &'a TreeNode, _env: &WidgetEnv<'a>) -> Element<'a, Message> {
        let props = node.props.as_object();

        let data: Vec<f64> = props
            .and_then(|p| p.get("data"))
            .and_then(|v| v.as_array())
            .map(|arr| arr.iter().filter_map(|v| v.as_f64()).collect())
            .unwrap_or_default();

        let stroke_width = prop_f32(props, "stroke_width").unwrap_or(2.0);
        let fill = prop_bool_default(props, "fill", false);
        let height = prop_f32(props, "height").unwrap_or(60.0);
        let color =
            prop_color(props, "color").unwrap_or(Color::from_rgb(0.298, 0.686, 0.314));

        canvas(SparklineDraw { data, color, stroke_width, fill })
            .width(Length::Fill)
            .height(Length::Fixed(height))
            .into()
    }
}

// ---------------------------------------------------------------------------
// Canvas rendering
// ---------------------------------------------------------------------------

struct SparklineDraw {
    data: Vec<f64>,
    color: Color,
    stroke_width: f32,
    fill: bool,
}

impl<Message> iced::widget::canvas::Program<Message> for SparklineDraw {
    type State = ();

    fn draw(
        &self,
        _state: &Self::State,
        renderer: &iced::Renderer,
        _theme: &Theme,
        bounds: iced::Rectangle,
        _cursor: iced::mouse::Cursor,
    ) -> Vec<iced::widget::canvas::Geometry> {
        if self.data.len() < 2 {
            return vec![];
        }

        let mut frame = iced::widget::canvas::Frame::new(renderer, bounds.size());
        let w = bounds.width;
        let h = bounds.height;

        let min = self.data.iter().cloned().fold(f64::INFINITY, f64::min);
        let max = self.data.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        let range = (max - min).max(1.0);
        let step = w / (self.data.len() - 1) as f32;

        // Build line path
        let line = iced::widget::canvas::Path::new(|b| {
            for (i, &val) in self.data.iter().enumerate() {
                let x = i as f32 * step;
                let y = h - ((val - min) / range) as f32 * h;
                if i == 0 {
                    b.move_to(Point::new(x, y));
                } else {
                    b.line_to(Point::new(x, y));
                }
            }
        });

        frame.stroke(
            &line,
            iced::widget::canvas::Stroke::default()
                .with_color(self.color)
                .with_width(self.stroke_width),
        );

        // Optional semi-transparent fill under the curve
        if self.fill {
            let fill_path = iced::widget::canvas::Path::new(|b| {
                for (i, &val) in self.data.iter().enumerate() {
                    let x = i as f32 * step;
                    let y = h - ((val - min) / range) as f32 * h;
                    if i == 0 {
                        b.move_to(Point::new(x, y));
                    } else {
                        b.line_to(Point::new(x, y));
                    }
                }
                b.line_to(Point::new((self.data.len() - 1) as f32 * step, h));
                b.line_to(Point::new(0.0, h));
                b.close();
            });

            let mut fill_color = self.color;
            fill_color.a = 0.15;
            frame.fill(&fill_path, fill_color);
        }

        vec![frame.into_geometry()]
    }
}
