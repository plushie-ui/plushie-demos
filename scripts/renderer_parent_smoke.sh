#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE_TIMEOUT="${SMOKE_TIMEOUT:-10s}"
SMOKE_LANGUAGES="${SMOKE_LANGUAGES:-}"

renderer="${PLUSHIE_RENDERER_BINARY:-${PLUSHIE_BINARY_PATH:-}}"

if [ -z "$renderer" ]; then
  if command -v plushie-renderer >/dev/null 2>&1; then
    renderer="$(command -v plushie-renderer)"
  elif command -v plushie >/dev/null 2>&1; then
    renderer="$(command -v plushie)"
  else
    echo "No renderer binary found. Set PLUSHIE_RENDERER_BINARY or PLUSHIE_BINARY_PATH." >&2
    exit 1
  fi
fi

if ! command -v timeout >/dev/null 2>&1; then
  echo "The renderer-parent smoke needs the timeout command." >&2
  exit 1
fi

should_run() {
  local language="$1"

  if [ -z "$SMOKE_LANGUAGES" ]; then
    return 0
  fi

  case " $SMOKE_LANGUAGES " in
    *" $language "*) return 0 ;;
    *) return 1 ;;
  esac
}

run_case() {
  local language="$1"
  local mode="$2"
  local cwd="$3"
  local log
  local status
  shift 3

  if ! should_run "$language"; then
    return 0
  fi

  log="$(mktemp)"
  echo "==> $language ($mode)"

  set +e
  if [ "$mode" = "listen" ]; then
    (
      cd "$ROOT/$cwd"
      timeout --kill-after=2s "$SMOKE_TIMEOUT" "$renderer" --mock --listen "$@"
    ) >"$log" 2>&1
    status=$?
  else
    (
      cd "$ROOT/$cwd"
      timeout --kill-after=2s "$SMOKE_TIMEOUT" "$renderer" --mock "$@"
    ) >"$log" 2>&1
    status=$?
  fi
  set -e

  case "$status" in
    0)
      echo "ok: exited cleanly"
      ;;
    124|137)
      echo "ok: stayed alive until timeout"
      ;;
    *)
      echo "failed: exit status $status" >&2
      sed -n '1,120p' "$log" >&2
      rm -f "$log"
      return "$status"
      ;;
  esac

  rm -f "$log"
}

missing_case() {
  local language="$1"
  local reason="$2"

  if should_run "$language"; then
    echo "skip: $language - $reason"
  fi
}

run_case elixir listen "elixir/collab" \
  --exec-bin mix \
  --exec-arg plushie.connect \
  --exec-arg Collab

run_case gleam listen "gleam/collab" \
  --exec-bin gleam \
  --exec-arg run \
  --exec-arg -m \
  --exec-arg demo/connect

run_case python listen "python/collab" \
  --exec-bin python \
  --exec-arg -m \
  --exec-arg plushie \
  --exec-arg connect \
  --exec-arg collab_demo.collab:Collab

run_case typescript listen "typescript/collab" \
  --exec-bin npx \
  --exec-arg plushie \
  --exec-arg connect \
  --exec-arg src/collab.tsx

run_case ruby stdio "ruby/collab" \
  --exec-bin bundle \
  --exec-arg exec \
  --exec-arg ruby \
  --exec-arg bin/connect
missing_case rust "no renderer-parent connect command is exposed by the Rust demo"
