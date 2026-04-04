---
title: feat: Detail iOS sprint 3 trustworthy automation
type: feat
status: active
date: 2026-04-04
---

# feat: Detail iOS sprint 3 trustworthy automation

## Overview

This plan deepens sprint 3 from `docs/plans/2026-04-04-003-feat-ios-next-sprints-roadmap-plan.md` into an implementation-ready sprint document. Sprint 2 established runtime truth: accepted Clash subscriptions persist, tunnel session state restores on relaunch, and the first real import -> optimize -> restore flow now passes.

Sprint 3 should turn that runtime truth into trustworthy automation:
- persist the latest measured snapshot and manual pin intent
- coordinate foreground refresh and stale-state handling instead of treating every snapshot as session-local
- make Expert Console interactive enough to inspect ranked candidates and pin or unpin the active choice
- keep Auto Mode and Expert Console aligned on the same recommendation, freshness, and hold reasons
- replace the remaining skipped pin/console UI tests with real regression coverage

## Problem Frame

The current product has durable subscription and tunnel-session truth, but recommendation truth is still fragile. `Shared/Engine/ResultSnapshotStore.swift` is still in-memory only, `App/ExpertConsole/ExpertConsoleViewModel.swift` is read-only, and `UITests/ManualPinFlowTests.swift` is still fully skipped. `App/AutoMode/AutoModeViewModel.swift` already exposes `pinCurrentProvider()` and `unpinCurrentProvider()`, but those controls are not yet wired into the UI and the pin state is not restored across launches.

That leaves four trust gaps:
- the latest recommendation evidence disappears on relaunch because snapshots are not durable
- stale snapshots are not explicitly coordinated against foreground re-entry or manual refresh behavior
- manual override is implemented in policy but not actually reachable as product behavior
- Expert Console can display evidence but cannot yet act as the technical inspect surface promised by the design review

Sprint 3 should close those gaps without pulling in later-sprint marketplace evidence work or the observability spike.

## Requirements Trace

- R1. Persist the latest `ResultSnapshot` so Auto Mode and Expert Console can restore evidence and freshness state after relaunch.
- R2. Persist manual pin state so a user-selected override survives app lifecycle transitions until explicitly cleared.
- R3. Introduce a refresh coordinator that decides when restored snapshots remain current, when they become stale, and when an explicit or foreground refresh should run.
- R4. Keep Auto Mode honest when restored evidence is stale, partial, or refresh fails; it must not present old measurements as newly current.
- R5. Make Expert Console interactive: show ranked candidates, hold reasons, and pin/unpin controls that drive the shared recommendation policy.
- R6. Preserve the fixed product invariant that pin means no auto-switch until unpinned.
- R7. Replace the skipped Expert Console and manual pin UI tests with executable end-to-end coverage.
- R8. Keep the shared snapshot and centralized recommendation policy as the only sources of truth for all trust messaging.

## Scope Boundaries

- No marketplace evidence expansion beyond the existing teaser
- No observability-spike conclusions or deeper per-app telemetry claims
- No background task scheduler or silent background optimization loop
- No major visual redesign outside the existing Auto Mode and Expert Console surfaces
- No new tunnel-runtime primitives beyond consuming the restored session truth from sprint 2

## Context & Research

### Relevant Code and Patterns

- `App/AutoMode/AutoModeViewModel.swift` already owns the main product state transitions for subscription, tunnel runtime, snapshot, recommendation state, and pin state. It remains the correct orchestration seam for sprint 3.
- `Shared/Engine/RecommendationPolicy.swift` already centralizes the pinned, stale, low-confidence, and insignificant-delta hold logic. Sprint 3 should keep expanding around this policy instead of duplicating decisions in view models.
- `Shared/Engine/ResultSnapshotStore.swift` is currently an actor with in-memory state only, which makes it the clearest place to add durable snapshot persistence rather than inventing a second storage abstraction.
- `App/ExpertConsole/ExpertConsoleViewModel.swift` currently consumes snapshot, recommendation state, and pin state from Auto Mode. That is the correct flow direction; the console should dispatch actions back to Auto Mode, not create a second recommendation engine.
- `App/AppRootView.swift` already acts as the coordination layer between Auto Mode and Expert Console navigation and state handoff.
- `UITests/ManualPinFlowTests.swift` and `UITests/FirstRunOptimizeFlowTests.swift` are the right executable surfaces to complete rather than replacing them with a different UI harness.
- `project.yml` now separates `SharedKitTests`, `RockeRoomAppTests`, and `RockeRoomUITests`, so sprint-3 test coverage can be added without reintroducing hosted-test bundle collisions.

### Institutional Learnings

- There is still no `docs/solutions/` knowledge base, so the strongest local guidance remains the approved roadmap and the now-landed sprint-2 runtime implementation.
- Sprint-2 work already established a useful pattern: persist user-intent and runtime truth separately, then restore them in `RockeRoomApp` before the user interacts with the home screen.

### External References

- No new external research is needed for this sprint. The codebase now has direct local patterns for restore-time persistence, shared policy evaluation, and app/extension boundary handling, and sprint 3 does not introduce a new framework or third-party integration surface.

## Key Technical Decisions

- **Persist snapshot truth separately from tunnel truth:** snapshot evidence and tunnel runtime are related but not identical. A running tunnel can coexist with stale evidence, and the UI must express that difference honestly.
- **Persist pin intent explicitly:** manual override is user intent, not derived state. It should survive relaunch until the user unpins, even if the best candidate changes underneath it.
- **Introduce a dedicated refresh coordinator instead of adding more branching to `AutoModeViewModel`:** restore-time and foreground refresh rules are now their own concern and should be centralized in one place.
- **Keep Expert Console as a consumer plus action dispatcher:** the console can inspect rankings and dispatch pin/unpin actions, but the shared policy still decides whether the app is recommended, held, or rejected.
- **Do not auto-refresh silently in the background:** sprint 3 should coordinate foreground restore and explicit optimize/refresh actions only. Background scheduling and marketplace evidence remain later-sprint concerns.
- **Keep the stable test split from sprint 2:** app-hosted restore tests, pure shared-engine tests, and UI tests should remain separate targets.

## Open Questions

### Resolved During Planning

- **Should pin state persist?** Yes. Manual override is explicit user intent and should survive relaunch until the user clears it.
- **Should a restored stale snapshot disappear on launch?** No. The app should restore it immediately with stale messaging, then coordinate the next eligible refresh.
- **Should Expert Console own ranking logic?** No. It remains a read/write consumer of shared state, with recommendation decisions still made by `RecommendationPolicy`.
- **Should sprint 3 introduce background refresh?** No. Explicit optimize and foreground re-entry are sufficient for this sprint.

### Deferred to Implementation

- **Exact persistence format for snapshot and pin state:** whether the existing persistence store is extended directly or wrapped in another small repository can be finalized during implementation.
- **Exact foreground refresh debounce rules:** the plan requires restore-time freshness evaluation and coordinated refresh behavior, but the final debounce/window values can be tuned while wiring tests.
- **How much candidate detail to show in Expert Console rows:** the plan requires ranked candidates, current selection, and hold/pin affordances; the exact row layout can be finalized during UI implementation.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```text
App launch / foreground
  -> load stored subscription
  -> load stored tunnel session
  -> load stored result snapshot
  -> load stored pin state
  -> RefreshCoordinator.evaluate(...)
        ├── snapshot current enough
        │     -> restore recommendation immediately
        ├── snapshot stale but usable
        │     -> restore held/recommended state with stale messaging
        │     -> allow explicit/foreground refresh path
        └── snapshot unusable
              -> clear recommendation proof but preserve runtime truth

Expert Console action
  -> user pins candidate / unpins active choice
  -> AutoModeViewModel updates persisted pin state
  -> RecommendationPolicy re-evaluates same shared snapshot
  -> Auto Mode + Expert Console both reflect the same hold/recommendation output
```

## Implementation Units

- [ ] **Unit 1: Persist snapshot and manual-pin state**

**Goal:** Make the latest recommendation evidence and manual override intent durable across relaunch.

**Requirements:** R1, R2, R4, R6, R8

**Dependencies:** Sprint 2 runtime-truth implementation

**Files:**
- Modify: `Shared/Engine/ResultSnapshotStore.swift`
- Create: `Shared/Engine/PinStateStore.swift`
- Modify: `Shared/Engine/ResultSnapshot.swift`
- Modify: `Shared/Domain/RecommendationState.swift`
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Test: `Tests/ResultSnapshotStoreTests.swift`
- Test: `Tests/PinningPolicyTests.swift`
- Test: `Tests/AutoModeViewModelTests.swift`

**Approach:**
- Extend `ResultSnapshotStore` from in-memory-only storage into durable local persistence with restore and clear behavior.
- Add a small persisted store for `PinState` instead of deriving pinning from the snapshot or UI selection.
- Restore both snapshot and pin state during launch so `AutoModeViewModel.restoreState()` can evaluate the recommendation immediately from durable state.
- Keep restored evidence distinct from refreshed evidence by preserving `generatedAt`, `freshness`, and `isPartial` semantics.

**Execution note:** Start with failing persistence tests for snapshot restore and pin-state restore before changing launch behavior.

**Patterns to follow:**
- Follow the separate persistence seams already established by `SubscriptionRepository` and `TunnelSessionStore`.
- Reuse `RecommendationPolicy.evaluate(snapshot:pinState:)` rather than adding launch-time recommendation branching.

**Test scenarios:**
- Happy path: a measured snapshot persists and restores with the same candidate ordering, confidence, freshness, and partial-state values.
- Happy path: pinning the current candidate persists and restores as `.pinned(candidateID:)` after app relaunch.
- Edge case: restoring a snapshot with no selected candidate still allows policy evaluation from the best ranked candidate.
- Edge case: clearing stored state removes both snapshot and pin data without affecting stored subscription or tunnel session truth.
- Error path: corrupted persisted snapshot falls back to empty snapshot state without crashing and without wiping valid subscription state.
- Integration: restoring snapshot plus pin state yields a held pinned recommendation instead of a fresh auto-switch decision.

**Verification:**
- Relaunching the app restores the last known recommendation evidence and manual override state without requiring a new optimize run.

- [ ] **Unit 2: Add refresh coordination and stale-state mapping**

**Goal:** Turn restored snapshots into honest current/stale/degraded product behavior instead of a blind restore.

**Requirements:** R1, R3, R4, R8

**Dependencies:** Unit 1

**Files:**
- Create: `Shared/Engine/RefreshCoordinator.swift`
- Modify: `Shared/Engine/RecommendationPolicy.swift`
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Modify: `App/RockeRoomApp.swift`
- Modify: `App/AutoMode/AutoModeView.swift`
- Test: `Tests/FreshnessRegressionTests.swift`
- Test: `Tests/RecommendationPolicyTests.swift`
- Test: `Tests/AppSessionRestoreTests.swift`

**Approach:**
- Add a coordinator that evaluates restored snapshot age, tunnel-session state, and app lifecycle triggers to decide whether a snapshot is current, stale-but-usable, or requires explicit refresh.
- Use the coordinator to drive foreground refresh behavior and stale messaging instead of encoding those rules inline in SwiftUI or ad hoc in `AutoModeViewModel`.
- Keep Auto Mode simplified: it should surface stale evidence and hold reasons clearly, but not expose console-level detail about every missing signal.
- Preserve the last usable snapshot during refresh failure so the app degrades honestly instead of blanking all proof.

**Technical design:** *(directional guidance, not implementation specification)*

```text
RefreshCoordinator.evaluate(snapshot, tunnelStatus, trigger)
  -> if no snapshot: no restoreable evidence
  -> if snapshot stale and tunnel running:
       state = stale_usable
       refresh eligibility = true
  -> if snapshot stale and tunnel stopped:
       state = stale_hold
       refresh eligibility = explicit only
  -> if snapshot current:
       state = current
```

**Patterns to follow:**
- Extend the existing freshness semantics in `RecommendationPolicy` rather than inventing a second stale-threshold model in the UI.
- Follow the existing `RockeRoomApp` restore path that seeds view models before the user acts.

**Test scenarios:**
- Happy path: restored current snapshot maps to the same recommended state on launch with no stale warning.
- Happy path: foreground re-entry with a stale but usable snapshot marks the UI stale and makes refresh eligible without clearing evidence.
- Edge case: partial snapshot remains visible with partial/stale messaging instead of presenting as full-confidence proof.
- Edge case: foreground restore with running tunnel and no snapshot does not fabricate recommendation proof.
- Error path: refresh failure keeps the last usable snapshot visible while surfacing degraded state and preserving tunnel truth.
- Integration: launch restore followed by explicit optimize replaces stale proof with current proof and updated freshness text.

**Verification:**
- The app can distinguish restored current evidence from restored stale evidence, and refresh behavior is coordinated from one shared seam.

- [ ] **Unit 3: Complete Expert Console interaction and pin/unpin flows**

**Goal:** Make Expert Console a real inspect/control surface for ranked candidates and manual override.

**Requirements:** R2, R5, R6, R8

**Dependencies:** Units 1-2

**Files:**
- Modify: `App/AppRootView.swift`
- Modify: `App/ExpertConsole/ExpertConsoleViewModel.swift`
- Modify: `App/ExpertConsole/ExpertConsoleView.swift`
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Modify: `App/AutoMode/AutoModeView.swift`
- Test: `Tests/AutoModeViewModelTests.swift`
- Test: `Tests/RecommendationPolicyTests.swift`
- Test: `UITests/ManualPinFlowTests.swift`

**Approach:**
- Expand `ExpertConsoleViewModel` to expose ordered candidates, current active candidate, recommendation hold reason, and pin/unpin affordances sourced from the same restored snapshot and policy outputs as Auto Mode.
- Pass pin and unpin actions from `AppRootView` into the console surface so the console dispatches user intent back to `AutoModeViewModel`.
- Keep Auto Mode calm by showing only the simplified pinned/held summary, while Expert Console exposes the ranked list and richer explanation.
- Ensure unpin immediately re-evaluates the same snapshot through `RecommendationPolicy` so Auto Mode and Expert Console converge on the same post-unpin state.

**Patterns to follow:**
- Follow the existing `AppRootView` pattern of handing shared state from Auto Mode into Expert Console on navigation.
- Reuse `AutoModeViewModel.pinCurrentProvider()` and `unpinCurrentProvider()` semantics rather than creating console-local override state.

**Test scenarios:**
- Happy path: Expert Console opens from Auto Mode and displays the same current recommendation, confidence, and freshness state.
- Happy path: user pins the active candidate in Expert Console and Auto Mode immediately shows the pinned hold summary.
- Happy path: user unpins and the recommendation re-evaluates from the current snapshot without requiring a new optimize run.
- Edge case: opening Expert Console with no snapshot shows an inspectable empty state without exposing dead controls.
- Edge case: opening Expert Console with stale snapshot shows stale labels and hold reasoning consistent with Auto Mode.
- Error path: attempting to pin when no measurable candidate exists leaves pin state unchanged and surfaces a disabled or inert control path.
- Integration: pin survives relaunch, reopening Expert Console still shows the pinned candidate, and unpin resumes auto recommendation control.

**Verification:**
- Expert Console becomes a real secondary inspect surface with working pin/unpin behavior, and Auto Mode remains in lockstep with it.

- [ ] **Unit 4: Replace skipped UI coverage with real trust-regression tests**

**Goal:** Lock sprint-3 trust behavior behind stable unit, app-hosted, and UI regression coverage.

**Requirements:** R4, R5, R6, R7, R8

**Dependencies:** Units 1-3

**Files:**
- Modify: `UITests/ManualPinFlowTests.swift`
- Modify: `UITests/FirstRunOptimizeFlowTests.swift`
- Modify: `Tests/FreshnessRegressionTests.swift`
- Modify: `Tests/PinningPolicyTests.swift`
- Modify: `Tests/AppSessionRestoreTests.swift`
- Modify: `project.yml`

**Approach:**
- Replace skipped `ManualPinFlowTests` with real end-to-end console navigation and pin/no-auto-switch assertions.
- Add restore-and-stale coverage to the app-hosted and shared-engine tests so launch-time truth is proven outside the UI harness where possible.
- Keep the stable target split from sprint 2: pure shared logic in `SharedKitTests`, hosted restore logic in `RockeRoomAppTests`, and UI navigation/control assertions in `RockeRoomUITests`.
- Prefer deterministic demo fetch/probe/tunnel environment flags in UI tests rather than introducing new ad hoc fixtures.

**Patterns to follow:**
- Follow the now-stable `FirstRunOptimizeFlowTests` structure: preset demo link buttons, deterministic launch environment, and sequential simulator execution.
- Preserve the split test-target pattern now encoded in `project.yml`.

**Test scenarios:**
- Happy path: Auto Mode -> Expert Console navigation succeeds and shows ranked evidence rows from the shared snapshot.
- Happy path: user pins from Expert Console, returns to Auto Mode, and sees pinned hold messaging instead of a free auto-switch state.
- Happy path: relaunch restores pinned state and stale/current snapshot messaging correctly.
- Edge case: restored stale snapshot still allows navigation to Expert Console and shows stale indicators in both surfaces.
- Edge case: unpin while the current snapshot still favors the same candidate does not produce a false switch animation or state change.
- Error path: refresh failure after restore preserves last-known evidence and shows degraded messaging rather than clearing the console.
- Integration: full flow import -> optimize -> open console -> pin -> relaunch -> unpin remains policy-consistent end to end.

**Verification:**
- The remaining skipped sprint-1 shell tests are replaced with real executable trust-regression coverage, and the combined `RockeRoom` scheme remains green.

## System-Wide Impact

- **Interaction graph:** `RockeRoomApp` restores persisted subscription, tunnel, snapshot, and pin state into `AutoModeViewModel`; `AppRootView` hands that state into `ExpertConsoleViewModel`; `RecommendationPolicy` remains the only source of recommend/hold/reject decisions.
- **Error propagation:** snapshot-restore or refresh failures should degrade to honest stale or unavailable evidence states without clearing valid subscription or tunnel runtime truth.
- **State lifecycle risks:** stale snapshot restore, pin persistence, and explicit unpin all risk split-brain UI if state is persisted in more than one place; sprint 3 avoids that by keeping persistence in shared stores and decisions in the shared policy.
- **API surface parity:** Auto Mode, Expert Console, and later marketplace evidence must all continue consuming the same snapshot/policy outputs; sprint 3 should not add a console-only ranking model.
- **Integration coverage:** restore -> stale mapping, pin persistence across relaunch, and unpin re-evaluation are the cross-layer scenarios most likely to regress without explicit app-hosted and UI coverage.
- **Unchanged invariants:** Clash subscription validation, tunnel-session lifecycle, and packet-tunnel config handoff from sprint 2 stay unchanged; sprint 3 layers durable recommendation truth on top of that runtime base.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Snapshot persistence drifts from recommendation policy expectations | Keep `RecommendationPolicy` as the sole evaluator and test restored snapshots through the same path used after optimize |
| Pin state becomes UI-local and diverges from restored state | Persist pin intent in a dedicated shared store and rehydrate it before any console or Auto Mode render |
| Foreground refresh rules become scattered across views and view models | Centralize restore-time and refresh eligibility decisions in `RefreshCoordinator` |
| UI tests become flaky again | Reuse the stable deterministic launch-environment pattern from sprint 2 and keep UI tests sequential |

## Documentation / Operational Notes

- Update `docs/plans/2026-04-04-003-feat-ios-next-sprints-roadmap-plan.md` only if sprint-3 implementation changes sprint-4 marketplace assumptions about snapshot shape or pin-state availability.
- If refresh coordination introduces new app lifecycle assumptions, capture them in repo docs near the end of implementation rather than leaving them implicit in view-model code.

## Sources & References

- Related plan: `docs/plans/2026-04-04-003-feat-ios-next-sprints-roadmap-plan.md`
- Related plan: `docs/plans/2026-04-04-004-feat-ios-sprint-2-runtime-truth-plan.md`
- Related checklist: `docs/plans/2026-04-04-005-feat-ios-sprint-2-runtime-truth-checklist.md`
- Related code: `App/AutoMode/AutoModeViewModel.swift`
- Related code: `App/ExpertConsole/ExpertConsoleViewModel.swift`
- Related code: `Shared/Engine/ResultSnapshotStore.swift`
- Related code: `Shared/Engine/RecommendationPolicy.swift`
