#!/usr/bin/env bash
# Mode 6: Native plushie connecting over SSH to shared state
# Requires the SSH server to be running (mode 5: ./bin/ssh_server.sh)
cd "$(dirname "$0")/.."
plushie --exec "ssh -T -s -p 2222 -o StrictHostKeyChecking=no localhost plushie"
