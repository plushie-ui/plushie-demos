#!/bin/sh
# Mode 6: Connect a native renderer to the SSH server (mode 5).
exec plushie \
  --exec-bin ssh \
  --exec-arg -T \
  --exec-arg -s \
  --exec-arg -p \
  --exec-arg 2222 \
  --exec-arg -o \
  --exec-arg StrictHostKeyChecking=no \
  --exec-arg localhost \
  --exec-arg plushie
