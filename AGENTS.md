# AGENTS.md

Use this file for durable repo-local guidance that Codex should follow before changing code, docs, or project workflow surfaces in this repository.

## Repository Scope

### What This File Covers

This root-level file governs the Swift Package Manager Discord bot, its tests, repository docs, local helper scripts, and repo-maintenance release and validation surface.

### Where To Look First

- `Package.swift` for package products, targets, dependencies, platform, and language mode.
- `README.md` and `ROADMAP.md` for current operator behavior and planned project direction.
- `Sources/FizzeAssistant/` and `Tests/FizzeAssistantTests/` for source and matching test coverage.
- `fizze-assistant.json` for the committed non-secret config baseline.
- `scripts/repo-maintenance/` for validation, shared sync, and release entrypoints.

## Working Rules

### Change Scope

Keep changes focused on the requested bot behavior, docs, tests, or maintainer surface. If a change starts turning this one-server bot into a reusable multi-server framework, stop and make that scope expansion explicit before implementing it.

### Source of Truth

Use Swift Package Manager as the source of truth for package structure and dependencies. Prefer `swift package` CLI commands for structural changes when available; otherwise update `Package.swift` intentionally and keep package graph edits grouped with `Package.resolved` and matching target or test layout changes.

### Communication and Escalation

Surface tradeoffs before changing Discord permission assumptions, runtime config ownership, release behavior, or deployment scripts. Any setup issue that can be fixed from Discord itself should stay non-blocking at startup and should be reported in calm, actionable operator language.

## Commands

### Setup

```bash
swift build
cp fizze-assistant.json fizze-assistant-local.json
swift run fizze-assistant config validate
swift run fizze-assistant check
```

### Validation

```bash
swift build
swift test
bash scripts/repo-maintenance/validate-all.sh
```

### Optional Project Commands

```bash
swift run fizze-assistant register-commands
swift run fizze-assistant run
./scripts/setup.sh
./scripts/start-nohup.sh
./scripts/stop.sh
```

## Review and Delivery

### Review Expectations

Before handing work back, summarize the changed repo surfaces, call out any Discord setup or deployment implications, and report the exact validation commands that ran.

### Definition of Done

Work is done when the relevant source, tests, docs, and local scripts agree; `swift build`, `swift test`, and `bash scripts/repo-maintenance/validate-all.sh` have either passed or any blocker is reported clearly; and no secrets or local runtime config files are staged.

## Safety Boundaries

### Never Do

- Never commit Discord bot tokens, `.env` files, or `fizze-assistant-local.json`.
- Never replace Discord-owned state with local source-of-truth files unless Gale explicitly asks for that architecture change.
- Never make a setup issue startup-blocking when the same issue can be fixed from Discord after the bot starts.
- Never hand-edit generated package-manager output such as `Package.resolved`.

### Ask Before

- Ask before changing the public/private repo posture, release policy, or deployment model.
- Ask before widening this project into a reusable multi-server bot framework.
- Ask before changing committed Discord IDs, role gates, or channel routing unless the request is specifically about those settings.

## Local Overrides

There are no deeper repo-local AGENTS files currently. If a narrower AGENTS file is added later, its guidance refines this root file for work in that subtree.

## Baseline Provenance

- This template is the full bootstrap `AGENTS.md` used for new Swift package repositories.
- It intentionally incorporates the shared Swift/Apple baseline from `shared/agents-snippets/apple-swift-core.md`.
- Keep baseline guidance aligned with the shared snippet and use this template for deterministic scaffold output.

## Swift Coding Preferences

- Use idiomatic Swift and Cocoa-style naming conventions.
- Prefer explicit, consistent, and unambiguous names.
- Prefer compact and concise code; use shorthand syntax when readability remains high.
- Prefer trailing-closure syntax when it improves clarity.
- Avoid deep nesting; refactor into focused helpers and types.

## Types and Architecture

- Prefer value types (`struct`, `enum`) for domain modeling.
- Prefer concrete types internally; use protocols at module seams and integration boundaries.
- Mark classes as `final` by default.
- Prefer synthesized conformances (`Codable`, `Equatable`, `Hashable`, etc.) where possible.
- Prefer synthesized/memberwise initializers; avoid unnecessary custom initializers.
- Use enums as namespaces to group related concerns.
- Keep code modular and cohesive; group highly related concerns together.
- Avoid spaghetti code and tight coupling.
- Prefer pure Swift solutions where practical.
- For JSON or API boundary models, prefer the literal wire-format field names directly instead of local style remapping.
- Do not add `CodingKeys` as stylistic translation glue. Only keep them for real protocol mismatches that cannot be expressed by naming the property after the serialized field.
- Any setup issue that can be fixed from Discord itself must never be startup-blocking.
- Operator-facing console and log messages should stay calm and actionable; avoid harsh failure phrasing when the bot is intentionally continuing in a degraded but expected state.

## Concurrency and Language Mode

- Keep code compliant with Swift 6 language mode.
- Keep strict concurrency checking enabled.
- Use modern structured concurrency (`async`/`await`, task groups) instead of legacy async patterns.
- For app-facing packages, prefer approachable concurrency defaults with main-actor isolation by default.
- Introduce parallelism where it produces clear performance gains.

## State, Frameworks, and Dependencies

- Prefer `@Observation` over Combine for observation/state propagation.
- Prefer frameworks and packages from Swift.org, Swift on Server, Apple, and Apple Open Source ecosystems when suitable.
- Commonly acceptable examples include packages like `swift-algorithms`.

## Testing and Tooling Baseline

- Use Swift Testing (`import Testing`) as the default test framework.
- Avoid XCTest unless an external constraint requires it.
- Keep formatting consistent with `swift-format` conventions.
- Keep linting clean against `swiftlint` with clear, maintainable rule intent.

## CLI Tooling Preferences

- Prefer `swift package` for package-focused workflows (dependency graph, targets, manifest intent, and local package validation).
- Prefer `swift package` subcommands for structural package edits before manually editing `Package.swift`.
- Use `swift build` and `swift test` as the default first-pass validation commands.
- Use `xcodebuild` when validating Apple platform integration details that `swift package` does not cover well (schemes, destinations, SDK-specific behavior, and configuration-specific builds/tests).
- Keep `xcodebuild` invocations explicit and reproducible (always pass scheme, destination or SDK, and configuration when relevant).
- Prefer deterministic non-interactive CLI usage in automation/CI for both `swift package` and `xcodebuild`.

## Swift Package Workflow

- Use `swift build` and `swift test` as the default first-pass validation commands for this package.
- Use `bootstrap-swift-package` when a new Swift package repo still needs to be created from scratch.
- Use `sync-swift-package-guidance` when the repo guidance for this package drifts and needs to be refreshed or merged forward.
- Re-run `sync-swift-package-guidance` after substantial package-workflow or plugin updates so local guidance stays aligned.
- Use `swift-package-build-run-workflow` for manifest, dependency, plugin, resource, Metal-distribution, build, and run work when `Package.swift` is the source of truth.
- Use `swift-package-testing-workflow` for Swift Testing, XCTest holdouts, `.xctestplan`, fixtures, and package test diagnosis.
- Use `scripts/repo-maintenance/validate-all.sh` for local maintainer validation, `scripts/repo-maintenance/sync-shared.sh` for repo-local sync steps, and `scripts/repo-maintenance/release.sh` for releases.
- Treat `scripts/repo-maintenance/config/profile.env` as the installed profile marker for this repo-maintenance toolkit surface, and keep it on the `swift-package` profile for plain package repos.
- Read relevant SwiftPM, Swift, and Apple documentation before proposing package-structure, dependency, manifest, concurrency, or architecture changes.
- Prefer Dash or local Swift docs first, then official Swift or Apple docs when local docs are insufficient.
- Prefer the simplest correct Swift that is easiest to read and reason about.
- Prefer synthesized and framework-provided behavior over extra wrappers and boilerplate.
- Keep data flow straight and dependency direction unidirectional.
- Treat `Package.swift` as the source of truth for package structure, targets, products, and dependencies.
- Prefer `swift package` subcommands for structural package edits before manually editing `Package.swift`.
- Edit `Package.swift` intentionally and keep it readable; agents may modify it when package structure, targets, products, or dependencies need to change, and should try to keep package graph updates consolidated in one change when possible.
- Keep `Package.swift` explicit about its package-wide Swift language mode. On current Swift 6-era manifests, prefer `swiftLanguageModes: [.v6]` as the default declaration and treat `swiftLanguageVersions` as a legacy alias used only when an older manifest surface requires it.
- Avoid adding unnecessary dependency-provenance detail or switching to branch/revision-based requirements unless the user explicitly asks for that level of control.
- Treat `Package.resolved` and similar package-manager outputs as generated files; do not hand-edit them.
- Prefer Swift Testing by default unless an external constraint requires XCTest.
- Use `apple-ui-accessibility-workflow` when the package work crosses into SwiftUI accessibility semantics, Apple UI accessibility review, or UIKit/AppKit accessibility bridge behavior.
- Keep package resources under the owning target tree, declare them intentionally with `Resource.process(...)`, `Resource.copy(...)`, `Resource.embedInCode(...)`, and load them through `Bundle.module`.
- Keep test fixtures as test-target resources instead of relying on the working directory.
- Bundle precompiled Metal artifacts such as `.metallib` files as explicit resources when they ship with the package, and prefer `xcode-build-run-workflow` when shader compilation or Apple-managed Metal toolchain behavior matters.
- Validate both Debug and Release paths when optimization or packaging differences matter, and treat tagged releases as a cue to verify the Release artifact path before publishing.
- Prefer `xcode-build-run-workflow` or `xcode-testing-workflow` only when package work needs Xcode-managed SDK, toolchain, or test behavior.
- Keep runtime UI accessibility verification and XCUITest follow-through in `xcode-testing-workflow` rather than treating package-side testing as a substitute for live UI verification.
