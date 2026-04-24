#!/usr/bin/env node
// Launcher that runs the pad through tsx so the TypeScript sources
// don't need a prior build step.

import { spawn } from "node:child_process"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const here = dirname(fileURLToPath(import.meta.url))
const entry = resolve(here, "..", "src", "index.ts")

const child = spawn("npx", ["tsx", entry], { stdio: "inherit" })
child.on("exit", (code) => process.exit(code ?? 0))
