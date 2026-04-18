use plushie_widget_sdk::iced;
use plushie_widget_sdk::iced::widget::canvas as iced_canvas;
use plushie_widget_sdk::iced::{Color as IcedColor, Length as IcedLength, Theme as IcedTheme};
use plushie_widget_sdk::prelude::*;

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

pub struct SparklineExtension;

impl SparklineExtension {
    pub fn new() -> Self {
        Self
    }
}

impl<R: PlushieRenderer> PlushieWidget<R> for SparklineExtension {
    fn type_names(&self) -> &[&str] {
        &["sparkline"]
    }

    fn namespace(&self) -> &str {
        "sparkline"
    }

    fn fresh_for_session(&self) -> Box<dyn PlushieWidget<R>> {
        Box::new(SparklineExtension::new())
    }

    fn render<'a>(
        &'a self,
        node: &'a TreeNode,
        _ctx: &RenderCtx<'a, R>,
    ) -> Element<'a, Message, IcedTheme, R> {
        let data = prop_f64_array(&node.props, "data").unwrap_or_default();

        let stroke_width = prop_f32(&node.props, "stroke_width").unwrap_or(2.0);
        let fill = prop_bool_default(&node.props, "fill", false);
        let height = prop_f32(&node.props, "height").unwrap_or(60.0);
        let color = Color::extract(&node.props, "color")
            .map(|c| iced_convert::color(&c))
            .unwrap_or_else(|| IcedColor::from_rgb(0.298, 0.686, 0.314));

        canvas(SparklineDraw {
            data,
            color,
            stroke_width,
            fill,
        })
        .width(IcedLength::Fill)
        .height(IcedLength::Fixed(height))
        .into()
    }
}

// ---------------------------------------------------------------------------
// Canvas rendering
// ---------------------------------------------------------------------------

struct SparklineDraw {
    data: Vec<f64>,
    color: IcedColor,
    stroke_width: f32,
    fill: bool,
}

impl<R: PlushieRenderer> iced_canvas::Program<Message, IcedTheme, R> for SparklineDraw {
    type State = ();

    fn draw(
        &self,
        _state: &Self::State,
        renderer: &R,
        _theme: &IcedTheme,
        bounds: iced::Rectangle,
        _cursor: iced::mouse::Cursor,
    ) -> Vec<iced_canvas::Geometry<R>> {
        if self.data.len() < 2 {
            return vec![];
        }

        let mut frame = iced_canvas::Frame::new(renderer, bounds.size());
        let w = bounds.width;
        let h = bounds.height;

        let min = self.data.iter().cloned().fold(f64::INFINITY, f64::min);
        let max = self.data.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        let range = (max - min).max(1.0);
        let step = w / (self.data.len() - 1) as f32;

        // Build line path
        let line = iced_canvas::Path::new(|b| {
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
            iced_canvas::Stroke::default()
                .with_color(self.color)
                .with_width(self.stroke_width),
        );

        // Optional semi-transparent fill under the curve
        if self.fill {
            let fill_path = iced_canvas::Path::new(|b| {
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
