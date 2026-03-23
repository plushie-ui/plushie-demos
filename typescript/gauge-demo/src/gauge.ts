// src/gauge.ts
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
  commands: ["set_value", "animate_to"],
  rustCrate: "native/gauge",
  rustConstructor: "gauge::GaugeExtension::new()",
}

/** Gauge widget builder. */
export const Gauge = defineExtensionWidget(gaugeConfig)

/** Gauge command constructors. */
export const GaugeCmds = extensionCommands(gaugeConfig)
