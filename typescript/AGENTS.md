# AGENTS.md

## TypeScript Demos

Each child directory is an independent pnpm project. Use the local
`package.json`, lockfile, and Plushie extension config for that demo.

## Setup

Use Node.js 22 or newer with pnpm. Native widget demos also require
Rust and whatever Plushie Rust source path their extension config
expects.

## Commands

Run `just preflight` in `typescript/` to verify every TypeScript demo.

The language preflight installs with the lockfile, runs TypeScript
checking, tests, package build scripts when present, browser bundle
scripts when present, and native extension builds for demos with
`native/`.

For one demo:

```sh
pnpm install --frozen-lockfile
pnpm exec tsc --noEmit
pnpm test
pnpm run build
pnpm run build:ext
```

Only run build scripts that the demo declares.
