#!/usr/bin/env bash
# PreToolUse hook for Claude Drop. Rewrites foreign paths in Read.file_path
# and Bash.command to their local cached counterparts. Falls back to a
# synchronous fetch with a tight timeout when the path looks foreign but
# wasn't pre-fetched. Never blocks; on any uncertainty, allows as-is.

set -u

input=$(cat 2>/dev/null || true)
[ -n "$input" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)
[ -n "$session_id" ] || session_id="default"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"
. "$HERE/claude-drop-lib.sh" 2>/dev/null || exit 0

runtime_dir=$(cd_runtime_dir)
cache_file="$runtime_dir/session-cache-$session_id.json"

host=$(cd_resolve_host "$runtime_dir" "$session_id")

# rewrite_path <candidate> — echoes the local cached path or empty.
rewrite_path() {
    local cand="$1"
    [ -r "$cache_file" ] || { [ -n "$host" ] || return 0; }
    local mapped=""
    if [ -r "$cache_file" ]; then
        mapped=$(python3 - "$cache_file" "$cand" <<'PY' 2>/dev/null || true
import json, sys
try:
    cache = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
cand = sys.argv[2]
v = cache.get(cand)
if v:
    print(v)
PY
)
    fi
    if [ -n "$mapped" ]; then
        printf '%s' "$mapped"
        return 0
    fi
    # Synchronous fetch fallback for paths that look foreign but weren't pre-fetched.
    if [ -n "$host" ]; then
        case "$cand" in
            /Users/*|/home/*|/Volumes/*|/mnt/*|~/*)
                local fetch_bin="${CLAUDE_PLUGIN_ROOT}/bin/claude-drop-fetch"
                [ -x "$fetch_bin" ] || return 0
                local result
                result=$(CLAUDE_DROP_TIMEOUT=3 timeout 3 "$fetch_bin" "$host" "$cand" 2>/dev/null || true)
                [ -n "$result" ] || return 0
                mapped=$(python3 - "$result" "$cand" <<'PY' 2>/dev/null || true
import json, sys
try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)
r = data.get(sys.argv[2]) or {}
if r.get("status") == "ok" and r.get("local_path"):
    print(r["local_path"])
PY
)
                if [ -n "$mapped" ]; then
                    python3 - "$cache_file" "$cand" "$mapped" <<'PY' 2>/dev/null || true
import json, os, sys
path, cand, val = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    cache = json.load(open(path))
except Exception:
    cache = {}
cache[cand] = val
try:
    with open(path, "w") as f:
        json.dump(cache, f)
    os.chmod(path, 0o600)
except Exception:
    pass
PY
                    printf '%s' "$mapped"
                fi
                ;;
        esac
    fi
}

case "$tool" in
    Read)
        file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
        [ -n "$file_path" ] || exit 0
        new=$(rewrite_path "$file_path")
        if [ -n "$new" ] && [ "$new" != "$file_path" ]; then
            jq -n --arg fp "$new" '{
                hookSpecificOutput: {
                    hookEventName: "PreToolUse",
                    permissionDecision: "allow",
                    updatedInput: { file_path: $fp }
                }
            }'
        fi
        ;;
    Bash)
        command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
        [ -n "$command" ] || exit 0
        # Find foreign paths in the command and rewrite them.
        new_command=$(python3 - "$cache_file" "$command" 2>/dev/null <<'PY' || true
import json, os, re, sys
cache = {}
try:
    cache = json.load(open(sys.argv[1]))
except Exception:
    cache = {}
text = sys.argv[2]
if not cache:
    sys.stdout.write(text)
    sys.exit(0)
# Sort by length desc to replace longest paths first.
keys = sorted((k for k in cache if k), key=len, reverse=True)
for k in keys:
    if k in text:
        text = text.replace(k, cache[k])
sys.stdout.write(text)
PY
)
        if [ -n "$new_command" ] && [ "$new_command" != "$command" ]; then
            jq -n --arg cmd "$new_command" '{
                hookSpecificOutput: {
                    hookEventName: "PreToolUse",
                    permissionDecision: "allow",
                    updatedInput: { command: $cmd }
                }
            }'
        fi
        ;;
esac

exit 0
