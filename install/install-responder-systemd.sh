#!/usr/bin/env bash
# Install the Claude Drop responder as a systemd user path+service (Linux).
set -euo pipefail

src_dir="$HOME/.claude/claude-drop/install"
dest_dir="$HOME/.config/systemd/user"

mkdir -p "$dest_dir"
mkdir -p "$HOME/.cache/claude-drop/inbox"
chmod 700 "$HOME/.cache/claude-drop"

cp "$src_dir/claude-drop-responder.path" "$dest_dir/claude-drop-responder.path"
cp "$src_dir/claude-drop-responder.service" "$dest_dir/claude-drop-responder.service"

if command -v loginctl >/dev/null 2>&1; then
    loginctl enable-linger "$(id -un)" 2>/dev/null || true
fi

systemctl --user daemon-reload
systemctl --user enable --now claude-drop-responder.path

echo "Enabled claude-drop-responder.path (fires claude-drop-responder.service on inbox change)."
echo "Status: systemctl --user status claude-drop-responder.path"
echo "Logs:   journalctl --user -u claude-drop-responder -f"
