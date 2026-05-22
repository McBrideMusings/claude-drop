# Claude Drop

Tailscale-backed file fetching across SSH boundaries for Claude Code. When
Claude Code runs on a remote machine over SSH and you reference a path on your
local (SSH-client) side, Claude Drop transparently copies the file across via
Taildrop and rewrites the path to a local cache. The remote `Read` / `Bash`
tools then "just work" against your local-side files.

This repository is a Claude Code plugin.

## Requirements

- Tailscale installed and signed in on both ends, same tailnet (Tailscale Mac
  app on macOS, `tailscaled` on Linux).
- `jq` and Python 3.11+ available on the remote side.
- One-time per machine: `sudo tailscale set --operator=$USER` so user-level
  `tailscale file cp` is permitted.

## Install via the marketplace

```
/plugin marketplace add McBrideMusings/claude-plugins
/plugin install claude-drop@mcbridemusings
```

After installing the plugin, you still need to bring the receiver/responder
services up once per machine. From a shell on each end:

```
"${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/marketplaces/mcbridemusings/claude-drop}/bin/claude-drop-init"
```

`claude-drop-init` is idempotent. It installs launchd LaunchAgents on macOS or
systemd user units on Linux, both of which run `claude-drop-receiver` (a
`tailscale file get --loop` wrapper) and trigger `claude-drop-responder` when a
request lands in the inbox.

Flags:

- `--dry-run` — show what would happen, change nothing
- `--no-services` — skip launchd/systemd setup
- `--no-hooks` — skip touching `settings.json` (plugin install handles its own
  hooks; pass this when running the script after plugin install)

## Architecture

```
SSH client (macOS)                         Remote (linux/macOS, in Claude session)
─────────────────────                      ──────────────────────────────────────────
claude-drop-receiver  ◄─── taildrop reply ─── claude-drop-responder ◄─── req-*.json
   (long-running                                  (one-shot, path-triggered)
    tailscale file get --loop)
                                           ▲
claude-drop-responder                      │
   (one-shot, path-triggered)              │
                                           hooks/user-prompt-claude-drop.sh
                                              calls bin/claude-drop-fetch
                                              when the prompt mentions a local-side path
```

The three plugin hooks:

- `SessionStart` — resolves `SSH_CLIENT` to a tailnet hostname once per session,
  caches under `$XDG_RUNTIME_DIR/claude-drop/`.
- `UserPromptSubmit` — scans the prompt for local-style absolute paths
  (`/Users/...`, `/home/...`, `/Volumes/...`, `/mnt/...`, `~/...`), kicks off
  parallel `claude-drop-fetch` calls, and emits an `additionalContext` block
  telling Claude where each fetched file landed.
- `PreToolUse` (Read, Bash) — rewrites any foreign path in tool input to its
  local cache equivalent. Falls back to a 3-second synchronous fetch if the
  path looks foreign but wasn't pre-fetched.

## Components

- `bin/claude-drop-init` — one-command setup (OS services). Run once per
  machine after installing the plugin.
- `bin/claude-drop-fetch` — UserPromptSubmit-side parallel fetcher; called from
  the plugin hooks via `${CLAUDE_PLUGIN_ROOT}/bin/claude-drop-fetch`.
- `bin/claude-drop-responder` — source-side handler, spawned per request.
- `bin/claude-drop-receiver` — `tailscale file get --loop` wrapper, runs as a
  long-lived user service.
- `bin/claude-drop-push` — reverse-direction CLI (push an artifact back).

## Configuration

Drop a `config.toml` at `~/.claude/claude-drop/config.toml` (or
`config.<hostname>.toml` for per-machine overrides) — see `config.example.toml`
for the schema. All fields are optional.

## Status

Early. The plugin loads and the hooks fire end-to-end on a linux → mac → linux
round trip. The OS-service install path (`claude-drop-init`) still expects a
stable bin location and needs to be re-run when the plugin is updated to a new
versioned cache directory. That rough edge will be sanded down in a follow-up.
