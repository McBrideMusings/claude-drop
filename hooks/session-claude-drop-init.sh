#!/usr/bin/env bash
# SessionStart hook for Claude Drop. Resolves SSH_CLIENT to a tailnet host
# once per session and caches the result for the UserPromptSubmit hook.
# Always exits 0 so a hook bug never blocks session start.

set -u

input=$(cat 2>/dev/null || true)

session_id=""
if [ -n "$input" ] && command -v jq >/dev/null 2>&1; then
    session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)
fi
[ -n "$session_id" ] || session_id="default"

[ -n "${SSH_CLIENT:-}" ] || exit 0

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/claude-drop"
mkdir -p "$runtime_dir" 2>/dev/null || true
chmod 700 "$runtime_dir" 2>/dev/null || true

client_ip="${SSH_CLIENT%% *}"
[ -n "$client_ip" ] || exit 0

command -v tailscale >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

host=$(tailscale status --json 2>/dev/null \
    | jq -r --arg ip "$client_ip" '
        ([.Self] + (.Peer | to_entries | map(.value)))
        | map(select(.TailscaleIPs and (.TailscaleIPs | index($ip))))
        | first
        | (.DNSName // "") | split(".") | .[0] // empty
    ' 2>/dev/null)

[ -n "$host" ] || exit 0

printf '%s' "$host" > "$runtime_dir/session-host-$session_id"
chmod 600 "$runtime_dir/session-host-$session_id" 2>/dev/null || true

exit 0
