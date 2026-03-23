# Crash Test

Demonstrates plushie's error resilience -- two layers of crash
protection that keep the app running when things go wrong.

Demonstrates:

- Rust extension panic isolation (`catch_unwind`, poisoned state)
- TypeScript handler error recovery (model revert, rate-limited logging)
- TypeScript view error recovery (frozen UI, handler-driven recovery)
- App stays alive after any crash (counter keeps counting)

## Setup

```sh
pnpm install
```

## Build the extension binary

```sh
export PLUSHIE_SOURCE_PATH=~/projects/plushie-renderer
npx plushie build
```

## Run

```sh
npx plushie run src/app.tsx
```

## Test

```sh
pnpm test
```

Unit tests verify handler behaviors (including that throwing handlers
actually throw) and view error/recovery sequences. Integration tests
(when the binary is built) verify the app keeps running after each
type of crash.

## How it works

### Rust extension panic

Click **Panic Widget**. The Rust extension's `handle_command` calls
`panic!()`. The renderer catches it with `catch_unwind`:

1. Panic is caught and logged
2. Extension marked "poisoned"
3. Subsequent renders show an error placeholder
4. Other widgets (the counter) keep working
5. Poisoned state clears on the next full snapshot

### TypeScript handler error

Click **Throw Handler**. The `onClick` handler throws an error.
The runtime catches it:

1. Error logged with stack trace
2. Previous model kept (the throw had no effect)
3. Render cycle skipped
4. App keeps processing events -- click the counter

### TypeScript view error

Click **Throw View**. A model flag is set that causes `view()` to
throw on the next render. The runtime catches it:

1. Error logged
2. Previous tree stays rendered (UI frozen)
3. Handlers still run -- the Reset button works
4. Click **Reset** to clear the flag and recover

The key insight: even when `view()` is broken, the app isn't dead.
Handlers process clicks on the last good tree. This is why the Reset
button works even though the current model would cause view() to
throw -- the handler clears the flag before the next view() call.

## Project structure

```
src/
  crash-box.ts          -- extension definition (panics on command)
  app.tsx               -- the crash test app
test/
  app.test.ts           -- handler, view, recovery, integration tests
native/
  crash_box/
    Cargo.toml
    src/lib.rs          -- WidgetExtension that panics
plushie.extensions.json
```
