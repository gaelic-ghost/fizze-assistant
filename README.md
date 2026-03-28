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
2. Copy the Application ID into the committed JSON config file.
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

The bot now uses one committed JSON config file for all non-secret settings:

- [fizze-assistant.json](/Users/galew/Workspace/fizze-assistant/fizze-assistant.json)

That file holds the Discord IDs, channel settings, role gates, message templates, and trigger configuration. The only secret that stays outside git is the bot token.

`DISCORD_BOT_TOKEN` stays environment-only and is never editable from Discord.

On a deployment machine such as the Mac mini, you can also keep the token in `.env.local`:

```bash
export DISCORD_BOT_TOKEN="YOUR_BOT_TOKEN"
```

## Commands

Build and run locally:

```bash
swift build
swift run fizze-assistant config init --config fizze-assistant.json
swift run fizze-assistant config validate --config fizze-assistant.json
swift run fizze-assistant config show --config fizze-assistant.json
swift run fizze-assistant check --config fizze-assistant.json
swift run fizze-assistant register-commands --config fizze-assistant.json
swift run fizze-assistant run --config fizze-assistant.json
```

Build a release binary for the Mac mini:

```bash
swift build -c release
.build/release/fizze-assistant config validate --config fizze-assistant.json
.build/release/fizze-assistant check --config fizze-assistant.json
.build/release/fizze-assistant register-commands --config fizze-assistant.json
.build/release/fizze-assistant run --config fizze-assistant.json
```

There is also a thin setup script for the Mac mini flow. It loads `.env.local`, builds the release binary if needed, runs `check`, registers commands, and then starts the bot:

```bash
./scripts/setup.sh
```

Discord-side runtime config commands:

- `/config show`
- `/config set setting:<key> value:<value>`
- `/config trigger-add trigger:<exact phrase> response:<message>`
- `/config trigger-remove trigger:<exact phrase>`
- `/config trigger-list`

Only the dedicated config-owner roles may use `/config`. Normal staff roles can still use the moderation and `/say` commands, but they cannot change bot configuration.

Discord members with the native `Administrator` or `Manage Server` permission are also allowed to use staff and config-owner commands, even if their role IDs are not listed explicitly in the local config.

The committed config already includes `suggestionsChannelID` so the future bot suggestions workflow can stay in sync across machines through normal git pull/push.

## SSH-Friendly Startup

One simple pattern is:

```bash
nohup .build/release/fizze-assistant run --config /path/to/fizze-assistant.json > fizze-assistant.log 2>&1 &
```

There is also a small helper for that SSH-friendly background case:

```bash
./scripts/start-nohup.sh
```

It runs `scripts/setup.sh` under `nohup`, writes output to `fizze-assistant.log`, and stores the process ID in `.data/fizze-assistant.pid`.

To stop the background process cleanly:

```bash
./scripts/stop.sh
```

That keeps the process easy to start over SSH without committing to a larger deployment setup first.

## Secret Safety

- The bot token is expected in `DISCORD_BOT_TOKEN`, not in tracked JSON files.
- The committed `fizze-assistant.json` file is intentionally for non-secret server metadata only.
- The config system does not expose or mutate secrets from Discord.
- The Discord-side `/config` command can only change a narrow allowlist of non-secret runtime settings.
- In a public repository, channel IDs and role IDs are usually fine to commit if you are comfortable treating them as public server metadata, but the bot token must remain local-only in `DISCORD_BOT_TOKEN`.

## Current Limitations

- `check` prints a setup report and surfaces blocking permission issues.
- `check` can remind you about privileged intents, but Discord does not expose Developer Portal intent-toggle state through the bot API, so the bot cannot verify those toggles directly.
- `register-commands` installs guild-scoped slash commands for fast iteration.
- Warning history is stored locally in SQLite at the configured database path.
- Discord-owned state like members, roles, channels, and moderation context stays in Discord.
- Leave vs. kick vs. ban detection is best-effort from moderation events and audit-log timing.
- Runtime config changes are limited to a narrow allowlist of non-secret values, even though the broader non-secret baseline now lives in the committed `fizze-assistant.json` file.
- Command authorization is enforced by the bot itself; this project does not currently configure Discord’s separate per-command permission system.
- This repo is intentionally a one-off bot project for a specific friends’ server, not a reusable multi-server bot framework.
