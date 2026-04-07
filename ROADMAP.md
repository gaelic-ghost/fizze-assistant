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
- [ ] Milestone 3: Moderation quality-of-life
- [ ] Milestone 4: Config UX and safer bot operations
- [ ] Milestone 5: Messaging polish and richer iconic behavior

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

## Milestone 3: Moderation Quality-of-Life

Scope:

- [ ] Make moderation history easier to read and act on from Discord.
- [ ] Add lightweight lifecycle rules for warnings so staff do not need to manage old records manually.
- [ ] Improve leave, kick, and ban attribution so departures feel less ambiguous in the logs.

Tickets:

- [ ] Add richer `/warns` output so staff can see warning timestamps, reasons, and relevant context without digging through SQLite by hand.
- [ ] Add warning expiration or aging rules so stale moderation history can be managed intentionally instead of growing forever.
- [ ] Add note-only moderation records for non-warning staff context when a full warning is too heavy-handed.
- [ ] Improve leave-reason attribution so the bot can distinguish voluntary exits, kicks, and bans more confidently when Discord data allows it.
- [ ] Improve moderation summaries and mod-log wording so staff-facing followups read clearly during busy server moments.

Exit criteria:

- [ ] Staff can review warning history from Discord without needing local database inspection.
- [ ] Warning lifecycle behavior is explicit and predictable.
- [ ] Departure and moderation summaries feel trustworthy enough that staff do not need to second-guess them routinely.

## Milestone 4: Config UX and Safer Bot Operations

Scope:

- [ ] Make runtime configuration changes easier to preview, validate, and trust.
- [ ] Improve operator diagnostics so setup and runtime health are obvious from Discord replies and SSH logs.
- [ ] Add lightweight operational helpers without growing unnecessary architecture layers.

Tickets:

- [ ] Add config preview or dry-run behavior for risky `/config` changes where a confirmation step would reduce mistakes.
- [ ] Expand config validation so broken IDs, empty required values, and malformed trigger payloads fail with clearer guidance.
- [ ] Add a simple health or status command so operators can quickly confirm bot state from Discord or SSH.
- [ ] Improve startup self-checks around Discord API access, command registration readiness, and local runtime file expectations.
- [ ] Review Discord API retry and recovery messaging so transient failures and unknown delivery outcomes are easier to understand during incidents.

Exit criteria:

- [ ] Config owners can make runtime changes with a low chance of accidental breakage.
- [ ] Operators can tell whether the bot is healthy without hunting through multiple tools.
- [ ] Common Discord API and setup failures surface with clear, actionable guidance.

## Milestone 5: Messaging Polish and Richer Iconic Behavior

Scope:

- [ ] Refine the bot's conversational surfaces so automated replies feel more intentional and less repetitive.
- [ ] Make iconic response behavior more flexible without turning it into an overbuilt content system.
- [ ] Add enough targeting controls that server-specific messaging stays tidy.

Tickets:

- [ ] Add per-channel or channel-allowlist trigger scoping so iconic replies can be limited to the right places.
- [ ] Improve bot mention reply rules so mention handling feels predictable and does not clash with iconic triggers.
- [ ] Add richer iconic authoring options beyond the current text-plus-first-image flow when the server wants more expressive responses.
- [ ] Review cooldown and trigger matching behavior so repeated messages feel intentional rather than noisy.
- [ ] Improve message-template guidance in docs so new replies and iconic content stay consistent in tone.

Exit criteria:

- [ ] Automated messaging feels polished and predictable in normal server use.
- [ ] Iconic responses are flexible enough for the server's real needs without adding unnecessary complexity.
- [ ] Trigger behavior stays understandable to both staff and config owners.

## Detailed Test Coverage Plan

Scope:

- [ ] Expand automated coverage around the specific Discord and wizard regressions that have already happened in production.
- [ ] Strengthen the test suite at the Discord API boundary so malformed or surprising payloads do not silently turn into live reconnect incidents.
- [ ] Add user-flow confidence checks for the iconic authoring commands so non-technical Discord users get predictable behavior across create and edit flows.

Priority 1: Wizard unhappy-path regression coverage

- [ ] Add a `DiscordInteractionRouterTests` case for `/this-isnt-iconic` when the submitted trigger does not exist, and assert the returned error stays human-friendly and typo-oriented.
- [ ] Add a `DiscordInteractionRouterTests` case for `/this-isnt-iconic` when the target iconic entry uses a richer payload than the wizard can round-trip, and assert the bot returns the explicit `fizze-assistant-local.json` guidance instead of flattening the message.
- [ ] Add a `DiscordInteractionRouterTests` case for a stale create-flow continue button after the draft was removed, and assert the bot returns a readable stale-session error instead of failing opaquely.
- [ ] Add a `DiscordInteractionRouterTests` case for a stale edit-flow continue button after the draft was removed, and assert the same operator-facing clarity for the edit path.
- [ ] Add a `DiscordInteractionRouterTests` case for an outdated second-step modal submission so old open modals fail with the current “unknown modal step” guidance instead of creating partial state.
- [ ] Add a `DiscordInteractionRouterTests` case for edit lookup with mixed casing and extra surrounding whitespace so the normalized-trigger path is locked in for real user input.

Priority 2: Discord registration and payload-shape guardrails

- [ ] Add `DiscordCommandRegistrarTests` checks for slash-command token safety so command names stay within Discord's regex rules before they reach live registration.
- [ ] Add `DiscordCommandRegistrarTests` checks for command description length and other obvious registration-shape constraints that can be validated locally.
- [ ] Add `DiscordCommandRegistrarTests` checks for wizard button and modal `custom_id` lengths so future wizard growth does not quietly produce invalid component payloads.
- [ ] Add a `DiscordRESTClientTests` case for command-registration failures that include Discord's field-level validation errors, and assert the surfaced error message makes the bad request obvious to the operator.
- [ ] Add a `DiscordModelsTests` or `DiscordGatewayPayloadTests` case for a full `INTERACTION_CREATE` payload with numeric `data.id`, not just the local model decode, so the exact live regression shape stays covered.
- [ ] Add additional decode tests for interaction-adjacent Discord payload fields that may appear as either strings or numbers when the wire format is effectively opaque to the bot.

Priority 3: Gateway resilience and bot-level survival

- [ ] Add a `DiscordGatewayClientTests` case proving an `INTERACTION_CREATE` event with numeric `data.id` reaches the interaction handler instead of tearing down the Gateway session.
- [ ] Add a `DiscordGatewayClientTests` case for unexpected but ignorable dispatch payload shapes where one bad event should be rejected without poisoning the rest of the session when the event can safely be dropped.
- [ ] Add a `FizzeBotTests` case that verifies the bot remains operational after a recoverable interaction decode anomaly, so resilience is tested at the application layer instead of only at the model layer.
- [ ] Review existing Gateway reconnect tests and add any missing assertions around session reuse versus fresh identify so future payload-tolerance fixes do not accidentally weaken reconnect behavior.

Priority 4: End-to-end user-flow confidence for iconic commands

- [ ] Add a create-flow test that covers plain text content without a URL, and assert the saved config shape matches the intended product behavior for text-only iconic replies.
- [ ] Add an edit-flow test that rewrites only the message content while preserving the same trigger key, and assert that the flow behaves like editing content rather than replacing identity.
- [ ] Add a full create-flow snapshot-style test that asserts the first modal, continue prompt, second modal, and final persisted config together, so the whole authoring contract is documented in one place.
- [ ] Add a full edit-flow snapshot-style test that asserts the trigger prompt, current-content summary, prefilled content modal, and final persisted config together.
- [ ] Add a test that verifies both iconic command flows remain within Discord field-length limits for labels, titles, button text, placeholders, and any summary text that is constrained by component rules.

Execution order:

- [ ] Implement Priority 1 first so the next round of wizard UX work lands against explicit unhappy-path coverage.
- [ ] Implement Priority 2 second so Discord registration and payload-shape mistakes fail in tests before they fail at startup or during live interaction handling.
- [ ] Implement Priority 3 third so Gateway and bot resilience are covered after the payload-shape guardrails are in place.
- [ ] Implement Priority 4 last as the confidence layer that protects the overall non-technical Discord user experience.

## Risks and mitigations

- [ ] Discord-side permissions, role hierarchy, and privileged intents remain the main setup footguns, so diagnostics should stay explicit.
- [ ] New helper scripts and command surfaces should stay small and reviewable to avoid accidental deployment-framework creep.
- [ ] Suggestion collection should avoid storing more personal or long-lived data than the feature really needs.

## Backlog candidates

- [ ] Add richer iconic authoring controls if the server wants more than the current text-plus-first-image flow.
- [ ] Add optional command-registration diffing or clearer idempotency messaging during startup.
- [ ] Add a simple health/status helper command for SSH operators if routine maintenance starts to feel opaque.
