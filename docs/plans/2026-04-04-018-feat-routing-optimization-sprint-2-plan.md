---
title: feat: Plan routing optimization sprint 2
type: feat
status: completed
date: 2026-04-04
origin: docs/brainstorms/2026-04-04-routing-optimization-core-requirements.md
supersedes:
  - docs/plans/2026-04-04-017-feat-routing-optimization-sprint-1-plan.md
---

# feat: Plan routing optimization sprint 2

## Overview

Sprint 2 is the shared-state sprint for routing optimization. Sprint 1 already locked the curated destination catalog and introduced contract tests around destination-routing semantics. This sprint turns that contract into durable production state: one destination catalog seam, one assignment model, and one persistence path that `Home`, `Auto Mode`, `Expert Console`, and later optimization code can all read without inventing parallel truth.

This sprint remains **tests-first**, but unlike Sprint 1 it does introduce production shared types and stores. It still stops short of the actual optimizer. The output is not “RockeRoom actively improves routes.” The output is “RockeRoom can represent, restore, and expose destination routing state safely enough that Sprint 3 can add optimization policy without fighting storage drift.”

Sprint 2 must also harden the Sprint 1 contract where it is still placeholder-only. If any Sprint 1 tests merely validate test-local vocabulary or no-op launch behavior, Sprint 2 should replace those weak seams with production-coupled characterization as part of introducing the real shared assignment model.

## Problem Frame

The current repo now has three important things in place:

- `Shared/Domain/RoutingDestination.swift` defines the curated destination identity seam.
- `Tests/DestinationRoutingContractTests.swift` and `Tests/RoutingOptimizationPolicyTests.swift` define the visible semantics later runtime code must satisfy.
- Existing persistence seams already exist for imported subscription state, tunnel session state, snapshot state, and pin state.

What is still missing is the shared production model that ties those together. Right now the app can restore a subscription, restore a benchmark snapshot, and restore a pinned provider, but it cannot restore a destination-aware routing view such as:

- which destination is being discussed
- which mode governs it
- which strategy/provider/node is currently assigned
- whether the assignment came from automatic control or user override
- when that assignment should be treated as stale or advisory

If Sprint 3 tries to add optimization behavior before that backbone exists, the optimizer will end up writing ad hoc state into view models or piggybacking on snapshot fields that were never designed for destination-aware routing. Sprint 2 prevents that.

The review risk is not only missing production state. It is also false confidence from weak contract artifacts. A test suite that passes while asserting against test-only routing structs or launch-and-terminate E2E placeholders will not protect Sprint 3. Sprint 2 therefore needs to strengthen those seams while adding the shared model, not treat them as finished.

## Requirements Trace

- R5-R8. Carry the curated destination catalog into production shared state without widening scope.
- R9-R13. Represent Auto Mode and Manual Mode as durable assignment semantics, not just test vocabulary.
- R14-R17. Create a shared model for per-destination routing assignment, override state, and restore behavior.
- R18-R20. Persist the current strategy/provider truth and the evidence linkage needed for later UI surfaces.
- R25-R27. Make the launch-driven E2E contract able to restore meaningful destination state from shared storage.

## Scope Boundaries

- No fast-pass optimizer or foreground refinement loop in this sprint.
- No automatic reassignment decisions beyond restoring and exposing persisted state.
- No full `Home` or `Expert Console` redesign; only the shared state and minimal seam updates needed so later screens can consume it.
- No external rule-pack ingestion beyond the already-curated v1 catalog.
- No background execution behavior.

## Context & Research

### Relevant Code and Patterns

- `Shared/Domain/RoutingDestination.swift` already provides the curated top-10 identity seam and deterministic catalog loader. Sprint 2 should extend from this file instead of creating a second catalog abstraction.
- `Shared/Engine/SubscriptionRepository.swift`, `Shared/Engine/ResultSnapshotStore.swift`, and `Shared/Engine/PinStateStore.swift` show the current persistence pattern: small actor-backed stores over `PersistentDataStoring`, JSON codable payloads, corruption-clearing restore semantics.
- `Shared/Engine/PersistentDataStore.swift` already gives the shared `UserDefaults` / in-memory seam Sprint 2 should reuse.
- `App/AutoMode/AutoModeViewModel.swift` currently restores subscription, pin, snapshot, and tunnel session separately. Destination-aware restoration should be integrated here through shared stores, not view-model-owned persistence logic.
- `Tests/SubscriptionRepositoryTests.swift`, `Tests/ResultSnapshotStoreTests.swift`, and `Tests/PinStateStoreTests.swift` define the repo’s preferred characterization style for storage behavior.
- `Tests/DestinationRoutingContractTests.swift` and `Tests/RoutingOptimizationPolicyTests.swift` already establish the future vocabulary. Sprint 2 should connect production types to those expectations incrementally rather than replacing the tests wholesale.

### Institutional Learnings

- The repo has already converged on “one shared truth spine” as the stabilizing pattern. Sprint 2 should keep all destination assignment persistence in shared stores, not inside screen-specific state.
- The app already uses corruption-clearing restore behavior in multiple stores. Destination routing state should degrade safely the same way instead of surfacing partially-decoded garbage.
- The observability constraint still applies. Production types may use app-labeled destinations, but they must remain rule-backed destinations, not direct app telemetry claims.

### External References

- Origin requirements: `docs/brainstorms/2026-04-04-routing-optimization-core-requirements.md`
- Sprint 1 contract: `docs/plans/2026-04-04-017-feat-routing-optimization-sprint-1-plan.md`
- User-provided template reference: `https://github.com/limbopro/Profiles4limbo`
- User-provided rule source: `https://github.com/blackmatrix7/ios_rule_script`

## Key Technical Decisions

- **Extend the existing destination seam:** `RoutingDestination` already exists, so Sprint 2 should add shared assignment types beside it instead of inventing a parallel “catalog item” model elsewhere.
- **Use one persisted assignment store:** destination routing state should be saved through one shared store with corruption-clearing semantics, mirroring existing repositories and stores.
- **Separate assignment truth from measurement truth:** persisted assignment state should reference destination identity and current route choice, while benchmark snapshots remain measurement artifacts. Do not overload `ResultSnapshot` to become the assignment model.
- **Represent manual control explicitly:** manual overrides and auto-owned assignments should be distinguishable in persisted state so Sprint 3 can reason about whether a better route is applyable or advisory.
- **Characterize restore behavior before screen adoption:** production types and stores should be tested first, then consumed by view models in the smallest possible way.

## Open Questions

### Resolved During Planning

- **Should Sprint 2 recreate the destination catalog?** No. The catalog seam already exists in `Shared/Domain/RoutingDestination.swift`.
- **Should destination-aware state live inside `ResultSnapshot`?** No. Snapshot state is measurement evidence, not durable assignment truth.
- **Should Auto vs Manual remain test-only until Sprint 3?** No. Sprint 2 should introduce production assignment semantics so later optimizer code has a real state model to act on.

### Deferred to Implementation

- **Exact type names:** whether the final shared type is one aggregate payload or a few smaller codable structs can be decided during implementation.
- **Snapshot linkage shape:** the precise way assignment state references the latest evidence snapshot can be lightweight and implementation-driven as long as assignment truth remains separate.
- **Minimal screen adoption depth:** implementation can decide whether Sprint 2 surfaces restored assignment state through one or two view-model seams, provided it does not start full UI work early.

## High-Level Technical Design

> This is directional guidance for review, not implementation specification.

```text
RoutingDestination catalog
  -> destination assignment domain types
       mode
       current strategy
       current provider/node
       assignment source (auto vs manual override)
       evidence linkage / timestamps
  -> destination assignment store
       restore
       persist
       clear corrupted payload
  -> thin view-model restore seams
       auto mode
       later home / expert console consumers

ResultSnapshot remains measurement evidence
PinState remains separate unless explicitly folded into assignment restore semantics
Optimizer behavior waits for Sprint 3
```

## Implementation Units

- [ ] **Unit 1: Introduce production destination assignment types**

**Goal:** Add shared domain types that represent per-destination routing assignment, ownership mode, and restore-safe metadata.

**Requirements:** R9-R17

**Dependencies:** Sprint 1 contract and existing `RoutingDestination` seam

**Files:**
- Modify: `Shared/Domain/RoutingDestination.swift`
- Create: `Shared/Domain/DestinationRoutingAssignment.swift`
- Modify: `Tests/DestinationRoutingContractTests.swift`
- Create: `Tests/DestinationRoutingAssignmentTests.swift`

**Approach:**
- Keep `RoutingDestination` as the identity anchor for the curated catalog.
- Add production codable types that represent:
  - destination identity
  - control mode (`auto` / `manual`)
  - current strategy and provider or node choice
  - assignment provenance such as automatic selection vs manual override
  - restore-safe timing or freshness metadata needed for later stale handling
- Connect the production vocabulary to the Sprint 1 contract carefully, without forcing UI decisions into the domain layer.
- Replace any test-local placeholder routing vocabulary that is no longer carrying real product constraints once the production types exist.

**Execution note:** Start with characterization tests that prove the assignment types can express all required semantics before adding persistence. If Sprint 1 contract tests are only asserting against test-owned structs, convert them in this unit to exercise the new production assignment vocabulary directly.

**Patterns to follow:**
- Mirror the small, codable, stable-value style already used in `Shared/Domain/StoredSubscription.swift`.
- Keep the domain vocabulary independent of `AutoModeViewModel` and current screen text.

**Test scenarios:**
- Happy path: a destination assignment can represent one curated destination, one control mode, one strategy, and one provider/node together.
- Happy path: a manual override assignment is distinguishable from an automatically-owned assignment for the same destination.
- Edge case: the fallback `Final` destination still has a stable assignment identity and does not require special casing outside the model.
- Edge case: missing optional evidence-link metadata still decodes into a safe assignment state.
- Error path: malformed or incomplete required assignment fields fail decoding predictably.
- Integration: production assignment types can satisfy the semantic expectations introduced in Sprint 1 contract tests without relying on test-only routing structs.

**Verification:**
- The repo has production domain types for destination routing state that cover Auto vs Manual and provider/strategy truth without overloading measurement models.

- [ ] **Unit 2: Add a destination assignment store with restore-safe persistence**

**Goal:** Persist and restore destination assignment state through one shared store using the repo’s existing corruption-clearing pattern.

**Requirements:** R14-R20, R26

**Dependencies:** Unit 1

**Files:**
- Create: `Shared/Engine/DestinationRoutingAssignmentStore.swift`
- Modify: `Shared/Engine/PersistentDataStore.swift`
- Create: `Tests/DestinationRoutingAssignmentStoreTests.swift`
- Modify: `Tests/SubscriptionRepositoryTests.swift`
- Modify: `Tests/ResultSnapshotStoreTests.swift`

**Approach:**
- Implement an actor-backed store over `PersistentDataStoring`, following the same style as `SubscriptionRepository`, `ResultSnapshotStore`, and `PinStateStore`.
- Persist one destination-routing payload shape owned by the shared layer.
- Make corrupted payloads self-clearing on restore rather than leaking partial state.
- Keep storage ownership centralized so future optimizer code and screen code read the same persisted truth.

**Execution note:** Write store restore/clear/corruption tests before implementing the store methods.

**Patterns to follow:**
- Mirror the persistence seams already used by `SubscriptionRepository`, `ResultSnapshotStore`, and `PinStateStore`.
- Preserve the current in-memory data store testing pattern for deterministic tests.

**Test scenarios:**
- Happy path: the assignment store restores a persisted destination assignment payload unchanged.
- Happy path: multiple destination assignments persist without losing mode or provider/strategy relationships.
- Edge case: updating one destination assignment does not silently drop other destinations in the same persisted payload.
- Edge case: clearing the store removes all destination assignment state and leaves restore empty.
- Error path: corrupted assignment payload is cleared from storage and restore returns an empty or safe default state.
- Integration: assignment persistence uses the same `PersistentDataStoring` seam as the existing stores, so app-session restore tests can share one in-memory backing store.

**Verification:**
- The shared layer can persist and restore destination routing assignments reliably through one store.

- [ ] **Unit 3: Wire destination restore state into shared app flow seams**

**Goal:** Thread the new destination assignment store into the existing app restore path without starting optimizer behavior.

**Requirements:** R18-R20, R25-R27

**Dependencies:** Units 1-2

**Files:**
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Modify: `Tests/AutoModeViewModelTests.swift`
- Modify: `Tests/AppSessionRestoreTests.swift`
- Modify: `Shared/Engine/EvidenceProjection.swift`

**Approach:**
- Inject the assignment store into `AutoModeViewModel` alongside the existing subscription, snapshot, tunnel, and pin stores.
- Restore destination assignment truth during app/session restore so the app can carry forward meaningful route context before optimization exists.
- Keep the change minimal: expose enough shared assignment data for future surfaces and restore tests, but do not start applying reassignment decisions.
- Update projection logic only as needed to keep evidence summaries aligned with the new assignment truth.

**Execution note:** Characterize the current restore path in tests first, then add destination assignment restore with the smallest possible production changes.

**Patterns to follow:**
- Reuse the current restore sequencing in `AutoModeViewModel.restoreState()`.
- Keep shared evidence projection as the aggregation seam rather than formatting destination truth independently in view models.

**Test scenarios:**
- Happy path: app restore loads subscription, snapshot, pin state, and destination assignments together from one backing store.
- Happy path: a restored manual assignment remains manual after app relaunch.
- Edge case: destination assignment state exists while no fresh snapshot exists, and the restore path still exposes a coherent degraded state rather than resetting silently.
- Edge case: restoring old assignment state does not break the current non-destination benchmark flow.
- Error path: corrupted destination assignment payload is cleared and the app falls back to a safe no-assignment state.
- Integration: `AutoModeViewModel` restore tests prove destination-aware shared state can coexist with the existing snapshot and pin state restore path.

**Verification:**
- The app restore path can carry destination assignment truth without optimizer logic or UI-specific persistence hacks.

- [ ] **Unit 4: Extend the launch-driven scenario contract for persisted destination state**

**Goal:** Make the live E2E harness capable of restoring destination-aware persisted state so Sprint 3 can prove optimizer behavior against a real launch contract.

**Requirements:** R25-R29

**Dependencies:** Units 1-3

**Files:**
- Modify: `App/Automation/LiveE2EScenario.swift`
- Modify: `App/Automation/LiveE2ERunner.swift`
- Modify: `Tests/LiveE2EScenarioTests.swift`
- Modify: `UITests/LiveE2EWorkflowTests.swift`
- Modify: `docs/testing/live-e2e-workflow.md`

**Approach:**
- Extend the launch-driven scenario payload so it can seed persisted destination assignment state alongside the existing subscription and benchmark fixtures.
- Keep the harness state-based and deterministic.
- Focus on restore realism, not optimizer actions: the scenario contract should be able to launch into auto-owned, manual-owned, stale, and empty destination assignment states.
- Tighten weak no-op UI assertions from Sprint 1 so scenario tests prove a coherent restored state, not just that the app can launch and terminate.

**Execution note:** Add scenario-parser tests first so the persisted-state contract is locked before wiring the runner.

**Patterns to follow:**
- Reuse the existing launch-driven scenario parser and state seeding workflow.
- Keep `docs/testing/live-e2e-workflow.md` as the canonical description of the simulator-backed proof contract.

**Test scenarios:**
- Happy path: a launch scenario can seed a persisted auto-owned destination assignment state.
- Happy path: a launch scenario can seed a persisted manual override destination assignment state.
- Edge case: a launch scenario with no destination assignments still runs the legacy live E2E flow unchanged.
- Edge case: stale assignment metadata is restored as stale state without implying optimizer activity.
- Error path: malformed destination-assignment scenario payload fails safely without corrupting normal app launch.
- Integration: UI scenario tests can verify the app opens into a coherent restored destination-routing context before any runtime optimization logic exists, rather than only asserting no crash.

**Verification:**
- The E2E harness can restore destination-aware shared state deterministically, which becomes the proof surface for Sprint 3.

## System-Wide Impact

- **Interaction graph:** curated destination identity now feeds one assignment state spine, which is then restored into app flow seams and later consumed by optimization and UI surfaces.
- **Error propagation:** corrupted assignment payloads should clear at the shared store boundary, not leak inconsistent route truth upward.
- **State lifecycle risks:** the main risk is split-brain state between snapshot evidence, pin state, and destination assignments; this sprint mitigates that by introducing one assignment store and keeping measurement truth separate.
- **API surface parity:** the same destination identity and mode vocabulary should line up across shared domain types, stores, restore tests, and launch scenarios.
- **Integration coverage:** unit persistence tests and launch-driven restore tests are both required, because destination state can look correct in storage while still failing app restore behavior.
- **Unchanged invariants:** no fake app telemetry, no background optimizer claims, and no destination-aware auto-switch behavior yet.

## Risks & Dependencies

| Risk | Mitigation |
| --- | --- |
| Sprint 2 accidentally starts implementing optimizer policy | Keep optimization decisions out of production code and constrain the sprint to assignment representation and restore behavior only. |
| Assignment truth drifts from benchmark snapshot truth | Keep destination assignment in its own domain/store layer and treat snapshots as evidence only. |
| Manual override semantics get lost during restore | Add explicit tests for auto-owned vs manual-owned assignments and keep provenance in the persisted model. |
| New store duplicates existing persistence behavior inconsistently | Follow the same actor + `PersistentDataStoring` + corruption-clearing pattern already used by the existing stores. |
| Launch-driven E2E becomes more brittle | Expand the current harness incrementally and lock parser behavior in unit tests before UI assertions change. |

## Sequencing

1. Harden any weak Sprint 1 placeholder contract coverage while introducing production assignment vocabulary.
2. Add the shared assignment store and characterize restore/corruption behavior.
3. Wire the assignment store into app restore seams with minimal production adoption.
4. Extend the launch-driven scenario contract so persisted destination state can be replayed deterministically and asserted as restored UI state.

## Test Strategy

- Preserve Sprint 1’s contract tests as the semantic source of truth.
- Add new shared-domain and store characterization tests before changing runtime code.
- Reuse the in-memory persistence seam for deterministic restore tests.
- Keep launch-driven E2E deterministic and state-seeded rather than tap-scripted.
- Defer any “does the optimizer choose the best route?” assertions to Sprint 3.

## Exit Criteria

- Production shared types exist for destination routing assignment and distinguish Auto vs Manual ownership.
- Destination assignment state persists and restores safely through one shared store.
- App restore paths can load destination assignment truth without custom screen-owned persistence.
- The launch-driven E2E harness can seed and replay persisted destination routing state.
- No optimizer behavior or continuous refinement logic has leaked into this sprint.
