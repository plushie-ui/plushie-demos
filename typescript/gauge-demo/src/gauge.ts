/**
 * Gauge extension definition and builder functions.
 *
 * Defines the native gauge widget: a circular gauge rendered by
 * Rust/iced. The TypeScript side declares the props, events, and
 * commands; the Rust side handles rendering and animation.
 */

import { defineExtensionWidget, extensionCommands } from "plushie"
import type { ExtensionWidgetConfig } from "plushie"

export const gaugeConfig: ExtensionWidgetConfig = {
  type: "gauge",
  props: {
    value: "number",
    min: "number",
    max: "number",
    color: "color",
    label: "string",
    width: "length",
    height: "length",
  },
  events: ["value_changed"],
  commands: ["set_value", "animate_to"],
  rustCrate: "native/gauge",
  rustConstructor: "gauge::GaugeExtension::new()",
}

/** Gauge widget builder. */
export const Gauge = defineExtensionWidget(gaugeConfig)

/** Gauge command constructors. */
export const GaugeCmds = extensionCommands(gaugeConfig)
