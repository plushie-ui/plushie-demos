# AGENTS.md

## Scope

This repository holds standalone Plushie demos across SDKs. Work here
should stay inside this repo unless the task explicitly asks for a
coordinated SDK change.

Do not revert edits made by other agents. If the tree is dirty, inspect
the relevant files and adjust around unrelated work.

## Repository Shape

Each language directory contains independent demo projects. Treat each
demo as a standalone application with its own dependency lock files and
local setup.

Shared infrastructure lives at the repository root:

- `justfile` runs language-level verification.
- `scripts/renderer_parent_smoke.sh` exercises renderer-parent startup.
- Language directories own their `mise.toml`, `justfile`, and local
  agent notes.

## Commands

Use `just preflight` at the repository root for the full demos sweep.
Use `just preflight` inside a language directory for only that SDK.

Use `just package-postcheck` for the source package check. It proves
manifest validity plus launcher extraction and cache behavior through
`cargo plushie package check --postcheck`; it does not prove every packaged app
starts. Use `just package-release-check` for the strict release-oriented
path that requires real generated artifact runs and Rust direct mode.

Use `just renderer-parent-smoke` at the repository root for the
cross-SDK renderer-parent startup smoke. It needs a renderer binary on
`PATH`, or `PLUSHIE_RENDERER_BINARY` or `PLUSHIE_BINARY_PATH` set.

## Native Widget Demos

Native widget demos need Rust and usually a local Plushie Rust checkout.
Set `PLUSHIE_RUST_SOURCE_PATH` when a language SDK build command needs
renderer source.

Do not replace native widget checks with pure host-language mocks.
The point of these demos is to keep the host SDK and renderer boundary
honest.

## Commit Hygiene

Keep commits self-contained and functional. Run the narrowest useful
preflight before committing, and run the root preflight when the change
touches shared infrastructure.

Commit messages should describe what changed and why. Do not include
tracking IDs or references to this file.
