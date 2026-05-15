#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_PLUSHIE_RUST_SOURCE_PATH="$(cd "$ROOT/../plushie-rust" 2>/dev/null && pwd || true)"
LANGUAGE="${1:-all}"
POSTCHECK_TIMEOUT="${PACKAGE_POSTCHECK_TIMEOUT:-10}"
BUILD_PAYLOADS="${PACKAGE_POSTCHECK_BUILD:-0}"
RUN_ARTIFACTS="${PACKAGE_POSTCHECK_RUN_ARTIFACTS:-0}"
ARTIFACT_TIMEOUT="${PACKAGE_ARTIFACT_TIMEOUT:-10s}"
ARTIFACT_RUNTIME_PATH="${PACKAGE_ARTIFACT_RUNTIME_PATH:-}"
STRICT="${PACKAGE_POSTCHECK_STRICT:-0}"
ALLOW_LOCAL_SKIPS="${PACKAGE_POSTCHECK_ALLOW_LOCAL_SKIPS:-0}"
PACKAGE_COMMAND_BUILT=0
HEADLESS_WESTON_STARTED=0
HEADLESS_WESTON_PID=""
HEADLESS_WESTON_RUNTIME_DIR=""
HEADLESS_WESTON_LOG=""
HEADLESS_WESTON_SOCKET_PATH=""

# shellcheck source=package_lib.sh
source "$ROOT/scripts/package_lib.sh"

strict_mode() {
  [ "$STRICT" = "1" ] && [ "$ALLOW_LOCAL_SKIPS" != "1" ]
}

skip_or_fail() {
  local context="$1"
  local reason="$2"

  if strict_mode; then
    echo "failed: $context - $reason" >&2
    return 1
  fi

  echo "skip: $context - $reason" >&2
  return 0
}

skip_or_fail_status() {
  local context="$1"
  local reason="$2"

  if strict_mode; then
    echo "failed: $context - $reason" >&2
    return 1
  fi

  echo "skip: $context - $reason" >&2
  return 2
}

if [ "$STRICT" = "1" ] && [ "$RUN_ARTIFACTS" != "1" ]; then
  if [ "$ALLOW_LOCAL_SKIPS" = "1" ]; then
    echo "skip: strict package release check - artifact runs disabled by explicit local-skip mode" >&2
  else
    echo "failed: strict package release check - artifact runs are disabled" >&2
    exit 1
  fi
fi

if [ -z "${PLUSHIE_RUST_SOURCE_PATH:-}" ] &&
  [ -n "$DEFAULT_PLUSHIE_RUST_SOURCE_PATH" ] &&
  [ -f "$DEFAULT_PLUSHIE_RUST_SOURCE_PATH/Cargo.toml" ]; then
  export PLUSHIE_RUST_SOURCE_PATH="$DEFAULT_PLUSHIE_RUST_SOURCE_PATH"
fi

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

    echo "failed: package artifact postcheck - headless weston stopped before artifact run" >&2
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
    skip_or_fail_status "package artifact postcheck" "no display server is available and weston is unavailable"
    return $?
  fi

  HEADLESS_WESTON_RUNTIME_DIR="$(mktemp -d "${TMPDIR:-/tmp}/plushie-package-weston.XXXXXXXXXX")"
  HEADLESS_WESTON_LOG="$(mktemp "${TMPDIR:-/tmp}/plushie-package-weston-log.XXXXXXXXXX")"
  chmod 700 "$HEADLESS_WESTON_RUNTIME_DIR"

  socket_name="plushie-package-postcheck-$$"
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
      echo "==> started headless weston for artifact postcheck"
      echo "    XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
      echo "    WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
      return 0
    fi

    if ! kill -0 "$HEADLESS_WESTON_PID" >/dev/null 2>&1; then
      echo "failed: package artifact postcheck - headless weston exited before creating $socket_name" >&2
      sed -n '1,120p' "$HEADLESS_WESTON_LOG" >&2
      return 1
    fi

    sleep 0.1
  done

  echo "failed: package artifact postcheck - timed out waiting for headless weston socket $socket_name" >&2
  sed -n '1,120p' "$HEADLESS_WESTON_LOG" >&2
  return 1
}

run_clean_from_temp_cwd() {
  local scrubbed_env_args=()
  local postcheck_cwd
  local status

  while IFS='=' read -r name _; do
    case "$name" in
      PLUSHIE_CACHE_DIR) ;;
      PLUSHIE_*) scrubbed_env_args+=("-u" "$name") ;;
    esac
  done < <(env)

  postcheck_cwd="$(mktemp -d "${TMPDIR:-/tmp}/plushie-package-postcheck-cwd.XXXXXXXXXX")"

  if (
    set -e
    cd "$postcheck_cwd"

    env "${scrubbed_env_args[@]}" "$@"
  ); then
    status=0
  else
    status=$?
  fi

  rm -rf "$postcheck_cwd"
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
  local postcheck_cwd
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

  postcheck_cwd="$(mktemp -d "${TMPDIR:-/tmp}/plushie-package-artifact-cwd.XXXXXXXXXX")"

  if (
    set -e
    cd "$postcheck_cwd"

    env "${scrubbed_env_args[@]}" PATH="$ARTIFACT_LAUNCH_PATH" "$@"
  ); then
    status=0
  else
    status=$?
  fi

  rm -rf "$postcheck_cwd"
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
    skip_or_fail "package postcheck" "cargo is unavailable; install Rust or set up cargo-plushie"
    return $?
  fi

  if [ -n "${PLUSHIE_RUST_SOURCE_PATH:-}" ] && [ -f "$PLUSHIE_RUST_SOURCE_PATH/Cargo.toml" ]; then
    cargo_plushie_dir="$(cd "$PLUSHIE_RUST_SOURCE_PATH" && pwd)"
  elif ! command -v cargo-plushie >/dev/null 2>&1; then
    skip_or_fail "package postcheck" "cargo-plushie is unavailable; install cargo-plushie or set PLUSHIE_RUST_SOURCE_PATH"
    return $?
  fi

  if [ -n "$cargo_plushie_dir" ]; then
    run_clean_from_temp_cwd \
      cargo run -q -p cargo-plushie \
      --manifest-path "$cargo_plushie_dir/Cargo.toml" \
      -- package \
      --manifest "$manifest" \
      --postcheck \
      --postcheck-timeout "$POSTCHECK_TIMEOUT" \
      --out "$out"
  else
    run_clean_from_temp_cwd \
      cargo plushie package \
      --manifest "$manifest" \
      --postcheck \
      --postcheck-timeout "$POSTCHECK_TIMEOUT" \
      --out "$out"
  fi
  PACKAGE_COMMAND_BUILT=1
}

extract_payload_archive() {
  local archive="$1"
  local out_dir="$2"
  local tar_bin

  tar_bin="$(archive_tar_command)"
  mkdir -p "$out_dir"

  if archive_tar_supports_gnu_flags && "$tar_bin" --help 2>/dev/null | grep -q -- '--zstd'; then
    "$tar_bin" -C "$out_dir" --zstd -xf "$archive"
  else
    if ! command -v zstd >/dev/null 2>&1; then
      echo "Missing required command: zstd" >&2
      return 1
    fi

    zstd -dc "$archive" | "$tar_bin" -C "$out_dir" -xf -
  fi
}

resolve_stock_renderer_for_negative_postcheck() {
  if [ -n "${PLUSHIE_RUST_SOURCE_PATH:-}" ] && [ -f "$PLUSHIE_RUST_SOURCE_PATH/Cargo.toml" ]; then
    cargo build --release -p plushie-renderer --manifest-path "$PLUSHIE_RUST_SOURCE_PATH/Cargo.toml"
    printf '%s\n' "$PLUSHIE_RUST_SOURCE_PATH/target/release/plushie-renderer"
  elif command -v plushie-renderer >/dev/null 2>&1; then
    command -v plushie-renderer
  else
    return 2
  fi
}

write_native_negative_manifest() {
  local input="$1"
  local output="$2"
  local payload_hash="$3"
  local payload_size="$4"
  local line

  while IFS= read -r line; do
    case "$line" in
      'hash = '*)
        printf 'hash = "sha256:%s"\n' "$payload_hash"
        ;;
      'size = '*)
        printf 'size = %s\n' "$payload_size"
        ;;
      'kind = "custom"')
        printf 'kind = "stock"\n'
        ;;
      'source = "local-build"')
        printf 'source = "negative-postcheck"\n'
        ;;
      *)
        printf '%s\n' "$line"
        ;;
    esac
  done < "$input" > "$output"
}

assert_native_package_requires_custom_renderer() {
  local language="$1"

  case "$language" in
    elixir)
      echo "==> assert elixir/gauge-demo rejects stock renderer packaging"
      if (
        cd "$ROOT/elixir/gauge-demo"
        run_with_language_mise_config elixir \
          env PLUSHIE_PACKAGE_RENDERER_KIND=stock ./scripts/package.sh </dev/null
      ); then
        echo "failed: elixir/gauge-demo package accepted a stock renderer for native widgets" >&2
        return 1
      fi
      ;;
    gleam)
      echo "==> assert gleam/gauge-demo rejects stock renderer packaging"
      if (
        cd "$ROOT/gleam/gauge-demo"
        run_with_language_mise_config gleam \
          env PLUSHIE_PACKAGE_RENDERER_KIND=stock ./scripts/package.sh </dev/null
      ); then
        echo "failed: gleam/gauge-demo package accepted a stock renderer for native widgets" >&2
        return 1
      fi
      ;;
  esac
}

assert_native_package_rejects_missing_widget() {
  local language="$1"
  local demo=""
  local manifest
  local archive
  local renderer_name
  local safe
  local tmp
  local stock_renderer
  local payload_hash
  local payload_size
  local out
  local display_status

  if [ "$RUN_ARTIFACTS" != "1" ]; then
    return 0
  fi

  case "$language" in
    elixir)
      demo="elixir/gauge-demo"
      renderer_name="gauge-demo-plushie"
      ;;
    gleam)
      demo="gleam/gauge-demo"
      renderer_name="plushie-renderer"
      ;;
    *)
      return 0
      ;;
  esac

  manifest="$ROOT/$demo/dist/plushie-package.toml"
  archive="$ROOT/$demo/dist/payload.tar.zst"
  safe="${demo//\//-}"

  if [ ! -f "$manifest" ] || [ ! -f "$archive" ]; then
    skip_or_fail "native widget negative postcheck" "$demo package artifact is missing"
    return $?
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

  if stock_renderer="$(resolve_stock_renderer_for_negative_postcheck)"; then
    :
  else
    case "$?" in
      2)
        skip_or_fail "native widget negative postcheck" "no stock renderer available"
        return $?
        ;;
      *) return 1 ;;
    esac
  fi

  tmp="$(mktemp -d "${TMPDIR:-/tmp}/plushie-native-negative.XXXXXXXXXX")"
  mkdir -p "$tmp/dist"

  extract_payload_archive "$archive" "$tmp/payload"
  cp "$stock_renderer" "$tmp/payload/bin/$renderer_name"
  chmod +x "$tmp/payload/bin/$renderer_name"
  archive_payload "$tmp/payload" "$tmp/dist/payload.tar.zst"
  payload_hash="$(hash_file "$tmp/dist/payload.tar.zst")"
  payload_size="$(file_size "$tmp/dist/payload.tar.zst")"
  write_native_negative_manifest "$manifest" "$tmp/dist/plushie-package.toml" "$payload_hash" "$payload_size"

  out="$tmp/dist/package-postcheck/$safe-stock-renderer"
  echo "==> assert $demo rejects renderer without gauge widget"
  run_package_command "$tmp/dist/plushie-package.toml" "$out"
  if [ "$PACKAGE_COMMAND_BUILT" != "1" ]; then
    rm -rf "$tmp"
    return 0
  fi

  if run_artifact_command "$out" "$tmp/dist/plushie-package.toml"; then
    echo "failed: $demo ran with a renderer missing the gauge widget" >&2
    rm -rf "$tmp"
    return 1
  fi

  echo "ok: $demo rejected renderer without gauge widget"
  rm -rf "$tmp"
}

run_artifact_command() {
  local artifact="$1"
  local manifest="$2"
  local artifact_path
  local cache_dir
  local display_status
  local log
  local report
  local status
  local timeout_bin
  local timeout_args

  if [ "$RUN_ARTIFACTS" != "1" ]; then
    if strict_mode; then
      echo "failed: package artifact postcheck - artifact runs are disabled" >&2
      return 1
    fi
    return 0
  fi

  if [ "$PACKAGE_COMMAND_BUILT" != "1" ]; then
    skip_or_fail "package artifact postcheck" "launcher was not built in this run"
    return $?
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
    skip_or_fail "package artifact postcheck" "timeout is unavailable"
    return $?
  fi
  timeout_bin="$(command -v timeout)"

  if [ ! -x "$artifact" ]; then
    echo "failed: package artifact postcheck - launcher is not executable: $artifact" >&2
    return 1
  fi

  log="$(mktemp "${TMPDIR:-/tmp}/plushie-package-artifact.XXXXXXXXXX")"
  cache_dir="$(mktemp -d "${TMPDIR:-/tmp}/plushie-package-artifact-cache.XXXXXXXXXX")"
  artifact_path="$(artifact_runtime_path)"
  report="$artifact.report"

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

  write_artifact_report "$report" "$manifest" "$artifact" "$artifact_path" "$status" "$log"

  if grep -q "plushie launcher: postcheck ok" "$log"; then
    echo "failed: artifact used launcher postcheck mode" >&2
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

  if grep -q "unknown node type" "$log"; then
    echo "failed: artifact renderer reported an unknown widget type" >&2
    print_artifact_log "$log"
    rm -f "$log"
    rm -rf "$cache_dir"
    return 1
  fi

  case "$status" in
    0)
      if ! grep -q "plushie launcher: host exited" "$log"; then
        echo "failed: artifact exited before host shutdown" >&2
        print_artifact_log "$log"
        rm -f "$log"
        rm -rf "$cache_dir"
        return 1
      fi
      echo "ok: artifact exited cleanly"
      ;;
    124|137)
      echo "ok: artifact started and stayed alive until timeout"
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

manifest_value() {
  local manifest="$1"
  local key="$2"

  awk -F '=' -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value = $2
      sub(/^[[:space:]]*/, "", value)
      sub(/[[:space:]]*$/, "", value)
      gsub(/^"|"$/, "", value)
      print value
      exit
    }
  ' "$manifest"
}

write_artifact_report() {
  local report="$1"
  local manifest="$2"
  local artifact="$3"
  local runtime_path="$4"
  local status="$5"
  local log="$6"
  local demo_dir
  local alive_until_timeout="no"
  local unknown_widget="no"
  local renderer_path=""

  demo_dir="$(demo_dir_for_manifest "$manifest")"
  case "$status" in
    124|137) alive_until_timeout="yes" ;;
  esac
  grep -q "unknown node type" "$log" && unknown_widget="yes"
  renderer_path="$(sed -n 's/.* renderer=\([^ ]*\) .*/\1/p' "$log" | head -n 1)"

  mkdir -p "$(dirname "$report")"
  {
    printf 'manifest=%s\n' "${manifest#$ROOT/}"
    printf 'artifact=%s\n' "${artifact#$ROOT/}"
    printf 'app_id=%s\n' "$(manifest_value "$manifest" app_id)"
    printf 'app_version=%s\n' "$(manifest_value "$manifest" app_version)"
    printf 'target=%s\n' "$(manifest_value "$manifest" target)"
    printf 'host_sdk=%s\n' "$(manifest_value "$manifest" host_sdk)"
    printf 'host_sdk_version=%s\n' "$(manifest_value "$manifest" host_sdk_version)"
    printf 'plushie_rust_version=%s\n' "$(manifest_value "$manifest" plushie_rust_version)"
    printf 'protocol_version=%s\n' "$(manifest_value "$manifest" protocol_version)"
    printf 'host_sdk_dependency=%s\n' "$(host_sdk_dependency "$demo_dir")"
    printf 'native_widget_crates=%s\n' "$(native_widget_crates "$demo_dir")"
    printf 'renderer_kind=%s\n' "$(manifest_value "$manifest" kind)"
    printf 'payload_hash=%s\n' "$(manifest_value "$manifest" hash)"
    printf 'payload_size=%s\n' "$(manifest_value "$manifest" size)"
    printf 'artifact_size=%s\n' "$(file_size "$artifact")"
    printf 'runtime_path=%s\n' "$runtime_path"
    printf 'exit_status=%s\n' "$status"
    printf 'alive_until_timeout=%s\n' "$alive_until_timeout"
    printf 'unknown_widget=%s\n' "$unknown_widget"
    printf 'renderer_path=%s\n' "$renderer_path"
  } > "$report"
}

demo_dir_for_manifest() {
  local manifest="$1"
  local rel="${manifest#$ROOT/}"

  printf '%s\n' "${rel%%/dist/*}"
}

host_sdk_dependency() {
  local demo_dir="$1"
  local root="$ROOT/$demo_dir"
  local language="${demo_dir%%/*}"

  case "$language" in
    elixir)
      sed -n 's/.*{:plushie, *\(.*\)}.*/\1/p' "$root/mix.exs" 2>/dev/null | head -n 1 | tr -d '\n'
      ;;
    gleam)
      awk '/plushie_gleam = / { print; exit }' "$root/manifest.toml" 2>/dev/null
      ;;
    python)
      awk '/plushie/ { print; exit }' "$root/pyproject.toml" 2>/dev/null
      ;;
    ruby)
      awk '/plushie/ { print; exit }' "$root/Gemfile" 2>/dev/null
      ;;
    typescript)
      node -e '
        const fs = require("fs");
        const path = process.argv[1];
        const pkg = JSON.parse(fs.readFileSync(path, "utf8"));
        const deps = { ...(pkg.dependencies || {}), ...(pkg.devDependencies || {}) };
        process.stdout.write(deps.plushie || "");
      ' "$root/package.json" 2>/dev/null
      ;;
    rust)
      awk '/plushie = / { print; exit }' "$root/Cargo.toml" 2>/dev/null
      ;;
  esac
}

native_widget_crates() {
  local demo_dir="$1"
  local root="$ROOT/$demo_dir"
  local crate
  local name
  local version
  local sdk
  local output=()

  if [ ! -d "$root/native" ]; then
    return 0
  fi

  while IFS= read -r crate; do
    name="$(awk -F '"' '/^name = / { print $2; exit }' "$crate")"
    version="$(awk -F '"' '/^version = / { print $2; exit }' "$crate")"
    sdk="$(awk -F '"' '/^plushie-widget-sdk = / { print $2; exit }' "$crate")"
    output+=("$name:$version:plushie-widget-sdk=$sdk")
  done < <(find "$root/native" -name Cargo.toml -type f | sort)

  (IFS=','; printf '%s\n' "${output[*]}")
}

expected_plushie_rust_version() {
  if [ -n "${PLUSHIE_RUST_SOURCE_PATH:-}" ] && [ -f "$PLUSHIE_RUST_SOURCE_PATH/Cargo.toml" ]; then
    awk -F '"' '/^version = / { print $2; exit }' "$PLUSHIE_RUST_SOURCE_PATH/Cargo.toml"
  fi
}

expected_host_sdk_version() {
  local demo_dir="$1"
  local language="${demo_dir%%/*}"
  local sdk_root=""

  case "$language" in
    elixir)
      sdk_root="${PLUSHIE_ELIXIR_DIR:-$ROOT/../plushie-elixir}"
      [ -f "$sdk_root/mix.exs" ] || return 0
      awk -F '"' '/@version / { print $2; exit }' "$sdk_root/mix.exs"
      ;;
    gleam)
      sdk_root="${PLUSHIE_GLEAM_DIR:-$ROOT/../plushie-gleam}"
      [ -f "$sdk_root/gleam.toml" ] || return 0
      awk -F '"' '/^version = / { print $2; exit }' "$sdk_root/gleam.toml"
      ;;
    python)
      sdk_root="${PLUSHIE_PYTHON_DIR:-$ROOT/../plushie-python}"
      [ -f "$sdk_root/pyproject.toml" ] || return 0
      awk -F '"' '/^version = / { print $2; exit }' "$sdk_root/pyproject.toml"
      ;;
    ruby)
      sdk_root="${PLUSHIE_RUBY_DIR:-$ROOT/../plushie-ruby}"
      [ -f "$sdk_root/lib/plushie/version.rb" ] || return 0
      awk -F '"' '/VERSION = / { print $2; exit }' "$sdk_root/lib/plushie/version.rb"
      ;;
    typescript)
      sdk_root="${PLUSHIE_TYPESCRIPT_DIR:-$ROOT/../plushie-typescript}"
      [ -f "$sdk_root/package.json" ] || return 0
      node -e '
        const fs = require("fs");
        const path = process.argv[1];
        const pkg = JSON.parse(fs.readFileSync(path, "utf8"));
        process.stdout.write(pkg.version || "");
      ' "$sdk_root/package.json" 2>/dev/null
      ;;
    rust)
      expected_plushie_rust_version
      ;;
  esac
}

assert_manifest_value_present() {
  local manifest="$1"
  local key="$2"
  local value

  value="$(manifest_value "$manifest" "$key")"
  if [ -z "$value" ]; then
    echo "failed: package manifest ${manifest#$ROOT/} is missing $key" >&2
    return 1
  fi
}

payload_archive_path() {
  local manifest="$1"
  local archive

  archive="$(manifest_value "$manifest" archive)"
  if [ -z "$archive" ]; then
    archive="payload.tar.zst"
  fi

  case "$archive" in
    /*) printf '%s\n' "$archive" ;;
    *) printf '%s\n' "$(dirname "$manifest")/$archive" ;;
  esac
}

payload_archive_contains() {
  local archive="$1"
  local payload_path="$2"
  local listing
  local tar_bin
  local status

  listing="$(mktemp "${TMPDIR:-/tmp}/plushie-payload-list.XXXXXXXXXX")"
  tar_bin="$(archive_tar_command)"

  if archive_tar_supports_gnu_flags && "$tar_bin" --help 2>/dev/null | grep -q -- '--zstd'; then
    "$tar_bin" --zstd -tf "$archive" > "$listing"
  else
    if ! command -v zstd >/dev/null 2>&1; then
      echo "Missing required command: zstd" >&2
      rm -f "$listing"
      return 1
    fi

    zstd -dc "$archive" | "$tar_bin" -tf - > "$listing"
  fi

  if grep -Fxq "$payload_path" "$listing" || grep -Fxq "./$payload_path" "$listing"; then
    status=0
  else
    status=1
  fi

  rm -f "$listing"
  return "$status"
}

assert_platform_icon() {
  local manifest="$1"
  local icon
  local archive

  assert_manifest_value_present "$manifest" icon

  icon="$(manifest_value "$manifest" icon)"
  case "$icon" in
    /* | *../* | ../*)
      echo "failed: package manifest ${manifest#$ROOT/} has non-payload icon path: $icon" >&2
      return 1
      ;;
  esac

  archive="$(payload_archive_path "$manifest")"
  if ! payload_archive_contains "$archive" "$icon"; then
    echo "failed: package payload ${archive#$ROOT/} is missing platform icon $icon" >&2
    return 1
  fi
}

assert_version_alignment() {
  local manifest="$1"
  local demo_dir
  local expected
  local actual
  local native_crates

  demo_dir="$(demo_dir_for_manifest "$manifest")"

  assert_manifest_value_present "$manifest" host_sdk
  assert_manifest_value_present "$manifest" app_name
  assert_manifest_value_present "$manifest" host_sdk_version
  assert_manifest_value_present "$manifest" plushie_rust_version
  assert_manifest_value_present "$manifest" protocol_version
  assert_platform_icon "$manifest"

  expected="$(expected_plushie_rust_version)"
  actual="$(manifest_value "$manifest" plushie_rust_version)"
  if [ -n "$expected" ] && [ "$actual" != "$expected" ]; then
    echo "failed: package manifest ${manifest#$ROOT/} has plushie_rust_version=$actual, expected $expected" >&2
    return 1
  fi

  expected="$(expected_host_sdk_version "$demo_dir")"
  actual="$(manifest_value "$manifest" host_sdk_version)"
  if [ -n "$expected" ] && [ "$actual" != "$expected" ]; then
    echo "failed: package manifest ${manifest#$ROOT/} has host_sdk_version=$actual, expected $expected" >&2
    return 1
  fi

  if [ -d "$ROOT/$demo_dir/native" ]; then
    native_crates="$(native_widget_crates "$demo_dir")"
    if [ -z "$native_crates" ]; then
      echo "failed: package manifest ${manifest#$ROOT/} has native widgets but no native crate versions could be recorded" >&2
      return 1
    fi
  fi
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

  assert_native_package_requires_custom_renderer "$language"

  case "$language" in
    elixir|gleam|python|ruby|typescript)
      while IFS= read -r script; do
        echo "==> build ${script#$ROOT/}"
        (cd "$(dirname "$script")/.." && run_with_language_mise_config "$language" ./scripts/package.sh </dev/null)
      done < <(find "$ROOT/$language" -path '*/scripts/package.sh' -type f | sort)
      assert_native_package_rejects_missing_widget "$language"
      ;;
    rust)
      while IFS= read -r script; do
        echo "==> build ${script#$ROOT/}"
        (cd "$(dirname "$script")/.." && run_with_language_mise_config "$language" ./scripts/package.sh </dev/null)
      done < <(find "$ROOT/rust" -path '*/scripts/package.sh' -type f | sort)
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
      find "$ROOT/rust" -path '*/dist/plushie-package.toml' -type f | sort
      ;;
  esac
}

expected_manifests_for_language() {
  local language="$1"

  case "$language" in
    elixir)
      printf '%s\n' \
        "$ROOT/elixir/gauge-demo/dist/plushie-package.toml" \
        "$ROOT/elixir/notes/dist/plushie-package.toml"
      ;;
    gleam)
      printf '%s\n' \
        "$ROOT/gleam/gauge-demo/dist/plushie-package.toml" \
        "$ROOT/gleam/notes/dist/plushie-package.toml"
      ;;
    python)
      printf '%s\n' \
        "$ROOT/python/data-explorer/dist/package/plushie-package.toml"
      ;;
    ruby)
      printf '%s\n' \
        "$ROOT/ruby/notes/dist/plushie-package.toml"
      ;;
    rust)
      printf '%s\n' \
        "$ROOT/rust/plushie_pad/dist/plushie-package.toml"
      ;;
    typescript)
      printf '%s\n' \
        "$ROOT/typescript/data-explorer/dist/shared-launcher/plushie-package.toml"
      ;;
  esac
}

assert_expected_manifests_for_language() {
  local language="$1"
  local manifest

  if ! strict_mode; then
    return 0
  fi

  while IFS= read -r manifest; do
    if [ ! -f "$manifest" ]; then
      echo "failed: $language - expected package manifest is missing: ${manifest#$ROOT/}" >&2
      return 1
    fi
  done < <(expected_manifests_for_language "$language")
}

postcheck_language() {
  local language="$1"
  local count=0

  build_payloads_for_language "$language"
  assert_expected_manifests_for_language "$language"

  while IFS= read -r manifest; do
    count=$((count + 1))
    local rel="${manifest#$ROOT/}"
    local demo="${rel%%/dist/*}"
    local safe="${demo//\//-}"
    local out="$ROOT/$demo/dist/package-postcheck/$safe"

    echo "==> postcheck $rel"
    assert_version_alignment "$manifest"
    run_package_command "$manifest" "$out"
    if [ "$language" = "rust" ] && [ "$PACKAGE_COMMAND_BUILT" != "1" ]; then
      echo "failed: rust package postcheck could not run cargo plushie package --postcheck" >&2
      return 1
    fi
    run_artifact_command "$out" "$manifest"
  done < <(manifests_for_language "$language")

  if [ "$count" -eq 0 ]; then
    if strict_mode; then
      echo "failed: $language - no package manifest found" >&2
      return 1
    fi

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
    postcheck_language "$language"
  fi
done
