#!/usr/bin/env bash
# Mode 6: Native plushie connecting over SSH to shared state
# Requires the SSH server to be running (mode 5: ./bin/ssh_server.sh)
cd "$(dirname "$0")/.."
plushie \
  --exec-bin ssh \
  --exec-arg -T \
  --exec-arg -s \
  --exec-arg -p \
  --exec-arg 2222 \
  --exec-arg -o \
  --exec-arg StrictHostKeyChecking=no \
  --exec-arg localhost \
  --exec-arg plushie
