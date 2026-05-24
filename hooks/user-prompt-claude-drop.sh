#!/usr/bin/env bash
# UserPromptSubmit hook for Claude Drop.
# Scans the prompt for absolute path candidates that live on the SSH client side,
# fetches them via Taildrop, and emits additionalContext mapping each to its
# local cache path. Always exits 0; never blocks.

set -u

input=$(cat 2>/dev/null || true)
[ -n "$input" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null || true)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)
[ -n "$session_id" ] || session_id="default"
[ -n "$prompt" ] || exit 0

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"
. "$HERE/claude-drop-lib.sh" 2>/dev/null || exit 0

runtime_dir=$(cd_runtime_dir)
host=$(cd_resolve_host "$runtime_dir" "$session_id")
[ -n "$host" ] || exit 0

candidates=$(python3 - "$prompt" <<'PY' 2>/dev/null
import re, sys
prompt = sys.argv[1]
# A path with spaces pasted into a terminal becomes "Foo\ Bar" and may wrap as
# "Foo\<newline>Bar". Join the continuation so the path stays on one line.
prompt = prompt.replace("\\\n", " ")
seen = set()
out = []
path_re = re.compile(r"(?:^|[\s`'\"(\[{])((?:/Users|/home|/Volumes|/mnt|~)/[^\n]*)")
for m in path_re.finditer(prompt):
    cand = m.group(1).rstrip()
    cand = cand.rstrip(".,;:!?'\")]}")
    # Unescape shell escapes ("\ " -> " ") so the candidate is a real path; the
    # responder's prefix back-off trims any trailing words after it.
    cand = re.sub(r"\\(.)", r"\1", cand)
    if cand and cand not in seen:
        seen.add(cand)
        out.append(cand)
tokens = ("latest-screenshot", "clipboard-text", "clipboard-image", "select-file")
for t in tokens:
    if re.search(r"(?:^|[\s`'\"(\[{])" + re.escape(t) + r"(?:$|[\s`'\"|.,;:!?)\]}])", prompt):
        if t not in seen:
            seen.add(t)
            out.append(t)
for c in out:
    print(c)
PY
)

[ -n "$candidates" ] || exit 0

mapfile -t cand_arr <<< "$candidates"
[ "${#cand_arr[@]}" -gt 0 ] || exit 0

fetch_bin="${CLAUDE_PLUGIN_ROOT}/bin/claude-drop-fetch"
[ -x "$fetch_bin" ] || exit 0

result=$("$fetch_bin" "$host" "${cand_arr[@]}" 2>/dev/null || true)
[ -n "$result" ] || exit 0

cache_file="$runtime_dir/session-cache-$session_id.json"

context=$(python3 - "$result" "$host" "$cache_file" <<'PY' 2>/dev/null
import json, sys, os
host = sys.argv[2]
cache_file = sys.argv[3]
try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)

cache = {}
if os.path.exists(cache_file):
    try:
        cache = json.loads(open(cache_file).read())
    except Exception:
        cache = {}

lines = []
for cand, r in data.items():
    status = r.get("status")
    if status == "ok":
        lp = r.get("local_path")
        rp = r.get("resolved_path") or cand
        kind = r.get("kind", "file")
        cache[cand] = lp
        if rp != cand:
            cache[rp] = lp
        if kind == "dir":
            lines.append(f"`{cand}` is a directory on {host}; it was unzipped to `{lp}`. Use that local path.")
        else:
            lines.append(f"`{cand}` was fetched from {host} to `{lp}`. Use the local path; do not try to read the original path.")
    elif status == "denied":
        lines.append(f"`{cand}` on {host} is in the deny list and was not fetched.")
    elif status == "not_found":
        lines.append(f"`{cand}` on {host} does not resolve to any existing path (no valid prefix matched).")
    elif status == "tree_only":
        size = r.get("raw_size_bytes")
        tree = r.get("tree") or []
        listing = "\n".join(f"  - {e['path']} ({e['size']} bytes)" for e in tree[:200])
        more = "" if len(tree) <= 200 else f"\n  ... ({len(tree) - 200} more)"
        lines.append(
            f"`{cand}` on {host} is a directory of {size} bytes raw — over the size limit. "
            f"Tree listing follows; reference specific files in the next prompt to fetch them.\n{listing}{more}"
        )
    elif status == "too_large":
        lines.append(f"`{cand}` on {host} ({r.get('size')} bytes) exceeds max_raw_bytes; not fetched.")
    else:
        err = r.get("error") or "unknown error"
        lines.append(f"`{cand}` on {host} could not be fetched: {err}.")

if cache:
    try:
        with open(cache_file, "w") as f:
            json.dump(cache, f)
        os.chmod(cache_file, 0o600)
    except Exception:
        pass

if lines:
    print("Claude Drop fetched the following from your local machine:\n\n" + "\n".join(lines))
PY
)

[ -n "$context" ] || exit 0

jq -n --arg ctx "$context" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
exit 0
