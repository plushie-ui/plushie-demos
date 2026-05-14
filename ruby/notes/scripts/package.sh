#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
BUILD_DIR="$PROJECT_DIR/build/package"
PAYLOAD_DIR="$DIST_DIR/payload"
APP_DIR="$PAYLOAD_DIR/app"
RUBY_DIR="$PAYLOAD_DIR/ruby"

cd "$PROJECT_DIR"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

file_size() {
  ruby -e 'print File.size(ARGV.fetch(0))' "$1"
}

ruby_config() {
  ruby -rrbconfig -e "print RbConfig::CONFIG.fetch('$1')"
}

resolve_renderer() {
  if [ -n "${PLUSHIE_BINARY_PATH:-}" ]; then
    printf '%s\n' "$PLUSHIE_BINARY_PATH"
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

package_target() {
  ruby -rrbconfig -e '
    host_os = RbConfig::CONFIG.fetch("host_os")
    host_cpu = RbConfig::CONFIG.fetch("host_cpu")

    os = case host_os
    when /linux/i
      "linux"
    when /darwin/i
      "darwin"
    when /mswin|mingw|cygwin/i
      "windows"
    else
      abort "Unsupported package OS: #{host_os}"
    end

    arch = case host_cpu
    when /x86_64|amd64|x64/i
      "x86_64"
    when /aarch64|arm64/i
      "aarch64"
    else
      abort "Unsupported package architecture: #{host_cpu}"
    end

    print "#{os}-#{arch}"
  '
}

archive_payload() {
  if tar --help 2>/dev/null | grep -q -- '--zstd'; then
    (cd "$PAYLOAD_DIR" && tar --zstd -cf "$DIST_DIR/payload.tar.zst" .)
  else
    require_command zstd
    (cd "$PAYLOAD_DIR" && tar -cf - . | zstd -q -o "$DIST_DIR/payload.tar.zst")
  fi
}

dereference_payload_symlinks() {
  local link
  local symlink_target
  local tmp

  while IFS= read -r -d '' link; do
    symlink_target="$(ruby -e 'print File.realpath(ARGV.fetch(0))' "$link")"
    tmp="$link.deref.$$"

    if [ -d "$symlink_target" ]; then
      cp -R "$symlink_target" "$tmp"
    else
      cp "$symlink_target" "$tmp"
    fi

    rm "$link"
    mv "$tmp" "$link"
  done < <(find "$PAYLOAD_DIR" -type l -print0)
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
target="$(package_target)"

echo "Preparing payload..."
rm -rf "$DIST_DIR" "$BUILD_DIR"
mkdir -p "$APP_DIR/bin" "$APP_DIR/lib" "$APP_DIR/.bundle" "$PAYLOAD_DIR/bin" "$RUBY_DIR" "$BUILD_DIR"

cp -R "$ruby_prefix"/. "$RUBY_DIR"/
cp Gemfile "$APP_DIR/Gemfile"
cp -R lib/. "$APP_DIR/lib/"
cp bin/connect "$APP_DIR/bin/connect"
chmod +x "$APP_DIR/bin/connect"

echo "Installing runtime gems..."
(
  cd "$APP_DIR"
  bundle config set --local path vendor/bundle
  bundle config set --local without "development test"
  bundle install
)

cp "$renderer" "$PAYLOAD_DIR/bin/plushie-renderer"
chmod +x "$PAYLOAD_DIR/bin/plushie-renderer"

dereference_payload_symlinks

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
archive_payload
payload_hash="$(hash_file "$DIST_DIR/payload.tar.zst")"
payload_size="$(file_size "$DIST_DIR/payload.tar.zst")"

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
