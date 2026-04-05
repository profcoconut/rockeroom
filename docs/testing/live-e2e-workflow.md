# Live E2E Workflow

RockeRoom now supports a launch-driven live E2E workflow so simulator validation can replay most of the manual checklist even when the current XcodeBuildMCP surface does not expose `tap` or `type_text`.

This workflow should now be read against the current product direction: RockeRoom is validating a monitor-and-optimize loop, not just a one-shot benchmark flow.

For manual simulator use, the debug overlay is now intentionally narrower than the launch-driven harness:

- it can reset app state
- it can start a simulator-safe manual debug runtime session
- it can import a built-in deterministic demo subscription
- it can import a typed live URL through the normal import path

It does **not** seed benchmarked, pinned, stale, or tunnel-failure end states anymore. After a debug import succeeds, `Run Benchmark` and everything after it remain the normal product flow.

`Run Benchmark` now means:

- start the destination-aware fast pass
- persist the best current route per curated destination
- begin foreground adaptive monitoring while the app stays active

The route under test should be understood as a runtime context, not just a destination label:

- current environment, such as home Wi‑Fi, office Wi‑Fi, or 5G
- current destination, represented as a curated rule-backed app or service category
- current provider or node source
- current strategy, such as direct, country route, or HY2-capable path

## What This Covers

- importing a subscription from a live URL or deterministic fixture
- running the adaptive benchmark loop as the start of an optimization session
- opening `Home`, `Expert Console`, and `Marketplace`
- pinning and unpinning from the normal recommendation path
- stale restore and refresh
- tunnel failure and recovery
- route-context scenarios (fast pass, foreground monitoring, auto-switch, override/pin, stale refresh, failed reassignment recovery, future environment-sensitive reassessment)

## Scenario Contract

The app reads these launch environment keys:

- `ROCKEROOM_LIVE_E2E_SCENARIO`
- `ROCKEROOM_LIVE_E2E_LINK`

### Established Scenarios (provider-level)

- `import-home`
- `benchmark-home`
- `expert-console`
- `pin-stable`
- `pin-unpin-home`
- `marketplace`
- `stale-hint`
- `stale-refresh`
- `tunnel-failure`
- `tunnel-recovery`

### Destination-Aware Routing Scenarios

These scenarios exercise the destination-routing state contract introduced in Sprint 2 and extended by adaptive routing. They replay a specific routing state by seeding `DestinationRoutingAssignments` into the shared `DestinationRoutingAssignmentStore` before app restore.

Sprint 1 now gives this contract concrete production vocabulary:

- `NetworkEnvironment` for the current environment, defaulting safely to `.unknown`
- `RoutingStrategy` for shared strategy identity, including stable fallback handling for unsupported raw labels
- `RouteContext` for the tuple `(environment, destination, provider, strategy)`
- `DestinationRoutingAssignment` as the current assignment record that carries one `routeContext`

The harness contract remains route-context-aware even where it does not yet seed a distinct non-unknown environment value. Environment-sensitive behavior is a planned extension, not a reason to keep the docs destination-only.

The harness seeds the following state through `LiveE2EScenario.destinationAssignment`:

- `auto-mode-apply` — Fast pass or monitoring applies a better route when evidence is strong
- `manual-mode-advisory` — Manual Mode surfaces a better route but requires user confirmation
- `override-or-pin` — User override or pin suppresses the automatic recommendation
- `stale-or-refresh` — Evidence is stale and a refresh is required before acting
- `failed-reassignment` — Route reassignment failed and the app recovered to a safe state

The runner is state-aware. It uses the normal view-model methods for import, benchmark, tab selection, and pinning rather than bypassing product code.

## Destination-Aware Routing Matrix

The destination routing scenarios define a contract matrix for later sprint implementation:

| Scenario | Evidence | Strategy | Action |
|---|---|---|---|
| `auto-mode-apply` | Strong + fresh | Auto | App auto-applies better route after fast pass or monitoring |
| `manual-mode-advisory` | Any | Manual | App surfaces advisory, user decides |
| `override-or-pin` | Any | Auto or Manual | Pin/override suppresses auto-switch |
| `stale-or-refresh` | Stale | Any | Hold until fresh benchmark run |
| `failed-reassignment` | — | Any | Recover to previous known-good state |

Each scenario must remain launch-replayable and idempotent across repeated foreground transitions. Degraded scenarios (not yet implemented) must not corrupt the app state.

Future extensions to this matrix should cover context changes such as:

- environment transition, for example home Wi‑Fi to 5G
- strategy reassessment under the same provider
- provider reassessment under the same destination and environment

## Deterministic Regression Mode

Use this when you want stable regression coverage with the captured live-format fixture.

Launch environment:

```text
ROCKEROOM_RESET_STORAGE=1
ROCKEROOM_STORAGE_SUITE=live-e2e-deterministic
ROCKEROOM_USE_DEMO_FETCHER=1
ROCKEROOM_USE_DEMO_TUNNEL=1
ROCKEROOM_LIVE_E2E_SCENARIO=expert-console
ROCKEROOM_LIVE_E2E_LINK=https://example.com/live-e2e
ROCKEROOM_DEMO_SUBSCRIPTION_PAYLOAD_B64=<base64 of Tests/Fixtures/live-vless-subscription.txt>
```

Recommended XCTest coverage:

- `UITests/LiveE2EWorkflowTests.swift`
- `UITests/FirstRunOptimizeFlowTests.swift`
- `UITests/ManualPinFlowTests.swift`

## True Live Import Mode

Use this when the flow depends on a real provider URL and you need live E2E validation.

Launch environment:

```text
ROCKEROOM_RESET_STORAGE=1
ROCKEROOM_STORAGE_SUITE=live-e2e-live-provider
ROCKEROOM_USE_DEMO_TUNNEL=1
ROCKEROOM_LIVE_E2E_SCENARIO=benchmark-home
ROCKEROOM_LIVE_E2E_LINK=https://liangxin.xyz/api/v1/liangxin?OwO=c03c31babaa7f4dd1f9f45f79aecb2a2
```

Notes:

- omit `ROCKEROOM_USE_DEMO_FETCHER` so the app performs the real fetch
- keep `ROCKEROOM_USE_DEMO_TUNNEL=1` unless you are explicitly validating the system tunnel path
- this validates real provider compatibility while keeping simulator execution deterministic enough to inspect

## Manual Debug Overlay Mode

Use this when you are driving the simulator by hand and want one-tap import without relying on paste.

What it does:

- `Reset app` clears imported subscription, benchmark snapshot, tunnel session, pin state, and destination assignments
- `Import demo subscription` imports a built-in deterministic subscription, starts a simulator-safe manual debug runtime session, and lands on normal `Home`
- `Import typed URL` takes the URL you enter in the overlay, starts a simulator-safe manual debug runtime session, and runs the same import path the setup screen uses

What it does not do:

- it does not auto-benchmark on import
- it does not validate real packet tunnel IPC
- it does not seed stale, pinned, or failure states

That means the manual debug path is intended to keep the visible product flow honest while avoiding simulator-only IPC failures. Once you tap `Run Benchmark`, the app may continue foreground monitoring and auto-switching inside that session. If you need true packet tunnel validation, use the explicit launch-driven/runtime path instead of the manual debug overlay.

## XcodeBuildMCP Workflow

1. Set session defaults for the project, scheme, and simulator.
2. Use `build_run_sim` when the scheme is healthy.
3. If you need explicit control, use `build_sim`, `install_app_sim`, and `launch_app_sim`.
4. Capture evidence with `snapshot_ui`, `screenshot`, and log capture tools.

Checks to inspect per flow:

- `import-home`: setup screen disappears and `Home` tab shell appears
- `benchmark-home`: recommendation card shows measured state, adaptive routing summary, route-context-aware messaging, and populated metrics
- `expert-console`: ranked candidates render and route-context control state is visible
- `pin-unpin-home`: app returns to `Home` with no pinned banner and recommendation restored
- `stale-hint`: refresh hint is visible after relaunch with old evidence
- `stale-refresh`: refresh hint clears after rerunning the benchmark
- `tunnel-failure`: recoverable failure text is visible on `Home`
- `tunnel-recovery`: benchmark succeeds on the next launch and tunnel state returns to running

### Destination-Aware Routing Scenario Checks

These checks validate the destination-routing state contract in Sprint 2 and later. The harness seeds persisted `DestinationRoutingAssignments` into the store before `restoreState()` so the app can restore routing context across launches.

- `auto-mode-apply`: app restores with `destinationAssignment.mode == .auto` and shows recommended setup or switched route state
- `manual-mode-advisory`: app restores with `destinationAssignment.mode == .manual` and surfaces expert console
- `override-or-pin`: app restores with pinned provider active and shows pinned banner
- `stale-or-refresh`: app restores with stale evidence and shows refresh hint
- `failed-reassignment`: app restores with recoverable failure state

As the route-context model expands, these checks should also prove:

- the UI can explain current provider and strategy for a destination
- switch versus hold reasons are visible in plain network terms
- environment-sensitive reassessment is visible when the product adds that dimension explicitly

## Limitations

- This workflow does not pretend to be true free-form UI automation. It is a launch-driven replay path for the most important user journeys.
- When XcodeBuildMCP exposes full interaction tools in a future session, this workflow still remains useful because it gives a deterministic fallback and a shared scenario contract for both MCP and XCTest.
