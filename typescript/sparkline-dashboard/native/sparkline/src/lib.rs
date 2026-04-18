//! Sparkline native widget for plushie.
//!
//! Renders a line chart from an array of numeric data points using
//! iced's canvas::Program trait. Supports stroke color, fill, and
//! configurable height.

use plushie_widget_sdk::iced;
use plushie_widget_sdk::iced::widget::canvas as iced_canvas;
use plushie_widget_sdk::iced::{Color as IcedColor, Length as IcedLength, Theme as IcedTheme};
use plushie_widget_sdk::prelude::*;

/// Sparkline widget - renders a canvas-based line chart.
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
        let props = &node.props;

        let data: Vec<f64> = prop_f32_array(props, "data")
            .map(|arr| arr.into_iter().map(|v| v as f64).collect())
            .unwrap_or_default();

        let stroke_width = prop_f32(props, "stroke_width").unwrap_or(2.0);
        let fill = prop_bool(props, "fill").unwrap_or(false);
        let height = prop_f32(props, "height").unwrap_or(60.0);

        let color = Color::extract(props, "color")
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

/// Canvas program that draws the sparkline chart.
struct SparklineDraw {
    data: Vec<f64>,
    color: IcedColor,
    stroke_width: f32,
    fill: bool,
}

impl<M, R> iced_canvas::Program<M, IcedTheme, R> for SparklineDraw
where
    R: iced::advanced::graphics::geometry::Renderer,
{
    type State = ();

    fn draw(
        &self,
        _state: &(),
        renderer: &R,
        _theme: &IcedTheme,
        bounds: iced::Rectangle,
        _cursor: iced::mouse::Cursor,
    ) -> Vec<iced_canvas::Geometry<R>> {
        if self.data.len() < 2 {
            return vec![];
        }

        let mut frame = iced_canvas::Frame::<R>::new(renderer, bounds.size());
        let w = bounds.width;
        let h = bounds.height;

        let min = self.data.iter().cloned().fold(f64::INFINITY, f64::min);
        let max = self.data.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        let range = (max - min).max(1.0);

        let step = w / (self.data.len() - 1) as f32;

        // Build the line path
        let mut builder = iced_canvas::path::Builder::new();
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
            iced_canvas::Stroke::default()
                .with_color(self.color)
                .with_width(self.stroke_width),
        );

        // Optional: fill under the line
        if self.fill {
            let mut fill_builder = iced_canvas::path::Builder::new();
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
