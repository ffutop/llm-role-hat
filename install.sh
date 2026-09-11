#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
TARGET="$PREFIX/bin/hat"

mkdir -p "$PREFIX/bin"
cp "$SOURCE_DIR/bin/hat" "$TARGET"
chmod 755 "$TARGET"

printf 'Installed hat to %s\n' "$TARGET"
printf 'Ensure %s/bin is in your PATH. This installer did not modify any shell rc file.\n' "$PREFIX"
printf 'For completion: source <(hat completion bash)  # or zsh\n'
printf 'For @role shortcuts: hat shortcut install bash  # or zsh\n'
