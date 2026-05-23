#!/usr/bin/env bash
# Install the Claude Drop responder as a launchd LaunchAgent with WatchPaths (macOS).
# Derives paths from this script's own location so it works from any
# plugin cache directory.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
plugin_root="$(cd "$script_dir/.." && pwd)"
bin_dir="$plugin_root/bin"

label="com.piercemcbride.claude-drop.responder"
src="$script_dir/${label}.plist"
dest_dir="$HOME/Library/LaunchAgents"
dest="$dest_dir/${label}.plist"

mkdir -p "$dest_dir"
mkdir -p "$HOME/.cache/claude-drop/inbox"
chmod 700 "$HOME/.cache/claude-drop"

sed -e "s|__HOME__|$HOME|g" -e "s|__BIN_DIR__|$bin_dir|g" "$src" > "$dest"
chmod 644 "$dest"

launchctl unload "$dest" 2>/dev/null || true
launchctl load "$dest"

echo "Loaded $label."
echo "Bin:  $bin_dir/claude-drop-responder"
echo "Logs: ~/.cache/claude-drop/responder{,.err}.log"
