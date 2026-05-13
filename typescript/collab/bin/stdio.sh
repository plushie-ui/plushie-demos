#!/bin/sh
# Mode 4: Native desktop. Renderer spawns Node.js via structured exec args.
exec plushie --listen \
  --exec-bin npx \
  --exec-arg plushie \
  --exec-arg connect \
  --exec-arg src/app.ts
