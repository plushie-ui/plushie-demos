#!/usr/bin/env bash

normalize_package_target() {
  local os="$1"
  local arch="$2"

  os="$(printf '%s' "$os" | tr '[:upper:]' '[:lower:]')"
  case "$os" in
    linux*) os="linux" ;;
    darwin*) os="darwin" ;;
    win32|windows|msys*|mingw*|cygwin*) os="windows" ;;
    *)
      echo "Unsupported package OS: $os" >&2
      return 1
      ;;
  esac

  arch="$(printf '%s' "$arch" | tr '[:upper:]' '[:lower:]')"
  case "$arch" in
    amd64|x64|x86_64) arch="x86_64" ;;
    arm64|aarch64) arch="aarch64" ;;
    *)
      echo "Unsupported package architecture: $arch" >&2
      return 1
      ;;
  esac

  printf '%s-%s\n' "$os" "$arch"
}

package_target() {
  normalize_package_target "$(uname -s)" "$(uname -m)"
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

hash_file() {
  sha256_file "$@"
}

file_size() {
  wc -c < "$1" | tr -d '[:space:]'
}

validate_payload_archive_inputs() {
  local payload_dir="$1"
  local invalid

  invalid="$(find "$payload_dir" -type l -print -quit)"
  if [ -n "$invalid" ]; then
    echo "Payload contains unsupported symlink: ${invalid#$payload_dir/}" >&2
    return 1
  fi

  invalid="$(find "$payload_dir" \( -type p -o -type s -o -type b -o -type c \) -print -quit)"
  if [ -n "$invalid" ]; then
    echo "Payload contains unsupported special file: ${invalid#$payload_dir/}" >&2
    return 1
  fi

  invalid="$(find "$payload_dir" -type f -links +1 -print -quit)"
  if [ -n "$invalid" ]; then
    echo "Payload contains unsupported hard-linked file: ${invalid#$payload_dir/}" >&2
    return 1
  fi
}

dereference_payload_symlinks() {
  local payload_dir="$1"
  local link
  local symlink_target
  local tmp

  while IFS= read -r -d '' link; do
    symlink_target="$(readlink "$link")"
    case "$symlink_target" in
      /*) ;;
      *) symlink_target="$(cd "$(dirname "$link")" && pwd -P)/$symlink_target" ;;
    esac
    tmp="$link.deref.$$"

    cp -aL "$symlink_target" "$tmp"
    rm "$link"
    mv "$tmp" "$link"
  done < <(find "$payload_dir" -type l -print0)
}

archive_tar_command() {
  if tar --version 2>/dev/null | grep -q 'GNU tar'; then
    printf 'tar\n'
  elif command -v gtar >/dev/null 2>&1; then
    printf 'gtar\n'
  else
    printf 'tar\n'
  fi
}

archive_tar_supports_gnu_flags() {
  [ "$(archive_tar_command)" != "tar" ] || tar --version 2>/dev/null | grep -q 'GNU tar'
}

archive_payload() {
  local payload_dir="$1"
  local archive_path="$2"
  local tar_bin

  validate_payload_archive_inputs "$payload_dir" || return
  tar_bin="$(archive_tar_command)"

  if archive_tar_supports_gnu_flags && "$tar_bin" --help 2>/dev/null | grep -q -- '--zstd'; then
    "$tar_bin" -C "$payload_dir" --sort=name --mtime='UTC 1970-01-01' \
      --owner=0 --group=0 --numeric-owner --zstd -cf "$archive_path" .
  elif archive_tar_supports_gnu_flags; then
    if ! command -v zstd >/dev/null 2>&1; then
      echo "Missing required command: zstd" >&2
      return 1
    fi

    "$tar_bin" -C "$payload_dir" --sort=name --mtime='UTC 1970-01-01' \
      --owner=0 --group=0 --numeric-owner -cf - . | zstd -q -o "$archive_path"
  else
    echo "GNU tar or gtar is required for deterministic payload archives." >&2
    return 1
  fi
}
