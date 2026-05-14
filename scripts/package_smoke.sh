#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LANGUAGE="${1:-all}"
SMOKE_TIMEOUT="${PACKAGE_SMOKE_TIMEOUT:-10}"
BUILD_PAYLOADS="${PACKAGE_SMOKE_BUILD:-0}"
RUN_ARTIFACTS="${PACKAGE_SMOKE_RUN_ARTIFACTS:-0}"
ARTIFACT_TIMEOUT="${PACKAGE_ARTIFACT_TIMEOUT:-10s}"
ARTIFACT_READY_MARKER="${PACKAGE_ARTIFACT_READY_MARKER:-plushie renderer-parent: ready}"
ARTIFACT_RUNTIME_PATH="${PACKAGE_ARTIFACT_RUNTIME_PATH:-}"
PACKAGE_COMMAND_BUILT=0
HEADLESS_WESTON_STARTED=0
HEADLESS_WESTON_PID=""
HEADLESS_WESTON_RUNTIME_DIR=""
HEADLESS_WESTON_LOG=""
HEADLESS_WESTON_SOCKET_PATH=""

cleanup_headless_weston() {
  if [ -n "$HEADLESS_WESTON_PID" ] && kill -0 "$HEADLESS_WESTON_PID" >/dev/null 2>&1; then
    kill "$HEADLESS_WESTON_PID" >/dev/null 2>&1 || true
    wait "$HEADLESS_WESTON_PID" >/dev/null 2>&1 || true
  fi

  if [ "$HEADLESS_WESTON_STARTED" = "1" ]; then
    echo "==> stopped headless weston"
    echo "    XDG_RUNTIME_DIR=$HEADLESS_WESTON_RUNTIME_DIR"
    echo "    WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-}"
  fi

  [ -z "$HEADLESS_WESTON_RUNTIME_DIR" ] || rm -rf "$HEADLESS_WESTON_RUNTIME_DIR"
  [ -z "$HEADLESS_WESTON_LOG" ] || rm -f "$HEADLESS_WESTON_LOG"
}

trap cleanup_headless_weston EXIT

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

headless_weston_alive() {
  [ "$HEADLESS_WESTON_STARTED" = "1" ] &&
    [ -n "$HEADLESS_WESTON_PID" ] &&
    kill -0 "$HEADLESS_WESTON_PID" >/dev/null 2>&1 &&
    [ -n "$HEADLESS_WESTON_SOCKET_PATH" ] &&
    [ -S "$HEADLESS_WESTON_SOCKET_PATH" ]
}

print_artifact_log() {
  local log="$1"

  echo "artifact log excerpt:" >&2
  sed -n '1,120p' "$log" >&2
}

ensure_display_env() {
  local display_status

  if [ "$HEADLESS_WESTON_STARTED" = "1" ]; then
    if headless_weston_alive; then
      return 0
    fi

    echo "failed: package artifact smoke - headless weston stopped before artifact run" >&2
    [ -z "$HEADLESS_WESTON_LOG" ] || sed -n '1,120p' "$HEADLESS_WESTON_LOG" >&2
    return 1
  fi

  if has_display_env; then
    return 0
  fi

  if start_headless_weston; then
    display_status=0
  else
    display_status=$?
  fi

  case "$display_status" in
    0) return 0 ;;
    2) return 2 ;;
    *) return "$display_status" ;;
  esac
}

start_headless_weston() {
  local socket_name
  local socket_path
  local attempt

  if has_display_env; then
    return 0
  fi

  if [ "$HEADLESS_WESTON_STARTED" = "1" ]; then
    return 0
  fi

  if ! command -v weston >/dev/null 2>&1; then
    echo "skip: package artifact smoke - no display server is available and weston is unavailable" >&2
    return 2
  fi

  HEADLESS_WESTON_RUNTIME_DIR="$(mktemp -d "${TMPDIR:-/tmp}/plushie-package-weston.XXXXXXXXXX")"
  HEADLESS_WESTON_LOG="$(mktemp "${TMPDIR:-/tmp}/plushie-package-weston-log.XXXXXXXXXX")"
  chmod 700 "$HEADLESS_WESTON_RUNTIME_DIR"

  socket_name="plushie-package-smoke-$$"
  socket_path="$HEADLESS_WESTON_RUNTIME_DIR/$socket_name"
  HEADLESS_WESTON_SOCKET_PATH="$socket_path"

  XDG_RUNTIME_DIR="$HEADLESS_WESTON_RUNTIME_DIR" \
    weston -B headless --socket="$socket_name" >"$HEADLESS_WESTON_LOG" 2>&1 &
  HEADLESS_WESTON_PID=$!

  for attempt in {1..50}; do
    if [ -S "$socket_path" ]; then
      export XDG_RUNTIME_DIR="$HEADLESS_WESTON_RUNTIME_DIR"
      export WAYLAND_DISPLAY="$socket_name"
      unset WAYLAND_SOCKET
      HEADLESS_WESTON_STARTED=1
      echo "==> started headless weston for artifact smoke"
      echo "    XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
      echo "    WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
      return 0
    fi

    if ! kill -0 "$HEADLESS_WESTON_PID" >/dev/null 2>&1; then
      echo "failed: package artifact smoke - headless weston exited before creating $socket_name" >&2
      sed -n '1,120p' "$HEADLESS_WESTON_LOG" >&2
      return 1
    fi

    sleep 0.1
  done

  echo "failed: package artifact smoke - timed out waiting for headless weston socket $socket_name" >&2
  sed -n '1,120p' "$HEADLESS_WESTON_LOG" >&2
  return 1
}

run_clean_from_temp_cwd() {
  local scrubbed_env_args=()
  local smoke_cwd
  local status

  while IFS='=' read -r name _; do
    case "$name" in
      PLUSHIE_CACHE_DIR) ;;
      PLUSHIE_*) scrubbed_env_args+=("-u" "$name") ;;
    esac
  done < <(env)

  smoke_cwd="$(mktemp -d "${TMPDIR:-/tmp}/plushie-package-smoke-cwd.XXXXXXXXXX")"

  if (
    set -e
    cd "$smoke_cwd"

    env "${scrubbed_env_args[@]}" "$@"
  ); then
    status=0
  else
    status=$?
  fi

  rm -rf "$smoke_cwd"
  return "$status"
}

default_artifact_runtime_path() {
  local path=""
  local dir

  for dir in /usr/bin /bin /usr/sbin /sbin; do
    if [ -d "$dir" ]; then
      if [ -z "$path" ]; then
        path="$dir"
      else
        path="$path:$dir"
      fi
    fi
  done

  printf '%s\n' "$path"
}

artifact_runtime_path() {
  if [ -n "$ARTIFACT_RUNTIME_PATH" ]; then
    printf '%s\n' "$ARTIFACT_RUNTIME_PATH"
  else
    default_artifact_runtime_path
  fi
}

run_artifact_from_temp_cwd() {
  local scrubbed_env_args=()
  local smoke_cwd
  local status

  while IFS='=' read -r name _; do
    case "$name" in
      PLUSHIE_CACHE_DIR) ;;
      PLUSHIE_* | \
        MISE* | \
        ASDF* | \
        RBENV* | \
        RVM* | \
        PYENV* | \
        NVM* | \
        BUNDLE_* | \
        GEM_HOME | \
        GEM_PATH | \
        RUBYLIB | \
        RUBYOPT | \
        NODE_OPTIONS | \
        NODE_PATH | \
        PYTHONHOME | \
        PYTHONPATH | \
        MIX_ENV | \
        ERL_* | \
        ERLROOTDIR | \
        ERL_ROOTDIR)
        scrubbed_env_args+=("-u" "$name")
        ;;
    esac
  done < <(env)

  smoke_cwd="$(mktemp -d "${TMPDIR:-/tmp}/plushie-package-artifact-cwd.XXXXXXXXXX")"

  if (
    set -e
    cd "$smoke_cwd"

    env "${scrubbed_env_args[@]}" PATH="$ARTIFACT_LAUNCH_PATH" "$@"
  ); then
    status=0
  else
    status=$?
  fi

  rm -rf "$smoke_cwd"
  return "$status"
}

run_with_language_mise_config() {
  local language="$1"
  local config="$ROOT/$language/mise.toml"
  local trusted_paths

  shift

  if [ ! -f "$config" ]; then
    "$@"
    return
  fi

  if [ -n "${MISE_TRUSTED_CONFIG_PATHS:-}" ]; then
    trusted_paths="$MISE_TRUSTED_CONFIG_PATHS:$config"
  else
    trusted_paths="$config"
  fi

  if command -v mise >/dev/null 2>&1; then
    MISE_TRUSTED_CONFIG_PATHS="$trusted_paths" mise exec -- "$@"
  else
    MISE_TRUSTED_CONFIG_PATHS="$trusted_paths" "$@"
  fi
}

run_package_command() {
  local manifest="$1"
  local out="$2"
  local cargo_plushie_dir=""

  PACKAGE_COMMAND_BUILT=0

  if ! command -v cargo >/dev/null 2>&1; then
    echo "skip: package smoke - cargo is unavailable; install Rust or set up cargo-plushie" >&2
    return 0
  fi

  if [ -n "${PLUSHIE_RUST_SOURCE_PATH:-}" ] && [ -f "$PLUSHIE_RUST_SOURCE_PATH/Cargo.toml" ]; then
    cargo_plushie_dir="$(cd "$PLUSHIE_RUST_SOURCE_PATH" && pwd)"
  elif ! command -v cargo-plushie >/dev/null 2>&1; then
    echo "skip: package smoke - cargo-plushie is unavailable; install cargo-plushie or set PLUSHIE_RUST_SOURCE_PATH" >&2
    return 0
  fi

  if [ -n "$cargo_plushie_dir" ]; then
    run_clean_from_temp_cwd \
      cargo run -q -p cargo-plushie \
      --manifest-path "$cargo_plushie_dir/Cargo.toml" \
      -- package \
      --manifest "$manifest" \
      --smoke \
      --smoke-timeout "$SMOKE_TIMEOUT" \
      --out "$out"
  else
    run_clean_from_temp_cwd \
      cargo plushie package \
      --manifest "$manifest" \
      --smoke \
      --smoke-timeout "$SMOKE_TIMEOUT" \
      --out "$out"
  fi
  PACKAGE_COMMAND_BUILT=1
}

run_artifact_command() {
  local artifact="$1"
  local artifact_path
  local cache_dir
  local display_status
  local log
  local status
  local timeout_bin
  local timeout_args

  if [ "$RUN_ARTIFACTS" != "1" ]; then
    return 0
  fi

  if [ "$PACKAGE_COMMAND_BUILT" != "1" ]; then
    echo "skip: package artifact smoke - launcher was not built in this run" >&2
    return 0
  fi

  if [ -z "$ARTIFACT_READY_MARKER" ]; then
    echo "failed: package artifact smoke - PACKAGE_ARTIFACT_READY_MARKER must not be empty" >&2
    return 1
  fi

  if ensure_display_env; then
    display_status=0
  else
    display_status=$?
  fi

  case "$display_status" in
    0) ;;
    2) return 0 ;;
    *) return "$display_status" ;;
  esac

  if ! command -v timeout >/dev/null 2>&1; then
    echo "skip: package artifact smoke - timeout is unavailable" >&2
    return 0
  fi
  timeout_bin="$(command -v timeout)"

  if [ ! -x "$artifact" ]; then
    echo "failed: package artifact smoke - launcher is not executable: $artifact" >&2
    return 1
  fi

  log="$(mktemp "${TMPDIR:-/tmp}/plushie-package-artifact.XXXXXXXXXX")"
  cache_dir="$(mktemp -d "${TMPDIR:-/tmp}/plushie-package-artifact-cache.XXXXXXXXXX")"
  artifact_path="$(artifact_runtime_path)"

  echo "==> artifact ${artifact#$ROOT/}"
  echo "    PATH=$artifact_path"

  timeout_args=("$ARTIFACT_TIMEOUT" "$artifact")
  if "$timeout_bin" --help 2>&1 | grep -q -- '--kill-after'; then
    timeout_args=(--kill-after=2s "$ARTIFACT_TIMEOUT" "$artifact")
  fi

  set +e
  (
    export PLUSHIE_CACHE_DIR="$cache_dir"
    export ARTIFACT_LAUNCH_PATH="$artifact_path"
    run_artifact_from_temp_cwd \
      "$timeout_bin" "${timeout_args[@]}"
  ) >"$log" 2>&1
  status=$?
  set -e

  if grep -q "plushie launcher: smoke ok" "$log"; then
    echo "failed: artifact used launcher smoke mode" >&2
    print_artifact_log "$log"
    rm -f "$log"
    rm -rf "$cache_dir"
    return 1
  fi

  if ! grep -q "plushie launcher: app=" "$log"; then
    echo "failed: artifact did not emit launcher diagnostics" >&2
    print_artifact_log "$log"
    rm -f "$log"
    rm -rf "$cache_dir"
    return 1
  fi

  if ! grep -Fq "$ARTIFACT_READY_MARKER" "$log"; then
    case "$status" in
      124|137)
        echo "failed: artifact timed out before renderer-parent was ready" >&2
        ;;
      *)
        echo "failed: artifact exited before renderer-parent was ready" >&2
        ;;
    esac
    print_artifact_log "$log"
    rm -f "$log"
    rm -rf "$cache_dir"
    return 1
  fi

  case "$status" in
    0)
      if ! grep -q "plushie launcher: renderer exited" "$log"; then
        echo "failed: artifact exited before renderer shutdown" >&2
        print_artifact_log "$log"
        rm -f "$log"
        rm -rf "$cache_dir"
        return 1
      fi
      echo "ok: artifact exited cleanly"
      ;;
    124|137)
      echo "ok: artifact reached renderer-parent ready and stayed alive until timeout"
      ;;
    *)
      echo "failed: artifact exit status $status" >&2
      print_artifact_log "$log"
      rm -f "$log"
      rm -rf "$cache_dir"
      return "$status"
      ;;
  esac

  rm -f "$log"
  rm -rf "$cache_dir"
}

should_run_language() {
  local candidate="$1"

  [ "$LANGUAGE" = "all" ] || [ "$LANGUAGE" = "$candidate" ]
}

build_payloads_for_language() {
  local language="$1"

  if [ "$BUILD_PAYLOADS" != "1" ]; then
    return 0
  fi

  case "$language" in
    elixir|gleam|ruby|typescript)
      while IFS= read -r script; do
        echo "==> build ${script#$ROOT/}"
        (cd "$(dirname "$script")/.." && run_with_language_mise_config "$language" ./scripts/package.sh)
      done < <(find "$ROOT/$language" -path '*/scripts/package.sh' -type f | sort)
      ;;
    python)
      while IFS= read -r script; do
        echo "==> build ${script#$ROOT/}"
        (cd "$(dirname "$script")" && run_with_language_mise_config "$language" ./build_standalone.sh)
      done < <(find "$ROOT/python" -name build_standalone.sh -type f | sort)
      ;;
  esac
}

manifests_for_language() {
  local language="$1"

  case "$language" in
    elixir|gleam|ruby)
      find "$ROOT/$language" -path '*/dist/plushie-package.toml' -type f | sort
      ;;
    python)
      find "$ROOT/python" -path '*/dist/package/plushie-package.toml' -type f | sort
      ;;
    typescript)
      find "$ROOT/typescript" -path '*/dist/shared-launcher/plushie-package.toml' -type f | sort
      ;;
    rust)
      true
      ;;
  esac
}

smoke_language() {
  local language="$1"
  local count=0

  build_payloads_for_language "$language"

  while IFS= read -r manifest; do
    count=$((count + 1))
    local rel="${manifest#$ROOT/}"
    local demo="${rel%%/dist/*}"
    local safe="${demo//\//-}"
    local out="$ROOT/$demo/dist/package-smoke/$safe"

    echo "==> smoke $rel"
    run_package_command "$manifest" "$out"
    run_artifact_command "$out"
  done < <(manifests_for_language "$language")

  if [ "$count" -eq 0 ]; then
    echo "skip: $language - no package manifest found"
  fi
}

case "$LANGUAGE" in
  all|elixir|gleam|python|ruby|rust|typescript) ;;
  *)
    echo "usage: $0 [all|elixir|gleam|python|ruby|rust|typescript]" >&2
    exit 2
    ;;
esac

for language in elixir gleam python ruby rust typescript; do
  if should_run_language "$language"; then
    smoke_language "$language"
  fi
done
