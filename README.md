# Fizze Assistant

`Fizze Assistant` is a one-off Swift command-line Discord bot for some friends in a single Discord server: `https://discord.gg/2kz68FvyJg`. It connects to Discord over the Gateway for realtime events and uses the Discord HTTP API for commands, messages, role assignment, and audit-log lookups.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Development](#development)
- [Repo Structure](#repo-structure)
- [Release Notes](#release-notes)
- [License](#license)
- [What It Does](#what-it-does)
- [Why This Shape](#why-this-shape)
- [Project Layout](#project-layout)
- [Requirements](#requirements)
- [Developer Portal Setup](#developer-portal-setup)
- [Required Discord Permissions](#required-discord-permissions)
- [Configuration](#configuration)
- [Commands](#commands)
- [SSH-Friendly Startup](#ssh-friendly-startup)
- [Secret Safety](#secret-safety)
- [Current Limitations](#current-limitations)
- [Planned Directions](#planned-directions)

## Overview

### Status

Fizze Assistant is in active private use for one Discord server and remains tailored to that server instead of being packaged as a reusable bot framework.

### What This Project Is

Fizze Assistant is a Swift Package Manager command-line bot that connects to Discord, manages server onboarding and moderation helpers, and stores only the local state it needs for runtime config and warning history. The repo owns the bot executable, its Swift tests, non-secret baseline config, SSH-friendly helper scripts, and local maintainer automation.

### Motivation

The project exists to keep one friends' server easier to run without turning those server-specific needs into a general-purpose Discord platform. It stays small so the bot can be understood, checked, and restarted from an ordinary Mac shell.

## Quick Start

This bot is meant for the configured private server, so there is not a generic public quick start. For local development, install Swift 6.2 or newer, keep `DISCORD_BOT_TOKEN` in your shell environment, copy the committed config to an untracked local config, and use the commands in [Development](#development) and [Commands](#commands).

## Usage

Normal use is operator-driven: build the executable, validate the Discord setup, register guild-scoped slash commands, and run the long-lived bot process.

```bash
swift run fizze-assistant config validate
swift run fizze-assistant check
swift run fizze-assistant register-commands
swift run fizze-assistant run
```

On the Mac mini deployment path, the helper scripts under `scripts/` wrap the same build, check, register, run, start, and stop flow.

## Development

### Setup

Use Swift 6.2 or newer, install the Discord bot in the target server, enable the required privileged intents in the Discord Developer Portal, and keep the bot token in `DISCORD_BOT_TOKEN`. For local runtime edits, copy `fizze-assistant.json` to `fizze-assistant-local.json` and keep the local file untracked.

### Workflow

Treat `Package.swift` as the SwiftPM source of truth. Make source and test changes in matching feature areas, keep non-secret config changes in the committed baseline only when they should sync across machines, and use the repo-maintenance scripts for shared validation and release work.

### Validation

Run the Swift package checks and the repo-maintenance gate before handing work back:

```bash
swift build
swift test
bash scripts/repo-maintenance/validate-all.sh
```

## Repo Structure

```text
.
├── Package.swift
├── Sources/FizzeAssistant/
├── Tests/FizzeAssistantTests/
├── fizze-assistant.json
├── scripts/
└── scripts/repo-maintenance/
```

The source and test trees are intentionally aligned by feature area so nearby behavior and coverage stay easy to find together.

## Release Notes

This repo uses `scripts/repo-maintenance/release.sh` for release flow automation when a tagged release is needed. Notable planned work and shipped direction live in `ROADMAP.md` until the project grows a dedicated release-notes surface.

## License

No license file is currently committed.

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

## Project Layout

The package is organized to keep the source tree and test tree aligned:

- `Sources/FizzeAssistant/App`
  - CLI entry points, startup wiring, and top-level bot orchestration
- `Sources/FizzeAssistant/Discord`
  - Discord wire models, Gateway handling, and REST client behavior
- `Sources/FizzeAssistant/Features/Configuration`
  - baseline and local config models, runtime projection, and persistence
- `Sources/FizzeAssistant/Features/Interactions`
  - slash-command routing, authorization, parsing, and wizard flows
- `Sources/FizzeAssistant/Features/Messaging`
  - iconic-response matching and template rendering
- `Sources/FizzeAssistant/Features/Moderation`
  - warning storage and leave-reason classification
- `Sources/FizzeAssistant/Features/Permissions`
  - Discord permission math and human-readable setup reports
- `Tests/FizzeAssistantTests/...`
  - mirrors those same `App`, `Discord`, and `Features/*` slices, with shared fixtures under `Tests/FizzeAssistantTests/TestSupport`

That alignment is intentional: if a source file changes, its nearest tests should be easy to find in the matching test area instead of hidden behind a separate integration-only hierarchy.

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

- [fizze-assistant.json](./fizze-assistant.json)
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

Test the whole package locally:

```bash
swift test
```

If you are iterating on one area, the filtered suites follow the same source-oriented layout. For example:

```bash
swift test --filter ConfigurationStoreTests
swift test --filter DiscordInteractionRouterTests
swift test --filter '(DiscordModelsTests|DiscordGatewayPayloadTests)'
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

The resulting iconic message is saved under `iconic_messages` in the active local JSON config file, keyed by normalized trigger text. The runtime now treats `fizze-assistant.json` as a committed baseline template only: if `fizze-assistant-local.json` is missing, startup seeds it from the baseline and then uses only the local file for future edits. Hand-editing the active local JSON is still the escape hatch for any richer embed payloads you want to author manually.

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
