# Fizze Assistant

`Fizze Assistant` is a one-off Swift command-line Discord bot for some friends in a single Discord server: `https://discord.gg/2kz68FvyJg`. It connects to Discord over the Gateway for realtime events and uses the Discord HTTP API for commands, messages, role assignment, and audit-log lookups.

## What It Does

- Welcomes new members in a configured channel
- Announces member departures in a configured channel
- Distinguishes voluntary leaves from kicks and bans when Discord data allows it
- Auto-assigns a configured member role on join
- Provides staff slash commands for `/say`, `/warn`, `/warns`, `/clear-warning`, and `/clear-warnings`
- Provides config-owner slash commands under `/config` for safe runtime config changes
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

## Developer Portal Setup

1. Create a new Discord application and bot in the Developer Portal.
2. Copy the Application ID into your local config file.
3. Keep the bot token local-only by exporting `DISCORD_BOT_TOKEN` in your shell environment instead of writing it into tracked files.
4. Enable these privileged intents for the bot:
   - `Server Members Intent`
   - `Message Content Intent`
5. Install the bot with scopes `bot` and `applications.commands`.
6. After the bot is installed in the target server, place the bot role above the default member role it should assign.
7. If you want to keep this truly private to the friends' server, consider disabling `Public Bot` after installation.

## Required Discord Permissions

- `View Channel`
- `Send Messages`
- `Manage Roles`
- `View Audit Log`

The bot’s highest role must also be above the default member role it assigns.

The permission integer used by this project is `268438656`.

Install URL template:

```text
https://discord.com/oauth2/authorize?client_id=YOUR_APPLICATION_ID&scope=bot%20applications.commands&permissions=268438656
```

## Configuration

The bot uses three local pieces of configuration:

- environment variables for secrets
- a local install config file passed with `--config`
- a separate local runtime config file that the bot can update safely from Discord

`DISCORD_BOT_TOKEN` stays environment-only and is never editable from Discord.

Tracked install config example: [fizze-assistant.example.json](/Users/galew/Workspace/fizze-assistant/fizze-assistant.example.json)

Tracked runtime config example: [fizze-assistant.runtime.example.json](/Users/galew/Workspace/fizze-assistant/fizze-assistant.runtime.example.json)

Local setup example:

```bash
cp fizze-assistant.example.json fizze-assistant.local.json
mkdir -p .data
cp fizze-assistant.runtime.example.json .data/runtime-config.json
export DISCORD_BOT_TOKEN="YOUR_BOT_TOKEN"
```

## Commands

Build and run locally:

```bash
swift build
swift run fizze-assistant config init --config fizze-assistant.local.json
swift run fizze-assistant config validate --config fizze-assistant.local.json
swift run fizze-assistant config show --config fizze-assistant.local.json
swift run fizze-assistant check --config fizze-assistant.local.json
swift run fizze-assistant register-commands --config fizze-assistant.local.json
swift run fizze-assistant run --config fizze-assistant.local.json
```

Build a release binary for the Mac mini:

```bash
swift build -c release
.build/release/fizze-assistant config validate --config fizze-assistant.local.json
.build/release/fizze-assistant check --config fizze-assistant.local.json
.build/release/fizze-assistant register-commands --config fizze-assistant.local.json
.build/release/fizze-assistant run --config fizze-assistant.local.json
```

Discord-side runtime config commands:

- `/config show`
- `/config set setting:<key> value:<value>`
- `/config trigger-add trigger:<exact phrase> response:<message>`
- `/config trigger-remove trigger:<exact phrase>`
- `/config trigger-list`

Only the dedicated config-owner roles may use `/config`. Normal staff roles can still use the moderation and `/say` commands, but they cannot change bot configuration.

## SSH-Friendly Startup

One simple pattern is:

```bash
nohup .build/release/fizze-assistant run --config /path/to/fizze-assistant.local.json > fizze-assistant.log 2>&1 &
```

That keeps the process easy to start over SSH without committing to a larger deployment setup first.

## Secret Safety

- The bot token is expected in `DISCORD_BOT_TOKEN`, not in tracked JSON files.
- The install config and runtime config examples contain placeholders only.
- The runtime config system does not expose or mutate secrets from Discord.
- The Discord-side `/config` command can only change a narrow allowlist of non-secret runtime settings.

## Current Limitations

- `check` prints a setup report and surfaces blocking permission issues.
- `check` can remind you about privileged intents, but Discord does not expose Developer Portal intent-toggle state through the bot API, so the bot cannot verify those toggles directly.
- `register-commands` installs guild-scoped slash commands for fast iteration.
- Warning history is stored locally in SQLite at the configured database path.
- Discord-owned state like members, roles, channels, and moderation context stays in Discord.
- Leave vs. kick vs. ban detection is best-effort from moderation events and audit-log timing.
- Runtime config changes are limited to non-secret values; application ID, guild ID, role gates, database path, and the bot token remain local-only.
- Command authorization is enforced by the bot itself; this project does not currently configure Discord’s separate per-command permission system.
- This repo is intentionally a one-off bot project for a specific friends’ server, not a reusable multi-server bot framework.
