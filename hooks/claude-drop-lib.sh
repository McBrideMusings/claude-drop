#!/usr/bin/env bash
# Shared helpers for Claude Drop hooks. Sourced, never executed directly.
# All functions are defensive: they never abort the caller and degrade to
# empty output on any failure.

# cd_runtime_dir — echoes the runtime dir, creating it 0700.
cd_runtime_dir() {
    local dir="${XDG_RUNTIME_DIR:-/tmp}/claude-drop"
    mkdir -p "$dir" 2>/dev/null || true
    chmod 700 "$dir" 2>/dev/null || true
    printf '%s' "$dir"
}

# cd_resolve_ip_to_host <client_ip> — echoes the tailnet short hostname for an
# IP, or empty. Requires tailscale + jq.
cd_resolve_ip_to_host() {
    local ip="$1"
    [ -n "$ip" ] || return 0
    command -v tailscale >/dev/null 2>&1 || return 0
    command -v jq >/dev/null 2>&1 || return 0
    tailscale status --json 2>/dev/null \
        | jq -r --arg ip "$ip" '
            ([.Self] + (.Peer | to_entries | map(.value)))
            | map(select(.TailscaleIPs and (.TailscaleIPs | index($ip))))
            | first
            | (.DNSName // "") | split(".") | .[0] // empty
        ' 2>/dev/null
}

# cd_resolve_host <runtime_dir> <session_id> — echoes the SSH-client host for
# this session, or empty. Resolution order:
#   1. per-session cached host file (fast path for any later hook this session)
#   2. SSH_CLIENT IP -> tailnet host (interactive SSH sessions; persists the
#      result to both the per-session file and the cross-session last-host file)
#   3. last-host fallback — for sessions with no SSH_CLIENT in their environment
#      (e.g. detached background-job sessions), reuse the most recently resolved
#      host and seed this session's per-session file so later hooks hit case 1.
cd_resolve_host() {
    local runtime_dir="$1" session_id="$2"
    local host_file="$runtime_dir/session-host-$session_id"
    local last_host_file="$runtime_dir/last-host"
    local host=""

    if [ -r "$host_file" ]; then
        host=$(cat "$host_file" 2>/dev/null || true)
    fi

    if [ -z "$host" ] && [ -n "${SSH_CLIENT:-}" ]; then
        host=$(cd_resolve_ip_to_host "${SSH_CLIENT%% *}")
        if [ -n "$host" ]; then
            { printf '%s' "$host" > "$host_file" && chmod 600 "$host_file"; } 2>/dev/null || true
            { printf '%s' "$host" > "$last_host_file" && chmod 600 "$last_host_file"; } 2>/dev/null || true
        fi
    fi

    if [ -z "$host" ] && [ -r "$last_host_file" ]; then
        host=$(cat "$last_host_file" 2>/dev/null || true)
        if [ -n "$host" ]; then
            { printf '%s' "$host" > "$host_file" && chmod 600 "$host_file"; } 2>/dev/null || true
        fi
    fi

    printf '%s' "$host"
}
