#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
PAYLOAD_DIR="$DIST_DIR/payload"
SHIPMENT_DIR="$PROJECT_DIR/build/erlang-shipment"
BUNDLE_ERLANG="${PLUSHIE_BUNDLE_ERLANG:-1}"

cd "$PROJECT_DIR"

# shellcheck source=../../../scripts/package_lib.sh
source "$ROOT_DIR/scripts/package_lib.sh"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

resolve_renderer() {
  if [ -n "${PLUSHIE_BINARY_PATH:-}" ]; then
    if [ ! -x "$PLUSHIE_BINARY_PATH" ]; then
      echo "PLUSHIE_BINARY_PATH is not executable: $PLUSHIE_BINARY_PATH" >&2
      exit 1
    fi

    printf '%s\n' "$PLUSHIE_BINARY_PATH"
  elif [ -x "$SHIPMENT_DIR/plushie-renderer" ]; then
    printf '%s\n' "$SHIPMENT_DIR/plushie-renderer"
  elif [ -n "${PLUSHIE_RUST_SOURCE_PATH:-}" ]; then
    if [ ! -f "$PLUSHIE_RUST_SOURCE_PATH/Cargo.toml" ]; then
      echo "PLUSHIE_RUST_SOURCE_PATH does not look like a Rust workspace: $PLUSHIE_RUST_SOURCE_PATH" >&2
      exit 1
    fi

    require_command cargo
    echo "Building plushie-renderer from $PLUSHIE_RUST_SOURCE_PATH" >&2
    (cd "$PLUSHIE_RUST_SOURCE_PATH" && cargo build --release -p plushie-renderer)
    printf '%s\n' "$PLUSHIE_RUST_SOURCE_PATH/target/release/plushie-renderer"
  elif command -v plushie-renderer >/dev/null 2>&1; then
    command -v plushie-renderer
  else
    echo "No renderer binary found. Run gleam run -m plushie/download or set PLUSHIE_BINARY_PATH." >&2
    exit 1
  fi
}

resolve_erlang_root() {
  if [ -n "${PLUSHIE_ERLANG_ROOT:-}" ]; then
    printf '%s\n' "$PLUSHIE_ERLANG_ROOT"
  elif command -v erl >/dev/null 2>&1; then
    erl -noshell -eval 'io:format("~s~n", [code:root_dir()]), halt().'
  else
    echo "No Erlang runtime found. Install Erlang, set PLUSHIE_ERLANG_ROOT, or set PLUSHIE_BUNDLE_ERLANG=0 to package without a runtime." >&2
    exit 1
  fi
}

find_runtime_dir() {
  root="$1"
  pattern="$2"
  dir="$(find "$root" -maxdepth 1 -type d -name "$pattern" | sort | tail -n 1)"

  if [ -z "$dir" ]; then
    echo "Erlang runtime is missing $pattern under $root" >&2
    exit 1
  fi

  printf '%s\n' "$dir"
}

copy_erlang_runtime() {
  root="$(resolve_erlang_root)"
  runtime_dir="$PAYLOAD_DIR/runtime/erlang"
  erts_dir="$(find_runtime_dir "$root" 'erts-*')"
  crypto_dir="$(find_runtime_dir "$root/lib" 'crypto-*')"
  kernel_dir="$(find_runtime_dir "$root/lib" 'kernel-*')"
  sasl_dir="$(find_runtime_dir "$root/lib" 'sasl-*')"
  stdlib_dir="$(find_runtime_dir "$root/lib" 'stdlib-*')"

  if [ ! -x "$root/bin/erl" ]; then
    echo "Erlang runtime root has no executable bin/erl: $root" >&2
    exit 1
  fi

  if [ ! -d "$root/releases" ]; then
    echo "Erlang runtime root has no releases directory: $root" >&2
    exit 1
  fi

  echo "Bundling Erlang runtime from $root"
  mkdir -p "$runtime_dir/lib"
  cp -aL "$root/bin" "$runtime_dir/"
  cp -aL "$root/releases" "$runtime_dir/"
  cp -aL "$erts_dir" "$runtime_dir/"
  cp -aL "$crypto_dir" "$runtime_dir/lib/"
  cp -aL "$kernel_dir" "$runtime_dir/lib/"
  cp -aL "$sasl_dir" "$runtime_dir/lib/"
  cp -aL "$stdlib_dir" "$runtime_dir/lib/"

  env -u ERL_ROOTDIR "$runtime_dir/bin/erl" \
    -noshell \
    -eval 'ok = application:ensure_started(crypto), halt().'
}

require_command gleam
require_command tar

renderer="$(resolve_renderer)"
target="$(package_target)"
plushie_rust_version="${PLUSHIE_RUST_VERSION:-$(awk -F '"' '/^plushie_rust_version = / { print $2 }' gleam.toml)}"

echo "Building shipment..."
gleam export erlang-shipment

echo "Preparing payload..."
rm -rf "$DIST_DIR"
mkdir -p "$PAYLOAD_DIR/bin" "$PAYLOAD_DIR/shipment"
cp -R "$SHIPMENT_DIR"/. "$PAYLOAD_DIR/shipment/"
cp "$renderer" "$PAYLOAD_DIR/bin/plushie-renderer"
chmod +x "$PAYLOAD_DIR/bin/plushie-renderer"

case "$BUNDLE_ERLANG" in
  1|true|yes)
    copy_erlang_runtime
    ;;
  0|false|no)
    echo "Skipping Erlang runtime bundle; package will require erl on PATH."
    ;;
  *)
    echo "PLUSHIE_BUNDLE_ERLANG must be 1 or 0." >&2
    exit 1
    ;;
esac

cat > "$PAYLOAD_DIR/bin/connect" <<'SH'
#!/bin/sh
set -eu
DIR="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"

if [ -x "$DIR/runtime/erlang/bin/erl" ]; then
  ERL="$DIR/runtime/erlang/bin/erl"
  unset ERL_ROOTDIR
elif command -v erl >/dev/null 2>&1; then
  ERL="$(command -v erl)"
else
  echo "No Erlang runtime found. Expected $DIR/runtime/erlang/bin/erl or erl on PATH." >&2
  exit 127
fi

exec "$ERL" -pa "$DIR"/shipment/*/ebin -eval 'notes@connect:main().' -noshell -extra "$@"
SH
chmod +x "$PAYLOAD_DIR/bin/connect"

echo "Writing archive..."
archive_payload "$PAYLOAD_DIR" "$DIST_DIR/payload.tar.zst"
payload_hash="$(hash_file "$DIST_DIR/payload.tar.zst")"
payload_size="$(file_size "$DIST_DIR/payload.tar.zst")"

cat > "$DIST_DIR/plushie-package.toml" <<EOF
schema_version = 1
app_id = "dev.plushie.demos.gleam.notes"
app_version = "0.1.0"
target = "$target"
host_sdk = "gleam"
plushie_rust_version = "$plushie_rust_version"
protocol_version = 1
renderer_path = "bin/plushie-renderer"
host_command = ["bin/connect"]
working_dir = "."
exec_env = []

[renderer]
kind = "stock"
source = "local-resolve"

[payload]
archive = "payload.tar.zst"
hash = "sha256:$payload_hash"
size = $payload_size
EOF

echo "Wrote $DIST_DIR/payload.tar.zst"
echo "Wrote $DIST_DIR/plushie-package.toml"
echo "Build launcher with:"
echo "  cargo plushie package --manifest $DIST_DIR/plushie-package.toml --release"
