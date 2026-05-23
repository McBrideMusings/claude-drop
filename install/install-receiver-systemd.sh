#!/usr/bin/env bash
# Install the Claude Drop receiver as a systemd user unit (Linux).
# Derives paths from this script's own location so it works from any
# plugin cache directory.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
plugin_root="$(cd "$script_dir/.." && pwd)"
bin_dir="$plugin_root/bin"

src="$script_dir/claude-drop-receiver.service"
dest_dir="$HOME/.config/systemd/user"
dest="$dest_dir/claude-drop-receiver.service"

mkdir -p "$dest_dir"
mkdir -p "$HOME/.cache/claude-drop/inbox"
chmod 700 "$HOME/.cache/claude-drop"

sed -e "s|__HOME__|$HOME|g" -e "s|__BIN_DIR__|$bin_dir|g" "$src" > "$dest"

if command -v loginctl >/dev/null 2>&1; then
    loginctl enable-linger "$(id -un)" 2>/dev/null || true
fi

systemctl --user daemon-reload
systemctl --user enable --now claude-drop-receiver.service

echo "Enabled claude-drop-receiver.service."
echo "Bin:    $bin_dir/claude-drop-receiver"
echo "Status: systemctl --user status claude-drop-receiver"
echo "Logs:   journalctl --user -u claude-drop-receiver -f"
