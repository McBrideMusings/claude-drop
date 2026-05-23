#!/usr/bin/env bash
# Install the Claude Drop responder as a systemd user path+service (Linux).
# Derives paths from this script's own location so it works from any
# plugin cache directory.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
plugin_root="$(cd "$script_dir/.." && pwd)"
bin_dir="$plugin_root/bin"

dest_dir="$HOME/.config/systemd/user"

mkdir -p "$dest_dir"
mkdir -p "$HOME/.cache/claude-drop/inbox"
chmod 700 "$HOME/.cache/claude-drop"

sed -e "s|__HOME__|$HOME|g" -e "s|__BIN_DIR__|$bin_dir|g" \
    "$script_dir/claude-drop-responder.service" \
    > "$dest_dir/claude-drop-responder.service"

# .path uses systemd's %h, no substitution needed — copy verbatim.
cp "$script_dir/claude-drop-responder.path" "$dest_dir/claude-drop-responder.path"

if command -v loginctl >/dev/null 2>&1; then
    loginctl enable-linger "$(id -un)" 2>/dev/null || true
fi

systemctl --user daemon-reload
systemctl --user enable --now claude-drop-responder.path

echo "Enabled claude-drop-responder.path (fires claude-drop-responder.service on inbox change)."
echo "Bin:    $bin_dir/claude-drop-responder"
echo "Status: systemctl --user status claude-drop-responder.path"
echo "Logs:   journalctl --user -u claude-drop-responder -f"
