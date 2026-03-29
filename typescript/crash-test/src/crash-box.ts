/**
 * Crash box native widget -- a simple widget that panics on command.
 *
 * Normally renders a colored container with a label. When the
 * "panic" command is sent, the Rust side calls panic!(), which
 * the renderer catches via catch_unwind. The widget is marked
 * poisoned and subsequent renders show an error placeholder.
 *
 * The rest of the app keeps working -- panic isolation means one
 * broken widget can't take down the process.
 */

import { defineNativeWidget, nativeWidgetCommands } from "plushie"
import type { NativeWidgetConfig } from "plushie"

export const crashBoxConfig: NativeWidgetConfig = {
  type: "crash_box",
  props: {
    label: "string",
    color: "color",
  },
  commands: ["panic"],
  rustCrate: "native/crash_box",
  rustConstructor: "crash_box::CrashBoxExtension::new()",
}

/** Crash box widget builder. */
export const CrashBox = defineNativeWidget(crashBoxConfig)

/** Crash box command constructors. */
export const CrashBoxCmds = nativeWidgetCommands(crashBoxConfig)
