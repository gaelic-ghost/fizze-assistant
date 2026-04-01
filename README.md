# Fizze Assistant

`Fizze Assistant` is a one-off Swift command-line Discord bot for some friends in a single Discord server: `https://discord.gg/2kz68FvyJg`. It connects to Discord over the Gateway for realtime events and uses the Discord HTTP API for commands, messages, role assignment, and audit-log lookups.

## What It Does

- Welcomes new members in a configured channel
- Announces member departures in a configured channel
- Distinguishes voluntary leaves from kicks and bans when Discord data allows it
- Auto-assigns a configured member role on join
- Provides staff slash commands for `/say`, `/warn`, `/warns`, `/clear-warning`, and `/clear-warnings`
- Provides config-owner slash commands under `/config` for safe runtime config changes
- Sends configurable “iconic” auto-replies using either exact-match or broader `fuzze` substring matching
- Can create new embed-backed iconic responses directly from Discord with `/this-is-iconic`
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

The bot now uses one committed JSON config file as the shared baseline for all non-secret settings:

- [fizze-assistant.json](/Users/galew/Workspace/fizze-assistant/fizze-assistant.json)
- `fizze-assistant-local.json` for untracked live runtime overrides

The committed baseline holds the Discord IDs, channel settings, role gates, message templates, and trigger configuration. The only secret that stays outside git is the bot token.

For iconic responses, the committed config now includes:

- `trigger_matching_mode` with `exact` and `fuzze`
- `iconic_messages`, keyed by normalized trigger text

`DISCORD_BOT_TOKEN` stays environment-only and is never editable from Discord.

On a deployment machine such as the Mac mini, you can also keep the token in `.env.local`:

```bash
export DISCORD_BOT_TOKEN="YOUR_BOT_TOKEN"
```

## Commands

Build and run locally:

```bash
swift build
cp fizze-assistant.json fizze-assistant-local.json
swift run fizze-assistant config validate
swift run fizze-assistant config show
swift run fizze-assistant check
swift run fizze-assistant register-commands
swift run fizze-assistant run
```

Without `--config`, the bot now prefers `fizze-assistant-local.json`, then falls back to the tracked `fizze-assistant.json`. Once the local file exists, live `/config` and wizard changes stay out of git by default.

Build a release binary for the Mac mini:

```bash
swift build -c release
.build/release/fizze-assistant config validate
.build/release/fizze-assistant check
.build/release/fizze-assistant register-commands
.build/release/fizze-assistant run
```

There is also a thin setup script for the Mac mini flow. It loads `.env.local`, rebuilds the release binary when it is missing or stale, runs `check`, registers commands, and then starts the bot:

```bash
./scripts/setup.sh
```

Discord-side runtime config commands:

- `/config show`
- `/config set setting:<key> value:<value>`
- `/config trigger-add trigger:<phrase> response:<message>`
- `/config trigger-remove trigger:<phrase>`
- `/config trigger-list`
- `/this-is-iconic`

Simple text iconic messages can still be added from Discord with `/config trigger-add`. `/config set` can also update `trigger_matching_mode` to either `exact` or `fuzze`, and `/config trigger-list` now shows the current matching mode plus each trigger's payload type.

For richer iconic messages, `/this-is-iconic` walks through a two-step Discord-native flow:

1. It asks for the trigger text and normalizes it before saving.
2. It asks for the iconic content text, keeps that text verbatim as embed description, and uses the first URL in the text as the embed image when one is present.

The resulting iconic message is saved under `iconic_messages` in the active JSON config file, keyed by normalized trigger text. With the default local-override flow, that means `fizze-assistant-local.json` once you create it. Hand-editing the active JSON is still the escape hatch for any richer embed payloads you want to author manually.

Only the dedicated config-owner roles may use `/config`. Normal staff roles can still use the moderation and `/say` commands, but they cannot change bot configuration.

Discord members with the native `Administrator` or `Manage Server` permission are also allowed to use staff and config-owner commands, even if their role IDs are not listed explicitly in the local config.

The committed config already includes `suggestions_channel_id` so the future bot suggestions workflow can stay in sync across machines through normal git pull/push.

## SSH-Friendly Startup

One simple pattern is:

```bash
nohup .build/release/fizze-assistant run --config /path/to/fizze-assistant-local.json > fizze-assistant.log 2>&1 &
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
- For live runtime use, prefer copying it to `fizze-assistant-local.json` so `/config` and wizard changes do not create git conflicts.
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
- `this-is-iconic` uses a short-lived in-memory draft between its modal steps, so a stale or abandoned wizard needs to be restarted from the slash command.
- Runtime config changes are limited to a narrow allowlist of non-secret values, even though the broader non-secret baseline now lives in the committed `fizze-assistant.json` file. With the local override flow, those live changes land in `fizze-assistant-local.json` by default.
- Command authorization is enforced by the bot itself; this project does not currently configure Discord’s separate per-command permission system.
- This repo is intentionally a one-off bot project for a specific friends’ server, not a reusable multi-server bot framework.

## Planned Directions

- Moderation quality-of-life improvements such as richer warning history views, warning expiration, and better leave/ban/kick attribution.
- Config UX improvements such as safer previews, richer validation, and more helpful config-owner command flows.
- Messaging polish such as per-channel trigger controls, better mention-reply rules, and richer iconic response authoring.
- Operator visibility improvements such as setup diagnostics, health/status commands, and clearer mod-log summaries.
- Reliability refinements such as startup self-checks and safer Discord API recovery behavior.
