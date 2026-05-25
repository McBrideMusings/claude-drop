---
description: Diagnose claude-drop health on this machine. Reports service state, what bin paths the daemons point at, whether any installations are stale (pointing at old plugin versions or the pre-plugin in-tree install), and tailscale/operator status. Suggests cleanup commands but does not run them.
---

# /claude-drop:doctor

Run a structured health check and tell the user what — if anything — needs
attention.

## Instructions

1. Run **exactly** this command with the Bash tool — do not substitute a
   concrete path or guess a version; let the shell resolve it:

   ```
   CONF="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; D="$CONF/plugins/cache/mcbridemusings/claude-drop"; VER="$(ls "$D" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"; [ -n "$VER" ] && "$D/$VER/bin/claude-drop-doctor" || echo "claude-drop not found under $D"
   ```

   This finds the latest installed plugin version under the cache and runs
   its doctor binary, so it stays correct across OSes and plugin updates
   without relying on `${CLAUDE_PLUGIN_ROOT}` (which is not set in the shell).

2. Parse the output (free-form text grouped into sections). Summarize the
   user-visible state as a short checklist:

   - Tailscale daemon reachable / not
   - `tailscale set --operator=$USER` set / not (and to whom)
   - Receiver inbox dir present / missing
   - For each installed service: pointing at *this* plugin version,
     pointing at an *old* plugin version, or pointing at the deprecated
     in-tree path (`~/.claude/claude-drop/`)
   - Whether the old in-tree install directory `~/.claude/claude-drop/`
     still exists

3. **If everything looks healthy** (services pointing at the current plugin
   root, tailscale and operator OK), say so in one sentence and stop.

4. **If cleanup is needed** — stale services, leftover in-tree install,
   missing operator — show the user the exact shell commands to fix it,
   one per finding. Do not run any cleanup commands without explicit
   per-command confirmation from the user; just print them.

   Common cleanup commands to suggest when applicable:

   - macOS, drop a stale launchd job:
     ```
     launchctl unload ~/Library/LaunchAgents/com.piercemcbride.claude-drop.<name>.plist
     rm ~/Library/LaunchAgents/com.piercemcbride.claude-drop.<name>.plist
     ```

   - Linux, drop a stale systemd user unit:
     ```
     systemctl --user disable --now claude-drop-<name>.service
     rm ~/.config/systemd/user/claude-drop-<name>.service
     systemctl --user daemon-reload
     ```

   - Remove the old in-tree install:
     ```
     rm -rf ~/.claude/claude-drop
     ```

   - After cleanup, re-install with: `/claude-drop:init`

5. If services are running on the *current* plugin version but daemons
   aren't actually working, suggest `/claude-drop:init` to refresh.
