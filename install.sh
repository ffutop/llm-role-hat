#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
TARGET="$PREFIX/bin/hat"
HAT_DOWNLOAD_URL="${HAT_DOWNLOAD_URL:-https://hat.ffutop.com/bin/hat}"
TEMP_TARGET=""

cleanup() {
  [ -z "$TEMP_TARGET" ] || rm -f "$TEMP_TARGET"
}

trap cleanup EXIT

download() {
  if command -v curl >/dev/null 2>&1; then
    curl --fail --silent --show-error --location "$HAT_DOWNLOAD_URL" --output "$TEMP_TARGET"
  elif command -v wget >/dev/null 2>&1; then
    wget --quiet --output-document="$TEMP_TARGET" "$HAT_DOWNLOAD_URL"
  else
    printf 'hat installer: curl or wget is required to download hat.\n' >&2
    return 1
  fi
}

mkdir -p "$PREFIX/bin"
TEMP_TARGET="$(mktemp "$PREFIX/bin/.hat.XXXXXX")"
download
chmod 755 "$TEMP_TARGET"
mv -f "$TEMP_TARGET" "$TARGET"
TEMP_TARGET=""

printf 'Installed hat to %s\n' "$TARGET"
printf 'Ensure %s/bin is in your PATH. This installer did not modify any shell rc file.\n' "$PREFIX"
printf 'For completion: source <(hat completion bash)  # or zsh\n'
printf 'For @role shortcuts: hat shortcut install bash  # or zsh\n'
