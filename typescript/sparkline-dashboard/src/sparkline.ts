/**
 * Sparkline native widget -- renders a line chart from sample data.
 *
 * The TypeScript side declares the widget type and props. The Rust
 * side (in native/sparkline/) handles the canvas rendering using
 * iced's canvas::Program trait.
 */

import { defineNativeWidget } from "plushie"
import type { NativeWidgetConfig } from "plushie"

export const sparklineConfig: NativeWidgetConfig = {
  type: "sparkline",
  props: {
    data: { list: "number" },
    color: "color",
    stroke_width: "number",
    fill: "boolean",
    height: "number",
  },
  rustCrate: "native/sparkline",
  rustConstructor: "sparkline::SparklineExtension::new()",
}

/** Sparkline widget builder. */
export const Sparkline = defineNativeWidget(sparklineConfig)
