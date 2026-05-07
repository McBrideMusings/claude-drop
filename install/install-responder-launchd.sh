#!/usr/bin/env bash
# Install the Claude Drop responder as a launchd LaunchAgent with WatchPaths (macOS).
set -euo pipefail

label="com.piercemcbride.claude-drop.responder"
src="$HOME/.claude/claude-drop/install/${label}.plist"
dest_dir="$HOME/Library/LaunchAgents"
dest="$dest_dir/${label}.plist"

mkdir -p "$dest_dir"
mkdir -p "$HOME/.cache/claude-drop/inbox"
chmod 700 "$HOME/.cache/claude-drop"

sed "s|__HOME__|$HOME|g" "$src" > "$dest"
chmod 644 "$dest"

launchctl unload "$dest" 2>/dev/null || true
launchctl load "$dest"

echo "Loaded $label."
echo "Logs: ~/.cache/claude-drop/responder{,.err}.log"
