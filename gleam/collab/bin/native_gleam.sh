#!/usr/bin/env bash
# Mode 3: Native desktop app started from Gleam
cd "$(dirname "$0")/.."
gleam run -m demo/native_gleam
