---
title: fix: Restore debug runtime parity for manual testing
type: fix
status: completed
date: 2026-04-05
related:
  - docs/plans/2026-04-05-001-fix-debug-overlay-real-input-plan.md
  - docs/plans/2026-04-05-002-fix-debug-overlay-auto-dismiss-plan.md
  - docs/plans/2026-04-04-015-feat-live-e2e-workflow-plan.md
---

# fix: Restore debug runtime parity for manual testing

## Overview

The current debug overlay solves input injection, but it still breaks the user’s actual goal: tap `Debug`, import a URL, and then use the app normally without falling into system tunnel IPC failures on the simulator. That mismatch exists because RockeRoom currently treats runtime mode as a process-launch concern instead of an app-session concern. Import source is switchable from the UI, but benchmark runtime is still locked to whichever adapter and probe executor were chosen at app startup.

This fix redefines the debug contract around session-level runtime parity. In debug-assisted manual testing, the UI flow must stay the same as a real user flow after import, while the runtime backend becomes explicitly switchable to a simulator-safe profile. The user should not need to know or care about environment variables to make `Run Benchmark` usable after tapping `Debug`.

## Problem Frame

The user expectation is simple: `Debug` should make manual testing easier, not require understanding internal launch flags. Today the architecture violates that expectation in two ways:

- `AppRootView` can inject import input from the debug overlay, but it cannot switch the benchmark backend that `AutoModeViewModel.optimize()` uses.
- `AutoModeViewModel` chooses importer and tunnel implementations once during initialization via static environment checks, so the benchmark path is effectively hard-wired before the user ever taps `Debug`.

As a result, manual testers can successfully import through the overlay and still hit the real `SystemTunnelManager` IPC path on `Run Benchmark`, which feels like a broken debug feature rather than an intentional product/testing boundary.

The issue is architectural. Testability and manual-debug parity are low because runtime dependencies are selected through global launch environment rather than through an injectable runtime profile the UI can activate intentionally.

## Requirements Trace

- R1. Tapping `Debug` must let a manual tester reach a usable post-import benchmark flow without needing launch environment knowledge.
- R2. After debug activation, the visible app flow must remain the same as a real user flow: import, land on `Home`, tap `Run Benchmark`, inspect `Expert Console`, pin/unpin, refresh, and recover.
- R3. The benchmark path used after debug activation must not depend on the real simulator tunnel IPC path unless the tester explicitly chooses that mode.
- R4. The app must make runtime mode selection an explicit app-level dependency decision instead of a hidden process-env side effect.
- R5. Launch-driven live E2E scenarios and true system-tunnel validation must continue to exist as separate contracts.
- R6. Debug-assisted mode must remain honest about what is simulated versus what is real enough to support manual product testing.
- R7. The fix must improve testability by giving tests and manual debug flows the same injectable runtime seam.

## Scope Boundaries

- No removal of true system-tunnel validation paths.
- No promise that simulator manual testing proves real packet tunnel IPC health.
- No broad rewrite of recommendation, ranking, or routing logic.
- No attempt to merge manual debug overlay behavior with launch-driven scenario replay.
- No new fake end-state seeding for stale, pinned, or failure views.

## Context & Research

### Relevant Code and Patterns

- `App/RockeRoomApp.swift` constructs `AutoModeViewModel` once through `AppEnvironment.makeAutoModeViewModel()`, making composition root changes the correct fix point.
- `App/AutoMode/AutoModeViewModel.swift` currently hard-codes dependency selection through `makeImporter()` and `makeAdapter(...)`, driven by process environment.
- `Shared/Engine/ClashAdapter.swift` already exposes a clean seam between `SystemTunnelManager` and `InMemoryTunnelManager`; the problem is how that seam is selected, not that it is missing.
- `docs/testing/live-e2e-workflow.md` already distinguishes manual overlay use from launch-driven live E2E and explicitly tells testers to keep `ROCKEROOM_USE_DEMO_TUNNEL=1` for simulator-friendly flows.
- `Tests/AutoModeViewModelTests.swift` and `UITests/LiveE2EWorkflowTests.swift` already cover debug import/reset flows and are the right places to extend runtime-parity coverage.

### Institutional Learnings

- Recent debug overlay work proved that overlay-level UX patches are not enough when the underlying session/runtime contract is wrong.
- The live E2E workflow already uses simulator-safe runtime toggles successfully; the missing piece is exposing the same runtime seam to manual debug flows through app composition instead of launch flags only.

### External References

- None. The issue is repo-local and the existing code already contains the needed runtime abstraction seam.

## Key Technical Decisions

- **Move runtime selection to the composition root:** `RockeRoomApp` / `AppEnvironment` should build a runtime profile object and inject it into `AutoModeViewModel` rather than letting the view model read global environment for core behavior.
- **Treat debug as a session profile, not a button side effect:** tapping `Debug` should activate a manual-debug runtime profile that survives import and drives later benchmark actions.
- **Keep UI parity, not infrastructure parity:** the user-facing flow after import stays identical, while the backend uses simulator-safe tunnel/probe implementations unless the tester explicitly requests true system runtime.
- **Preserve explicit truth boundaries:** true system-tunnel testing remains available, but it becomes an explicit mode instead of an accidental consequence of missing launch flags.
- **Share the seam across tests and manual debug:** the same runtime-profile abstraction should support app tests, UI tests, and manual simulator usage.

## Open Questions

### Resolved During Planning

- **Is this just a debug overlay wording problem?** No. The overlay is exposing an architectural mismatch between UI intent and runtime dependency selection.
- **Is low testability part of the root cause?** Yes. The runtime seam exists in the engine layer, but the current composition pattern hides it behind process-wide environment decisions, which lowers manual-debug parity and testability.
- **Should true system-tunnel validation disappear from the app?** No. It should remain available as an explicit mode.

### Deferred to Implementation

- **Exact UX for runtime selection:** implementation may use a one-time `Debug session` action, a simple mode picker inside the overlay, or a persisted debug session toggle, as long as the default manual-debug path becomes usable without environment knowledge.
- **Whether debug runtime state persists across relaunchs:** implementation may choose ephemeral-per-launch or persisted-per-storage-suite behavior based on what best matches current manual testing patterns.
- **How probe realism is communicated:** implementation can decide whether simulator-safe benchmark results need a small debug badge or copy treatment, as long as they are not confused with real tunnel IPC validation.

## High-Level Technical Design

> This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.

```text
App launch
  -> AppEnvironment builds RuntimeProfile
     -> importer strategy
     -> tunnel strategy
     -> probe strategy
     -> debug/session metadata
  -> AutoModeViewModel receives injected runtime profile

User taps Debug
  -> debug session intent activates ManualDebug RuntimeProfile
  -> overlay injects real or deterministic import input
  -> Home remains unchanged visually
  -> Run Benchmark uses injected simulator-safe tunnel/probe backend
  -> Expert Console / pin / refresh continue through normal app logic

Explicit true-runtime validation
  -> separate profile or launch path
  -> uses real SystemTunnelManager
  -> failures represent real IPC/tunnel truth
```

## Implementation Units

- [x] **Unit 1: Introduce an app-level runtime profile and stop selecting core dependencies inside `AutoModeViewModel`**

**Goal:** Make importer, tunnel, and probe behavior explicit injected dependencies rather than hidden launch-env decisions inside the view model.

**Requirements:** R3, R4, R7

**Dependencies:** None

**Files:**
- Modify: `App/RockeRoomApp.swift`
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Modify: `Shared/Engine/ClashAdapter.swift`
- Test: `Tests/AutoModeViewModelTests.swift`

**Approach:**
- Introduce a small runtime-profile concept at the app composition layer that determines which importer, tunnel manager, and probe executor are injected.
- Refactor `AutoModeViewModel` so its initializer accepts fully constructed dependencies or a profile-derived bundle, instead of calling `makeImporter()` and `makeAdapter(...)` internally.
- Keep environment variables as one way to choose a profile at app launch, but no longer as the only way to affect runtime behavior.
- Ensure the default non-debug profile still maps to today’s production path.

**Execution note:** Start with characterization coverage around current dependency selection so the refactor proves no unintended behavior drift in non-debug mode.

**Patterns to follow:**
- Follow the existing `AppEnvironment.makeAutoModeViewModel()` composition seam in `App/RockeRoomApp.swift`.
- Reuse the existing `TunnelManaging` and `ClashEngine` seams in `Shared/Engine/ClashAdapter.swift` rather than inventing a second abstraction layer.

**Test scenarios:**
- Happy path: default app composition still produces the current production runtime profile.
- Happy path: a simulator-safe profile injects an in-memory tunnel/runtime path without changing the rest of the view model API.
- Edge case: restoring stored state under a debug profile does not overwrite the selected runtime profile.
- Error path: explicit true-runtime profile still surfaces tunnel startup failures unchanged.
- Integration: `optimize()` uses the injected tunnel behavior rather than consulting process environment directly.

**Verification:**
- Runtime behavior can be selected by composition, and `AutoModeViewModel` no longer hides core runtime choices behind static factory helpers.

- [x] **Unit 2: Make the debug overlay activate a manual-debug runtime session, not just inject import input**

**Goal:** Align the `Debug` affordance with the user expectation that the rest of the app becomes manually testable after import.

**Requirements:** R1, R2, R3, R6

**Dependencies:** Unit 1

**Files:**
- Modify: `App/AppRootView.swift`
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Modify: `App/Home/SetupHomeView.swift`
- Test: `UITests/LiveE2EWorkflowTests.swift`
- Test: `Tests/AutoModeViewModelTests.swift`

**Approach:**
- Redefine the overlay action from “import source only” to “start debug session + import source”.
- When the user chooses a debug import path, activate the simulator-safe runtime profile before import so the following `Run Benchmark` action uses the same visible UI flow with a usable backend.
- Keep the overlay narrow: reset, start debug session with deterministic import, start debug session with typed live URL, and optionally an explicit “true runtime” action only if needed for parity.
- Avoid reintroducing fake benchmarked or stale end-state seeding.

**Patterns to follow:**
- Preserve the current parent-owned overlay presentation in `App/AppRootView.swift`.
- Reuse the existing import/reset flow and current accessibility identifiers where possible.

**Test scenarios:**
- Happy path: tapping debug import from setup activates the debug session, imports successfully, lands on `Home`, and a subsequent benchmark runs without system IPC failure.
- Happy path: tapping debug import with a typed live URL follows the same visible import success flow as today.
- Edge case: reopening debug from imported `Home` keeps the same runtime session unless reset or explicitly changed.
- Error path: bad URL import still shows the normal import error and does not leave the runtime session in a partially activated state.
- Integration: the overlay no longer needs launch env to make benchmark usable in the simulator after a debug import.

**Verification:**
- A manual tester can tap `Debug`, import, tap `Run Benchmark`, and continue through the app without needing any environment-variable knowledge.

- [x] **Unit 3: Separate manual-debug runtime, launch-driven E2E runtime, and true system runtime as explicit modes**

**Goal:** Prevent future confusion by making the three testing/runtime contracts explicit in code and docs.

**Requirements:** R3, R5, R6, R7

**Dependencies:** Units 1-2

**Files:**
- Modify: `App/RockeRoomApp.swift`
- Modify: `docs/testing/live-e2e-workflow.md`
- Modify: `README.md`
- Test: `UITests/LiveE2EWorkflowTests.swift`
- Test: `Tests/LiveE2EScenarioTests.swift`

**Approach:**
- Define three explicit runtime modes in code and documentation:
  - normal production/system runtime
  - manual debug-assisted runtime
  - launch-driven E2E/runtime-test profile
- Ensure manual debug activation does not interfere with launch-driven scenario replay.
- Clarify which mode is meant to validate real provider import, real packet tunnel IPC, or just product-flow usability on simulator.
- Keep the live E2E docs aligned with the new composition seam instead of continuing to explain behavior mostly through raw env vars.

**Patterns to follow:**
- Follow the current separation in `docs/testing/live-e2e-workflow.md` between deterministic launch-driven scenarios and manual overlay use.
- Preserve current scenario names and replay semantics in `LiveE2ERunner`/`LiveE2EScenario`.

**Test scenarios:**
- Happy path: launch-driven live E2E scenario still works without opening the debug overlay.
- Happy path: manual debug-assisted benchmark flow works from setup through `Expert Console` on simulator.
- Edge case: switching storage suites or relaunching does not accidentally leak one runtime mode into another unless explicitly designed.
- Error path: true-runtime validation mode still surfaces real IPC failure when that path is intentionally exercised.
- Integration: docs and tests agree on which mode is expected to use `SystemTunnelManager` versus simulator-safe runtime.

**Verification:**
- The codebase and docs expose one coherent runtime story instead of mixing UI-driven debug expectations with launch-env-only runtime behavior.

- [x] **Unit 4: Add simulator-backed parity regression coverage for the complete manual debug path**

**Goal:** Lock in the user-facing expectation that `Debug` produces a usable manual test session, not just a successful import.

**Requirements:** R1, R2, R3, R7

**Dependencies:** Units 2-3

**Files:**
- Modify: `UITests/LiveE2EWorkflowTests.swift`
- Modify: `Tests/AutoModeViewModelTests.swift`
- Modify: `docs/plans/2026-04-05-002-fix-debug-overlay-auto-dismiss-plan.md`

**Approach:**
- Extend the current overlay tests past import into benchmark and console assertions.
- Add focused tests that prove the benchmark path behaves differently under debug-assisted runtime versus true-runtime validation mode.
- Keep simulator-backed proof as the acceptance bar for the manual debug contract.

**Execution note:** Characterize the failing current benchmark-after-debug flow first, then replace it with the new parity contract.

**Patterns to follow:**
- Follow the current focused overlay UI tests in `UITests/LiveE2EWorkflowTests.swift`.
- Keep assertions on user-visible state rather than on implementation-only internals.

**Test scenarios:**
- Happy path: debug-assisted deterministic import -> `Run Benchmark` -> `Home` measured state -> `Expert Console` ranked candidates.
- Happy path: debug-assisted typed live URL import -> benchmark -> ranked candidates rendered.
- Edge case: reset clears both imported state and active debug runtime session.
- Error path: true-runtime path reproduces IPC/tunnel failure when explicitly selected.
- Integration: manual debug parity tests and launch-driven E2E tests can run in the same suite without hidden shared state.

**Verification:**
- The manual debug story is covered end-to-end by focused simulator-backed tests, not just import-only assertions.

## System-Wide Impact

- **Interaction graph:** `RockeRoomApp` composition, `AppRootView` debug activation, `AutoModeViewModel.optimize()`, tunnel manager selection, and UI test harnesses all become part of the same runtime-mode contract.
- **Error propagation:** import failures remain normal import failures; true-runtime tunnel failures remain explicit; debug-assisted runtime should not leak raw IPC failures into the default manual-debug path.
- **State lifecycle risks:** runtime-mode activation must reset cleanly so stored app state does not silently bind to the wrong backend across sessions.
- **API surface parity:** launch env, manual overlay, and test initialization should all map onto the same runtime-profile model instead of each inventing its own toggle logic.
- **Integration coverage:** simulator-backed tests must prove mode selection, import, benchmark, and console progression together.
- **Unchanged invariants:** the visible product flow, recommendation logic, and real system-tunnel validation path should remain intact.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Runtime-profile refactor accidentally changes non-debug production behavior | Characterize current default composition and keep the default profile mapped to today’s production dependencies |
| Manual debug mode becomes another hidden fake-state system | Limit the mode to backend/runtime selection plus real import flow; do not restore seeded end-state shortcuts |
| Mode leakage across relaunchs confuses tests and manual sessions | Define explicit reset/activation lifecycle and cover it in storage-suite-based UI tests |
| Docs continue to describe env vars while the app exposes a new runtime model | Update `docs/testing/live-e2e-workflow.md` and `README.md` in the same change set |

## Documentation / Operational Notes

- Update the manual debug overlay docs to say plainly that `Debug` starts a simulator-safe manual test session.
- Keep a separate documented path for explicit real IPC/tunnel validation so engineers can still test the real system path when they want it.
- If the final UX exposes multiple runtime choices, keep the labels blunt and operational rather than product-marketing styled.

## Sources & References

- Related plan: `docs/plans/2026-04-05-001-fix-debug-overlay-real-input-plan.md`
- Related plan: `docs/plans/2026-04-05-002-fix-debug-overlay-auto-dismiss-plan.md`
- Related code: `App/RockeRoomApp.swift`
- Related code: `App/AutoMode/AutoModeViewModel.swift`
- Related code: `Shared/Engine/ClashAdapter.swift`
- Related docs: `docs/testing/live-e2e-workflow.md`
