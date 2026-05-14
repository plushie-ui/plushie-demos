#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
BUILD_DIR="$PROJECT_DIR/build/package"
PAYLOAD_DIR="$DIST_DIR/payload"
APP_DIR="$PAYLOAD_DIR/app"
RUBY_DIR="$PAYLOAD_DIR/ruby"
DEFAULT_PLUSHIE_RUBY_DIR="$(cd "$PROJECT_DIR/../../../plushie-ruby" 2>/dev/null && pwd || true)"
PLUSHIE_RUBY_DIR="${PLUSHIE_RUBY_DIR:-$DEFAULT_PLUSHIE_RUBY_DIR}"

# shellcheck source=../../../scripts/package_lib.sh
source "$ROOT_DIR/scripts/package_lib.sh"

cd "$PROJECT_DIR"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

ruby_config() {
  ruby -rrbconfig -e "print RbConfig::CONFIG.fetch('$1')"
}

resolve_renderer() {
  if [ -n "${PLUSHIE_BINARY_PATH:-}" ]; then
    printf '%s\n' "$PLUSHIE_BINARY_PATH"
  elif [ -n "${PLUSHIE_RUST_SOURCE_PATH:-}" ]; then
    if [ ! -f "$PLUSHIE_RUST_SOURCE_PATH/Cargo.toml" ]; then
      echo "PLUSHIE_RUST_SOURCE_PATH does not look like a Rust workspace: $PLUSHIE_RUST_SOURCE_PATH" >&2
      exit 1
    fi

    require_command cargo
    echo "Building plushie-renderer from $PLUSHIE_RUST_SOURCE_PATH" >&2
    (cd "$PLUSHIE_RUST_SOURCE_PATH" && cargo build --release -p plushie-renderer)
    printf '%s\n' "$PLUSHIE_RUST_SOURCE_PATH/target/release/plushie-renderer"
  elif bundle exec ruby -rplushie -e 'path = Plushie::Binary.path; exit 1 unless path; print path' 2>/dev/null; then
    true
  elif command -v plushie-renderer >/dev/null 2>&1; then
    command -v plushie-renderer
  elif command -v plushie >/dev/null 2>&1; then
    command -v plushie
  else
    echo "No renderer binary found. Run bundle exec rake plushie:download or set PLUSHIE_BINARY_PATH." >&2
    exit 1
  fi
}

require_command bundle
require_command ruby
require_command tar

if command -v tebako >/dev/null 2>&1; then
  echo "Tebako is installed, but this proof keeps the directory-runtime payload path explicit."
else
  echo "Tebako is not installed; using the directory-runtime payload path."
fi

renderer="$(resolve_renderer)"
ruby_prefix="$(ruby_config prefix)"
ruby_install_name="$(ruby_config ruby_install_name)"
ruby_exeext="$(ruby_config EXEEXT)"
target="$(normalize_package_target "$(ruby_config host_os)" "$(ruby_config host_cpu)")"

echo "Preparing payload..."
rm -rf "$DIST_DIR" "$BUILD_DIR"
mkdir -p "$APP_DIR/bin" "$APP_DIR/lib" "$APP_DIR/.bundle" "$PAYLOAD_DIR/bin" "$RUBY_DIR" "$BUILD_DIR"

cp -R "$ruby_prefix"/. "$RUBY_DIR"/
cp -R lib/. "$APP_DIR/lib/"
cp bin/connect "$APP_DIR/bin/connect"
chmod +x "$APP_DIR/bin/connect"

if [ -n "$PLUSHIE_RUBY_DIR" ] && [ -d "$PLUSHIE_RUBY_DIR/lib/plushie" ]; then
  echo "Using local plushie SDK from $PLUSHIE_RUBY_DIR"
  mkdir -p "$APP_DIR/vendor/plushie-ruby"
  cp -R "$PLUSHIE_RUBY_DIR"/. "$APP_DIR/vendor/plushie-ruby/"
  rm -rf "$APP_DIR/vendor/plushie-ruby/.git"

  cat > "$APP_DIR/Gemfile" <<'GEMFILE'
# frozen_string_literal: true

source "https://rubygems.org"

gem "plushie", path: "vendor/plushie-ruby"
GEMFILE
else
  cp Gemfile "$APP_DIR/Gemfile"
fi

echo "Installing runtime gems..."
(
  cd "$APP_DIR"
  bundle config set --local path vendor/bundle
  bundle config set --local without "development test"
  bundle install
)

cp "$renderer" "$PAYLOAD_DIR/bin/plushie-renderer"
chmod +x "$PAYLOAD_DIR/bin/plushie-renderer"

dereference_payload_symlinks "$PAYLOAD_DIR"

metadata="$(
  cd "$APP_DIR"
  "$RUBY_DIR/bin/$ruby_install_name$ruby_exeext" -rbundler/setup -rplushie -e '
    puts Plushie::VERSION
    puts Plushie::PLUSHIE_RUST_VERSION
    puts Plushie::Protocol::PROTOCOL_VERSION
  '
)"
host_sdk_version="$(printf '%s\n' "$metadata" | sed -n '1p')"
plushie_rust_version="$(printf '%s\n' "$metadata" | sed -n '2p')"
protocol_version="$(printf '%s\n' "$metadata" | sed -n '3p')"

echo "Writing archive..."
archive_payload "$PAYLOAD_DIR" "$DIST_DIR/payload.tar.zst"
payload_hash="$(hash_file "$DIST_DIR/payload.tar.zst")"
payload_size="$(file_size "$DIST_DIR/payload.tar.zst")"
echo "Payload archive size: $payload_size bytes"

cat > "$DIST_DIR/plushie-package.toml" <<EOF
schema_version = 1
app_id = "dev.plushie.demos.ruby.notes"
app_name = "Ruby Notes"
app_version = "0.1.0"
target = "$target"

host_sdk = "ruby"
host_sdk_version = "$host_sdk_version"
plushie_rust_version = "$plushie_rust_version"
protocol_version = $protocol_version

renderer_path = "bin/plushie-renderer"
host_command = ["ruby/bin/$ruby_install_name$ruby_exeext", "bin/connect"]
working_dir = "app"
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
