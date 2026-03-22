#!/usr/bin/env bash
# Mode 6: Native plushie connecting over SSH to shared state
cd "$(dirname "$0")/.."
plushie --exec "ssh -p 2222 -o StrictHostKeyChecking=no localhost"
