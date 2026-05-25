---
description: Install or refresh claude-drop's launchd/systemd user services for the currently-installed plugin version. Run once per machine after installing the plugin, and again any time the plugin updates.
---

# /claude-drop:init

Install (or refresh) the claude-drop receiver and responder user services
on this machine, pointing at the binaries inside the **currently active
plugin version** (`${CLAUDE_PLUGIN_ROOT}/bin/`).

This must be re-run any time the plugin updates, because each plugin
version lives in its own cache directory and the service definitions bake
in absolute paths.

## Instructions

1. Run **exactly** this command with the Bash tool — do not substitute a
   concrete path or guess a version; let the shell resolve it:

   ```
   CONF="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; D="$CONF/plugins/cache/mcbridemusings/claude-drop"; VER="$(ls "$D" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"; [ -n "$VER" ] && "$D/$VER/bin/claude-drop-init" --no-hooks || echo "claude-drop not found under $D"
   ```

   This finds the latest installed plugin version under the cache and runs
   its init binary, so it stays correct across OSes and plugin updates
   without relying on `${CLAUDE_PLUGIN_ROOT}` (which is not set in the shell).

   `--no-hooks` is required — the plugin handles hook registration on its
   own; the script should never touch `~/.claude/settings.json` here.

2. Report the script's output verbatim to the user, then provide a one-line
   summary of what happened.

3. If prerequisites are missing (`tailscale`, `jq`, `python3.11+`), state
   what to install and stop. Do not attempt to install dependencies.

4. If `tailscale set --operator=$USER` hasn't been run yet on this
   machine, the install will succeed but `tailscale file cp` will fail
   later. Tell the user to run that command once with `sudo`.

5. Suggest running `/claude-drop:doctor` to verify the install worked.
