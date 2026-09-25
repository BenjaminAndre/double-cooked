#!/usr/bin/env bash
# Downloads the third-party assets and addons that are git-ignored (see readme.md).
# Used by CI, and works locally from Git Bash too: run it from anywhere,
# it installs into the project root. Existing folders are left untouched,
# so delete one to force a re-download.
#
# Versions are pinned so CI builds are reproducible. Bump them here.
set -euo pipefail

KENNEY_URL="https://kenney.nl/media/pages/assets/prototype-kit/4d3b7073ed-1724832076/kenney_prototype-kit.zip"
DEBUG_DRAW_3D_URL="https://github.com/DmitriySalnikov/godot_debug_draw_3d/releases/download/1.7.3/debug-draw-3d_1.7.3.zip"
TUBE_URL="https://github.com/jonandrewdavis/tube/archive/0370fa40dd4988b0bff8ebee15225761c327208d.zip"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# fetch <url> <name>: downloads and extracts into $TMP/<name>
fetch() {
    echo "Downloading $2..."
    curl -fsSL "$1" -o "$TMP/$2.zip"
    unzip -q "$TMP/$2.zip" -d "$TMP/$2"
}

# Kenney zips have no single top folder, so locate the one holding Models/.
if [ ! -d "$ROOT/assets/kenney_prototype-kit" ]; then
    fetch "$KENNEY_URL" kenney
    src="$(dirname "$(find "$TMP/kenney" -type d -name Models | head -n 1)")"
    mkdir -p "$ROOT/assets"
    mv "$src" "$ROOT/assets/kenney_prototype-kit"
fi

# Addon archives nest their folder at different depths, so find it by name.
install_addon() {
    local url="$1" name="$2"
    [ -d "$ROOT/addons/$name" ] && return
    fetch "$url" "$name"
    local src
    src="$(find "$TMP/$name" -type d -path "*/addons/$name" | head -n 1)"
    [ -n "$src" ] || { echo "addons/$name not found in $url" >&2; exit 1; }
    mkdir -p "$ROOT/addons"
    mv "$src" "$ROOT/addons/$name"
}

install_addon "$DEBUG_DRAW_3D_URL" debug_draw_3d
install_addon "$TUBE_URL" tube

# godot-extension-webrtc is not fetched: browsers provide WebRTC natively, so
# only desktop builds need it.

echo "Dependencies ready."
