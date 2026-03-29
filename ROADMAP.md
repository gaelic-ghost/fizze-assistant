# Project Roadmap

## Vision

- Keep `Fizze Assistant` as a reliable, friendly, one-off Discord bot for the friends' server, with low-maintenance operations on the Mac mini and polished moderation/community workflows.

## Product principles

- Keep delivery deterministic and reviewable.
- Prefer small refinements over new architecture layers or extra dependencies.
- Make operator-facing failures easy to understand from SSH and logs.
- Keep command UX friendly, concise, and server-appropriate.

## Milestone Progress

- [ ] Milestone 0: Foundation
- [ ] Milestone 1: Operator polish and startup refinement
- [ ] Milestone 2: Command UX and community feedback workflows

## Milestone 0: Foundation

Scope:

- [x] Ship a working Swift Package CLI bot for a single Discord server.
- [x] Support gateway-driven member lifecycle events and guild-scoped slash commands.
- [x] Support local config plus environment-based secret handling for the Mac mini deployment flow.

Tickets:

- [x] Implement welcome messages, leave announcements, auto-role assignment, warnings, `/say`, and iconic responses with configurable matching modes.
- [x] Add runtime config management with local persistence and Discord-side `/config` subcommands.
- [x] Add embed-capable iconic message storage plus the `/this-is-iconic` creation flow.
- [x] Add `check`, `register-commands`, `setup.sh`, `start-nohup.sh`, and `stop.sh` for SSH-friendly operations.
- [x] Allow native Discord `Administrator` and `Manage Server` members to use bot admin/config commands.

Exit criteria:

- [x] `swift build` passes.
- [x] `swift test` passes.
- [x] The bot can be launched from the Mac mini with local config and env-only token handling.

## Milestone 1: Operator Polish and Startup Refinement

Scope:

- [ ] Make setup, startup, and recovery smoother for sleepy late-night operator brains.
- [ ] Improve remote diagnostics so common Discord permission and install failures are obvious from the log output.
- [ ] Add lightweight operational helpers without turning the bot into a deployment framework.

Tickets:

- [ ] Improve `check` and startup error wording for common failures such as bot-not-in-guild, missing role hierarchy, missing channels, and stale PID state.
- [ ] Add clearer log phase markers for build, validation, command registration, and run mode.
- [ ] Add a tiny `scripts/logs.sh` helper for tailing the bot log over SSH.
- [ ] Add a short troubleshooting section to `README.md` covering the most common Mac mini and Discord setup issues.
- [ ] Review default runtime config copy so the out-of-box welcome, leave, moderation, and failure messages feel more polished.

Exit criteria:

- [ ] A first-time operator can understand the likely cause of a startup failure directly from `fizze-assistant.log`.
- [ ] The SSH launch, log-follow, and stop flow feels smooth without extra tribal knowledge.
- [ ] Default bot messages feel intentional rather than purely utilitarian.

## Milestone 2: Command UX and Community Feedback Workflows

Scope:

- [ ] Refine slash command responses so moderation and config actions feel polished and trustworthy.
- [ ] Add a native way for server members to submit bot feedback and feature ideas.
- [ ] Tie bot feedback handling into the server's existing suggestions flow.

Tickets:

- [ ] Improve `/warn`, `/warns`, `/clear-warning`, `/clear-warnings`, and `/config` response copy for clarity, tone, and confirmation detail.
- [ ] Add a `/suggestions` slash command that lets users submit bot suggestions in a structured way.
- [ ] Route `/suggestions` submissions to the server's bot suggestions channel.
- [ ] Consolidate and organize suggestions so repeat ideas are grouped instead of becoming noisy duplicates.
- [ ] Add staff-facing review output for suggestions so admins can see open themes and likely next improvements.
- [ ] Define how suggestion retention should work so the bot does not keep unnecessary local state forever.

Exit criteria:

- [ ] Admin and config commands return polished, unambiguous feedback.
- [ ] Server members have a clear in-Discord path to suggest bot improvements.
- [ ] Suggestions are organized enough that staff can act on them without manual cleanup becoming annoying.

## Risks and mitigations

- [ ] Discord-side permissions, role hierarchy, and privileged intents remain the main setup footguns, so diagnostics should stay explicit.
- [ ] New helper scripts and command surfaces should stay small and reviewable to avoid accidental deployment-framework creep.
- [ ] Suggestion collection should avoid storing more personal or long-lived data than the feature really needs.

## Backlog candidates

- [ ] Add richer iconic authoring controls if the server wants more than the current text-plus-first-image flow.
- [ ] Add optional command-registration diffing or clearer idempotency messaging during startup.
- [ ] Add a simple health/status helper command for SSH operators if routine maintenance starts to feel opaque.
