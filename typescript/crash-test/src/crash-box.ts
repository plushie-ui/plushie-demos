/**
 * Crash box extension -- a simple widget that panics on command.
 *
 * Normally renders a colored container with a label. When the
 * "panic" command is sent, the Rust side calls panic!(), which
 * the renderer catches via catch_unwind. The extension is marked
 * poisoned and subsequent renders show an error placeholder.
 *
 * The rest of the app keeps working -- panic isolation means one
 * broken extension can't take down the process.
 */

import { defineExtensionWidget, extensionCommands } from "plushie"
import type { ExtensionWidgetConfig } from "plushie"

export const crashBoxConfig: ExtensionWidgetConfig = {
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
export const CrashBox = defineExtensionWidget(crashBoxConfig)

/** Crash box command constructors. */
export const CrashBoxCmds = extensionCommands(crashBoxConfig)
