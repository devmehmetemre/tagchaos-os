#!/bin/sh
# CHA Icons kurulumu: /usr/share/icons/chaos altına kopyalar
set -eu
DEST="${1:-/}/usr/share/icons/chaos"
SRC="$(dirname "$0")"
mkdir -p "$DEST/48x48/places" "$DEST/48x48/apps" "$DEST/scalable/apps"
cp "$SRC/folder.svg" "$DEST/48x48/places/folder.svg"
cp "$SRC/terminal.svg" "$DEST/48x48/apps/terminal.svg"
cp "$SRC/chaos-logo.svg" "$DEST/scalable/apps/chaos-logo.svg"
cp "$SRC/chaos-logo.svg" "$DEST/scalable/apps/distributor-logo.svg"
echo "CHA Icons -> $DEST"
