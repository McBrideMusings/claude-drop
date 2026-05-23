---
description: Diagnose claude-drop health on this machine. Reports service state, what bin paths the daemons point at, whether any installations are stale (pointing at old plugin versions or the pre-plugin in-tree install), and tailscale/operator status. Suggests cleanup commands but does not run them.
---

# /claude-drop:doctor

Run a structured health check and tell the user what — if anything — needs
attention.

## Instructions

1. Run the doctor script with the Bash tool:

   ```
   "${CLAUDE_PLUGIN_ROOT}/bin/claude-drop-doctor"
   ```

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
