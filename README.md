# Fizze Assistant

`Fizze Assistant` is a Swift command-line Discord bot for a single server. It connects to Discord over the Gateway for realtime events and uses the Discord HTTP API for commands, messages, role assignment, and audit-log lookups.

## What It Does

- Welcomes new members in a configured channel
- Announces member departures in a configured channel
- Distinguishes voluntary leaves from kicks and bans when Discord data allows it
- Auto-assigns a configured member role on join
- Provides staff slash commands for `/say`, `/warn`, `/warns`, `/clear-warning`, and `/clear-warnings`
- Sends exact-match “iconic” auto-replies for configured trigger phrases
- Stores warning history in SQLite and keeps other server state in Discord

## Why This Shape

This bot is intentionally small. It avoids unnecessary wrappers and service layers so it stays understandable and easy to run over SSH on a Mac mini.

No inbound tunnel is required. The bot uses Discord’s outbound Gateway connection and normal outbound HTTPS requests.

## Requirements

- Swift 6.2 or newer
- A Discord application and bot token
- The bot installed in the target server
- Developer Portal privileged intents enabled:
  - Server Members Intent
  - Message Content Intent

## Required Discord Permissions

- `View Channel`
- `Send Messages`
- `Manage Roles`
- `View Audit Log`

The bot’s highest role must also be above the default member role it assigns.

## Configuration

You can configure the bot with either:

- environment variables
- a JSON config file passed with `--config`

Environment variables override file values.

Tracked example config: [fizze-assistant.example.json](/Users/galew/Workspace/fizze-assistant/fizze-assistant.example.json)

## Commands

Build and run locally:

```bash
swift build
swift run fizze-assistant check --config fizze-assistant.local.json
swift run fizze-assistant register-commands --config fizze-assistant.local.json
swift run fizze-assistant run --config fizze-assistant.local.json
```

Build a release binary for the Mac mini:

```bash
swift build -c release
.build/release/fizze-assistant check --config fizze-assistant.local.json
.build/release/fizze-assistant register-commands --config fizze-assistant.local.json
.build/release/fizze-assistant run --config fizze-assistant.local.json
```

## SSH-Friendly Startup

One simple pattern is:

```bash
nohup .build/release/fizze-assistant run --config /path/to/fizze-assistant.local.json > fizze-assistant.log 2>&1 &
```

That keeps the process easy to start over SSH without committing to a larger deployment setup first.

## Notes

- `check` prints a setup report and surfaces blocking permission issues.
- `register-commands` installs guild-scoped slash commands for fast iteration.
- Warning history is stored locally in SQLite at the configured database path.
- Discord-owned state like members, roles, channels, and moderation context stays in Discord.
