#!/bin/sh
# Mode 6: Connect a native renderer to the SSH server (mode 5).
exec plushie --exec "ssh -T -s -p 2222 -o StrictHostKeyChecking=no localhost plushie"
