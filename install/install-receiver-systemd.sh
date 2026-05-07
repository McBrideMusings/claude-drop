#!/usr/bin/env bash
# Install the Claude Drop receiver as a systemd user unit (Linux).
set -euo pipefail

src="$HOME/.claude/claude-drop/install/claude-drop-receiver.service"
dest_dir="$HOME/.config/systemd/user"
dest="$dest_dir/claude-drop-receiver.service"

mkdir -p "$dest_dir"
mkdir -p "$HOME/.cache/claude-drop/inbox"
chmod 700 "$HOME/.cache/claude-drop"

cp "$src" "$dest"

# loginctl enable-linger so the user service runs without an active session.
if command -v loginctl >/dev/null 2>&1; then
    loginctl enable-linger "$(id -un)" 2>/dev/null || true
fi

systemctl --user daemon-reload
systemctl --user enable --now claude-drop-receiver.service

echo "Enabled claude-drop-receiver.service."
echo "Status: systemctl --user status claude-drop-receiver"
echo "Logs:   journalctl --user -u claude-drop-receiver -f"
