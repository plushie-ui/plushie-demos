#!/bin/sh
# Mode 4: Native desktop. Renderer spawns Node.js via --exec.
exec plushie --listen --exec "npx plushie connect src/collab.tsx"
