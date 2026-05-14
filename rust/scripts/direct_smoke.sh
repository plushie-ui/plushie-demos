#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMEOUT="${RUST_DIRECT_SMOKE_TIMEOUT:-4s}"
HEADLESS_WESTON_PID=""
HEADLESS_WESTON_RUNTIME_DIR=""
HEADLESS_WESTON_LOG=""

cleanup() {
  if [ -n "$HEADLESS_WESTON_PID" ] && kill -0 "$HEADLESS_WESTON_PID" >/dev/null 2>&1; then
    kill "$HEADLESS_WESTON_PID" >/dev/null 2>&1 || true
    wait "$HEADLESS_WESTON_PID" >/dev/null 2>&1 || true
  fi

  [ -z "$HEADLESS_WESTON_RUNTIME_DIR" ] || rm -rf "$HEADLESS_WESTON_RUNTIME_DIR"
  [ -z "$HEADLESS_WESTON_LOG" ] || rm -f "$HEADLESS_WESTON_LOG"
}

trap cleanup EXIT

has_display_env() {
  local socket_path

  if [ -n "${WAYLAND_SOCKET:-}" ]; then
    case "$WAYLAND_SOCKET" in
      *[!0-9]*) ;;
      *)
        if [ -S "/proc/$$/fd/$WAYLAND_SOCKET" ]; then
          return 0
        fi
        ;;
    esac
  fi

  if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    case "$WAYLAND_DISPLAY" in
      /*) socket_path="$WAYLAND_DISPLAY" ;;
      *) socket_path="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ;;
    esac

    if [ -S "$socket_path" ]; then
      return 0
    fi
  fi

  [ -n "${DISPLAY:-}" ]
}

start_headless_weston() {
  local socket_name
  local socket_path

  if has_display_env; then
    return 0
  fi

  if ! command -v weston >/dev/null 2>&1; then
    echo "skip: rust direct smoke - no display server is available and weston is unavailable" >&2
    return 2
  fi

  HEADLESS_WESTON_RUNTIME_DIR="$(mktemp -d "${TMPDIR:-/tmp}/plushie-rust-weston.XXXXXXXXXX")"
  HEADLESS_WESTON_LOG="$(mktemp "${TMPDIR:-/tmp}/plushie-rust-weston-log.XXXXXXXXXX")"
  chmod 700 "$HEADLESS_WESTON_RUNTIME_DIR"

  socket_name="plushie-rust-smoke-$$"
  socket_path="$HEADLESS_WESTON_RUNTIME_DIR/$socket_name"

  XDG_RUNTIME_DIR="$HEADLESS_WESTON_RUNTIME_DIR" \
    weston -B headless --socket="$socket_name" >"$HEADLESS_WESTON_LOG" 2>&1 &
  HEADLESS_WESTON_PID=$!

  for _ in {1..50}; do
    if [ -S "$socket_path" ]; then
      export XDG_RUNTIME_DIR="$HEADLESS_WESTON_RUNTIME_DIR"
      export WAYLAND_DISPLAY="$socket_name"
      unset WAYLAND_SOCKET
      echo "==> started headless weston for Rust direct smoke"
      return 0
    fi

    if ! kill -0 "$HEADLESS_WESTON_PID" >/dev/null 2>&1; then
      echo "failed: rust direct smoke - headless weston exited before creating $socket_name" >&2
      sed -n '1,120p' "$HEADLESS_WESTON_LOG" >&2
      return 1
    fi

    sleep 0.1
  done

  echo "failed: rust direct smoke - timed out waiting for headless weston socket $socket_name" >&2
  sed -n '1,120p' "$HEADLESS_WESTON_LOG" >&2
  return 1
}

run_from_temp_cwd() {
  local binary="$1"
  local log
  local smoke_cwd
  local status
  local timeout_args

  if ! command -v timeout >/dev/null 2>&1; then
    echo "skip: rust direct smoke - timeout is unavailable" >&2
    return 0
  fi

  smoke_cwd="$(mktemp -d "${TMPDIR:-/tmp}/plushie-rust-direct-cwd.XXXXXXXXXX")"
  log="$(mktemp "${TMPDIR:-/tmp}/plushie-rust-direct.XXXXXXXXXX")"
  timeout_args=("$TIMEOUT" "$binary")
  if timeout --help 2>&1 | grep -q -- '--kill-after'; then
    timeout_args=(--kill-after=2s "$TIMEOUT" "$binary")
  fi

  set +e
  (cd "$smoke_cwd" && timeout "${timeout_args[@]}") >"$log" 2>&1
  status=$?
  set -e

  rm -rf "$smoke_cwd"

  case "$status" in
    0)
      echo "ok: rust direct app exited cleanly"
      ;;
    124|137)
      echo "ok: rust direct app stayed alive until timeout"
      ;;
    *)
      echo "failed: rust direct app exited with status $status" >&2
      sed -n '1,160p' "$log" >&2
      rm -f "$log"
      return "$status"
      ;;
  esac

  rm -f "$log"
}

start_headless_weston || {
  status=$?
  [ "$status" = "2" ] && exit 0
  exit "$status"
}

for manifest in "$ROOT"/*/Cargo.toml; do
  demo_dir="$(dirname "$manifest")"
  demo_name="$(basename "$demo_dir")"

  echo "==> rust/$demo_name release"
  "$ROOT/scripts/prepare_local_source.sh" "$demo_dir"
  (cd "$demo_dir" && cargo build --release)
  run_from_temp_cwd "$demo_dir/target/release/${demo_name//-/_}"
done
