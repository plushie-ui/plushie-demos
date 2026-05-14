#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_PLUSHIE_RUBY_DIR="$(cd "$PROJECT_DIR/../../../plushie-ruby" 2>/dev/null && pwd || true)"
PLUSHIE_RUBY_DIR="${PLUSHIE_RUBY_DIR:-$DEFAULT_PLUSHIE_RUBY_DIR}"

cd "$PROJECT_DIR"

bundle check || bundle install

cmd=(bundle exec ruby)
args=(
  --app-id dev.plushie.demos.ruby.notes
  --app-name "Ruby Notes"
  --app-version 0.1.0
  --project-dir "$PROJECT_DIR"
  --output "$PROJECT_DIR/dist"
  --entrypoint bin/connect
  --renderer-kind stock
  --renderer-source local-resolve
)

if [ -n "$PLUSHIE_RUBY_DIR" ] && [ -d "$PLUSHIE_RUBY_DIR/lib/plushie" ]; then
  cmd+=("-I$PLUSHIE_RUBY_DIR/lib")
  args+=(--sdk-source-path "$PLUSHIE_RUBY_DIR")
fi

"${cmd[@]}" -rplushie/package -e 'Plushie::Package.run_cli(ARGV)' -- "${args[@]}"
