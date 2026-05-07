# Claude Drop

Tailscale-backed file fetching across SSH boundaries. When Claude Code runs on
a remote machine over SSH and you reference a path on your local side, Drop
transparently copies the file across via Taildrop and rewrites the path
to a local cache.

See `docs/claude-drop-plan.md` for the design.

## Components

- `bin/claude-drop-init` — one-command setup (services + hooks).
- `bin/claude-drop-fetch` — UserPromptSubmit-side parallel fetcher.
- `bin/claude-drop-responder` — Source-side handler, fired on inbox change.
- `bin/claude-drop-receiver` — `tailscale file get --loop` wrapper.
- `bin/claude-drop-push` — Reverse-direction CLI (push artifact back).

## Install

Run on every tailnet machine you ssh into or out of:

    ~/.claude/claude-drop/bin/claude-drop-init

Detects the OS, installs the receiver and responder (launchd on macOS,
systemd user units on Linux), and patches `~/.claude/settings.json` to
wire the three hooks. Idempotent — safe to re-run.

Flags:

- `--dry-run` — show what would happen, change nothing
- `--no-services` — skip launchd/systemd setup
- `--no-hooks` — skip the settings.json patch

### Manual install (if you'd rather)

macOS:

    bash claude-drop/install/install-receiver-launchd.sh
    bash claude-drop/install/install-responder-launchd.sh

Linux:

    bash claude-drop/install/install-receiver-systemd.sh
    bash claude-drop/install/install-responder-systemd.sh

Then add to `~/.claude/settings.json` under `hooks`:

```json
"UserPromptSubmit": [
  {"matcher": "", "hooks": [{"type": "command", "command": "bash ~/.claude/hooks/user-prompt-claude-drop.sh"}]}
],
"PreToolUse": [
  {"matcher": "Read|Bash", "hooks": [{"type": "command", "command": "bash ~/.claude/hooks/pretool-claude-drop.sh"}]}
],
"SessionStart": [
  {"matcher": "", "hooks": [{"type": "command", "command": "bash ~/.claude/hooks/session-claude-drop-init.sh"}]}
]
```

## Test

From an SSH session into another tailnet host:

    echo "summarize /Users/$(whoami)/Desktop/test.txt" | bash ~/.claude/hooks/user-prompt-claude-drop.sh

The hook should emit `additionalContext` JSON describing the fetched file.
