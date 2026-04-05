# RockeRoom

RockeRoom is an alpha iOS app that uses Clash as the execution core and keeps recommendation truth in one shared snapshot/policy layer.

## Current Model

- Auto Mode is the home surface.
- Expert Console is the inspect surface.
- Marketplace is read-only and evidence-based.
- Manual pin means no auto-switch until the user unpins.

## Evidence Model

All user-facing evidence comes from the same shared snapshot and recommendation output. That keeps Auto Mode, Expert Console, and Marketplace aligned on the current setup, freshness, and partial-data state.

## Observability Constraint

The current alpha does not claim private per-app telemetry. The observability spike documents the current platform limit and the fallback language to use when synthetic probes are the best available signal.

## Destination Routing (Sprint 1)

The routing optimization roadmap is destination-aware. Sprint 1 is explicitly **tests-first and contract-first** — it does not implement the runtime routing engine. Instead, it:

- Locks the v1 destination fixture catalog (`Tests/Fixtures/routing-destinations/`) so later routing code cannot silently widen scope
- Defines the routing-state contract in executable tests (`DestinationRoutingContractTests`, `RoutingOptimizationPolicyTests`) so semantics are explicit before types are introduced
- Expands the live E2E scenario matrix to include destination-aware routing journeys (`auto-mode-apply`, `manual-mode-advisory`, `override-or-pin`, `stale-or-refresh`, `failed-reassignment`)

The Sprint 1 contract is in `docs/plans/2026-04-04-017-feat-routing-optimization-sprint-1-plan.md`.

## Development

The project is generated from `project.yml`. Use Xcode 17 / iOS 17 with the `RockeRoom` scheme.

## Alpha Validation

Use the integrated `RockeRoom` scheme as the alpha gate. The stable command is:

```sh
xcodebuild -project RockeRoom.xcodeproj -scheme RockeRoom -destination 'platform=iOS Simulator,name=iPhone 17' test -parallel-testing-enabled NO
```

For manual simulator testing, the debug overlay starts a simulator-safe debug session: it resets app state, imports a built-in deterministic demo subscription, or imports a typed live URL. Import, `Home`, `Run Benchmark`, and `Expert Console` remain the normal product flow, while true tunnel IPC validation stays a separate runtime path.

For TestFlight and evaluator handoff steps, see `docs/release/alpha-testflight-checklist.md`.
