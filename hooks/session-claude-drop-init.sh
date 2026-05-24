#!/usr/bin/env bash
# SessionStart hook for Claude Drop. Resolves the SSH-client host once per
# session and caches it for the UserPromptSubmit and PreToolUse hooks.
# For detached sessions with no SSH_CLIENT (e.g. background jobs) this seeds
# the per-session host from the cross-session last-host fallback.
# Always exits 0 so a hook bug never blocks session start.

set -u

input=$(cat 2>/dev/null || true)

session_id=""
if [ -n "$input" ] && command -v jq >/dev/null 2>&1; then
    session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)
fi
[ -n "$session_id" ] || session_id="default"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"
. "$HERE/claude-drop-lib.sh" 2>/dev/null || exit 0

runtime_dir=$(cd_runtime_dir)
cd_resolve_host "$runtime_dir" "$session_id" >/dev/null 2>&1 || true

exit 0
