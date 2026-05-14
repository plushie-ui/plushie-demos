#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=package_lib.sh
source "$ROOT/scripts/package_lib.sh"

fail() {
  echo "package_lib_test: $*" >&2
  exit 1
}

with_tmpdir() {
  local tmp

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  "$@" "$tmp"
  trap - RETURN
  rm -rf "$tmp"
}

test_dereference_payload_symlinks() {
  local tmp="$1"
  local payload="$tmp/payload"
  local target="linux-x86_64"
  local symlink_target="unchanged"
  local link="unchanged"

  mkdir -p "$payload/app" "$tmp/source-dir/nested"
  printf 'hello\n' > "$tmp/source-file"
  printf 'inside\n' > "$tmp/source-dir/nested/file"
  ln -s ../../source-file "$payload/app/file-link"
  ln -s ../../source-dir "$payload/app/dir-link"

  dereference_payload_symlinks "$payload"

  [ "$target" = "linux-x86_64" ] || fail "dereference_payload_symlinks clobbered target"
  [ "$symlink_target" = "unchanged" ] || fail "dereference_payload_symlinks clobbered symlink_target"
  [ "$link" = "unchanged" ] || fail "dereference_payload_symlinks clobbered link"
  [ ! -L "$payload/app/file-link" ] || fail "file symlink was not dereferenced"
  [ ! -L "$payload/app/dir-link" ] || fail "directory symlink was not dereferenced"
  [ "$(cat "$payload/app/file-link")" = "hello" ] || fail "file symlink content changed"
  [ "$(cat "$payload/app/dir-link/nested/file")" = "inside" ] || fail "directory symlink content changed"
  validate_payload_archive_inputs "$payload" || fail "dereferenced payload failed validation"
}

test_reject_symlink_payload() {
  local tmp="$1"
  local payload="$tmp/payload"

  mkdir -p "$payload"
  printf 'hello\n' > "$tmp/source"
  ln -s ../source "$payload/link"

  if validate_payload_archive_inputs "$payload" 2>"$tmp/error"; then
    fail "symlink payload passed validation"
  fi

  grep -q "unsupported symlink" "$tmp/error" || fail "symlink error was not reported"
}

test_reject_hard_link_payload() {
  local tmp="$1"
  local payload="$tmp/payload"

  mkdir -p "$payload"
  printf 'hello\n' > "$payload/source"
  ln "$payload/source" "$payload/hard-link"

  if validate_payload_archive_inputs "$payload" 2>"$tmp/error"; then
    fail "hard-linked payload passed validation"
  fi

  grep -q "unsupported hard-linked file" "$tmp/error" || fail "hard link error was not reported"
}

test_reject_special_file_payload() {
  local tmp="$1"
  local payload="$tmp/payload"

  mkdir -p "$payload"
  mkfifo "$payload/fifo"

  if validate_payload_archive_inputs "$payload" 2>"$tmp/error"; then
    fail "special-file payload passed validation"
  fi

  grep -q "unsupported special file" "$tmp/error" || fail "special file error was not reported"
}

with_tmpdir test_dereference_payload_symlinks
with_tmpdir test_reject_symlink_payload
with_tmpdir test_reject_hard_link_payload
with_tmpdir test_reject_special_file_payload

echo "package_lib_test: ok"
