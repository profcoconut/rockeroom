---
title: feat: Plan routing optimization core
type: feat
status: active
date: 2026-04-04
origin: docs/brainstorms/2026-04-04-routing-optimization-core-requirements.md
---

# feat: Plan routing optimization core

## Overview

RockeRoom's current alpha can benchmark one imported subscription and explain a single current recommendation. The next product step is bigger: make RockeRoom decide and validate routing for a curated destination set such as `OpenAI`, `Claude`, `Netflix`, `TikTok`, and `Apple`, while staying honest about what iOS can and cannot observe (see origin: `docs/brainstorms/2026-04-04-routing-optimization-core-requirements.md`).

This plan is intentionally **tests-first** and **multi-sprint**. The routing story is only valuable if the app can prove, end to end, that destination definitions, measurements, optimization choices, mode behavior, and user-visible state all agree. The first sprint therefore builds the test harness and truth fixtures before the product model expands.

## Problem Frame

Today the app can answer a narrower question: which current measured candidate looks best overall for the whole subscription. That is not enough for the intended product. The requested feature needs RockeRoom to answer, per curated destination:

- what is the current performance
- which routing strategy is active
- which node or provider is active
- whether that combination can be improved
- whether RockeRoom should change it automatically or only recommend changes

The repo already contains two critical constraints that shape the implementation:

- all user-facing truth should continue to come from one shared snapshot and policy spine, not parallel view-specific logic
- the app must not claim private per-app telemetry on iOS unless a future platform proof changes the current observability memo

That means the implementation must introduce destination-aware routing optimization without breaking the current architecture or inventing a fake “app telemetry” story.

## Requirements Trace

- R1-R4. Define destination routing optimization as the product core, with app labels backed by rule-based destination identities and honest observability language.
- R5-R8. Ship a curated top 10 destination catalog, not an unbounded import of every external rule.
- R9-R13. Support exactly two operating modes, `Auto Mode` and `Manual Mode`, with Auto allowed to change both routing target and node selection.
- R14-R20. Support fast-pass setup, foreground-only refinement, destination-level comparison, and honest uncertainty handling.
- R21-R24. Update `Home` and `Expert Console` so users can understand current routing state, current strategy, current provider, and optimization opportunity.
- R25-R29. Treat the live E2E workflow as part of the feature definition, with deterministic and true-live validation paths.

## Scope Boundaries

- No claim of private telemetry for arbitrary installed iOS apps.
- No attempt to support the full `ios_rule_script` catalog in v1.
- No more than two user-facing routing modes.
- No background optimizer claim while the app is closed.
- No template-import-first product path; external templates remain reference material for semantics and fixtures.

## Context & Research

### Relevant Code and Patterns

- `App/Home/HomeView.swift` currently presents one current recommendation plus four summary metrics. It is the correct seam for the future top-level “current routing health” surface.
- `App/AutoMode/AutoModeViewModel.swift` remains the orchestration seam for import, benchmark, restore, stale-state handling, and pin behavior. Destination-aware optimization should extend this seam rather than bypassing it.
- `App/ExpertConsole/ExpertConsoleView.swift` and `App/ExpertConsole/ExpertConsoleViewModel.swift` already consume shared recommendation state and expose ranked candidates plus pin controls. This is the right place for destination-level detail and override behavior.
- `Shared/Engine/ResultSnapshot.swift`, `Shared/Engine/ProbeRunner.swift`, `Shared/Engine/RecommendationPolicy.swift`, `Shared/Engine/RefreshCoordinator.swift`, and `Shared/Engine/EvidenceProjection.swift` define the current shared truth spine. The routing-optimization model should extend this shared layer rather than replacing it.
- `docs/testing/live-e2e-workflow.md`, `App/Automation/LiveE2ERunner.swift`, and `UITests/LiveE2EWorkflowTests.swift` already define a durable simulator-driven E2E contract. The new feature should extend that contract instead of inventing a second automation mechanism.
- `README.md` and `docs/research/2026-04-04-ios-observability-spike.md` already codify the current evidence model and observability limit. Those constraints remain authoritative.

### Institutional Learnings

- The current alpha stabilized by keeping one snapshot and one policy layer shared across `Home`, `Expert Console`, and `Marketplace`. This plan should preserve that invariant instead of introducing destination-local ranking logic.
- Previous hardening work proved that deterministic simulator validation and explicit live-provider validation both matter. This feature needs both from the start because route optimization can regress even when isolated scoring logic still passes.
- The existing live E2E workflow already showed one important operational truth: MCP build-and-run works, but scenario replay is most dependable when launch environment is set explicitly. The plan should assume that true-live validation remains explicit and intentional.

### External References

- User-provided routing template reference: `https://github.com/limbopro/Profiles4limbo`
- User-provided rule source reference: `https://github.com/blackmatrix7/ios_rule_script`
- Current observability constraint: `docs/research/2026-04-04-ios-observability-spike.md`

## Key Technical Decisions

- **Tests-first is the execution posture for the whole roadmap:** start by codifying destination fixtures, route semantics, and E2E expectations before widening runtime behavior.
- **Add a destination-aware layer to the shared truth spine, not a second engine:** destination identity, assignment, score, and optimization opportunity should all live in shared models adjacent to the current snapshot/policy system.
- **Preserve the current two-level app structure:** `Home` stays the summary and current-state surface, `Expert Console` stays the detailed inspect and override surface.
- **Model Auto and Manual as policy modes, not separate products:** they should share the same destination evidence, scoring, and UI story while differing only in whether RockeRoom may apply changes automatically.
- **Treat fast pass and foreground refinement as separate evaluation phases:** the first should produce a useful answer quickly; the second should refine only while the app is open.
- **Extend the existing live E2E workflow instead of replacing it:** the simulator-backed launch-driven harness is already the strongest available cross-layer validation seam in this repo.

## Open Questions

### Resolved During Planning

- **Should the plan start with feature code or with tests?** Tests first. This request explicitly calls for a tests-first posture, and the feature is too cross-cutting to trust ad hoc implementation.
- **Should this be one sprint or several?** Several. The feature has distinct phases: truth fixtures and test matrix, destination model, optimization engine, UI integration, and live E2E hardening.
- **Should the roadmap assume true per-app telemetry?** No. App labels are allowed in the UI, but they remain rule-backed destinations under the current observability memo.
- **Should Auto Mode be allowed to control both strategy and node/provider?** Yes, per origin requirements.

### Deferred to Implementation

- **Exact shared type boundaries:** whether destination-aware models extend `ResultSnapshot` directly or sit alongside it as a destination-routing projection should be finalized during implementation.
- **Exact top 10 rule-pack file selection:** the destination list is fixed, but the concrete upstream rule files or normalization strategy can be chosen during implementation.
- **Exact fast-pass thresholds:** the plan requires a quick initial answer, but the concrete search-space limit and switch thresholds depend on implementation-time measurement.
- **Exact UI composition on `Home`:** the plan requires destination-aware current-state summaries, but the exact card layout can be finalized during UI work.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```text
subscription import
  -> curated destination catalog
  -> destination x strategy x node candidate space
  -> fast pass measurement
  -> destination routing snapshot
  -> shared optimization policy
      -> Auto Mode may apply assignments
      -> Manual Mode shows advisory state only
  -> foreground refinement updates opportunities
  -> Home summarizes current routing health
  -> Expert Console exposes per-destination evidence and overrides
  -> live E2E verifies import, apply, hold, override, stale, and recovery flows
```

## Phased Delivery

### Sprint 1
- Lock the destination fixtures, route semantics, and tests-first validation harness.

### Sprint 2
- Add destination catalog, route identity, assignment persistence, and destination-aware shared snapshot structures.

### Sprint 3
- Add optimization policy for fast pass, foreground refinement, and Auto vs Manual mode behavior.

### Sprint 4
- Integrate the new model into `Home`, `Expert Console`, and user-visible override flows.

### Sprint 5
- Expand deterministic and true-live E2E validation, then harden rollout and docs for the new routing core.

## Implementation Units

- [ ] **Unit 1: Sprint 1 - Destination fixtures and tests-first routing contract**

**Goal:** Establish the destination catalog fixtures, upstream rule semantics, and full cross-layer test matrix before adding new runtime behavior.

**Requirements:** R3-R8, R25-R29

**Dependencies:** Current alpha baseline only

**Files:**
- Create: `Tests/Fixtures/routing-destinations/`
- Create: `Tests/DestinationCatalogTests.swift`
- Create: `Tests/DestinationRoutingContractTests.swift`
- Create: `Tests/RoutingOptimizationPolicyTests.swift`
- Modify: `UITests/LiveE2EWorkflowTests.swift`
- Modify: `docs/testing/live-e2e-workflow.md`
- Modify: `docs/release/alpha-testflight-checklist.md`

**Approach:**
- Capture a deterministic top 10 destination fixture set for `OpenAI`, `Claude`, `Google AI`, `Netflix`, `Disney+`, `TikTok`, `YouTube`, `Telegram`, `Apple`, and `Final`, each with its rule-backed identity and display semantics.
- Define the cross-layer contract in tests first: destination identity, strategy label, provider label, current score, optimization opportunity, mode behavior, and user-visible state transitions.
- Extend the current live E2E scenario matrix on paper first so every future sprint knows what must remain provable on simulator.
- Keep this sprint mostly about truth fixtures and behavioral contracts rather than product code.

**Execution note:** Start with failing unit and UI-level characterization coverage before creating destination-aware runtime types.

**Patterns to follow:**
- Reuse the fixture-driven style already used in `Tests/Fixtures/live-vless-subscription.txt`.
- Reuse the launch-driven scenario model from `App/Automation/LiveE2ERunner.swift` and `docs/testing/live-e2e-workflow.md`.

**Test scenarios:**
- Happy path: each curated destination resolves to one stable identity and display label.
- Happy path: the routing contract can represent current destination performance, current strategy, current node/provider, and optimization opportunity together.
- Edge case: unknown or unsupported destination input is rejected or omitted without corrupting the curated set.
- Edge case: a destination with incomplete upstream rule metadata still renders a stable fallback identity in the contract layer.
- Error path: live E2E docs and scenario lists fail review if they omit Auto Mode apply, Manual Mode advisory, stale evidence, or recovery flows.
- Integration: deterministic fixtures can drive both shared-engine tests and scenario-backed UI assertions without inventing separate semantics.

**Verification:**
- The repo contains a stable destination-routing fixture set and a test matrix that defines the feature before runtime code changes begin.

- [ ] **Unit 2: Sprint 2 - Destination catalog, assignment model, and persistence**

**Goal:** Introduce destination-aware shared models and persistence for destination identity, routing strategy assignment, and node/provider assignment.

**Requirements:** R1-R8, R18a

**Dependencies:** Unit 1

**Files:**
- Create: `Shared/Domain/DestinationDefinition.swift`
- Create: `Shared/Domain/RoutingMode.swift`
- Create: `Shared/Engine/DestinationCatalog.swift`
- Create: `Shared/Engine/DestinationAssignmentStore.swift`
- Create: `Shared/Engine/DestinationRoutingSnapshot.swift`
- Modify: `Shared/Engine/ResultSnapshot.swift`
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Test: `Tests/DestinationCatalogTests.swift`
- Test: `Tests/DestinationAssignmentStoreTests.swift`
- Test: `Tests/DestinationRoutingSnapshotTests.swift`

**Approach:**
- Add one shared representation for curated destination definitions and one shared representation for current destination routing state.
- Persist destination assignments separately from raw benchmark snapshots so the app can distinguish “what we measured” from “what is currently assigned.”
- Keep the new model adjacent to the current `ResultSnapshot` and recommendation system instead of replacing them outright.
- Ensure the model can represent current strategy, current provider/node, and current optimization opportunity without requiring view-specific joins.

**Execution note:** Implement new shared types test-first using the fixtures from Unit 1 before wiring them into view models.

**Patterns to follow:**
- Mirror the persistence seams already used by `SubscriptionRepository`, `ResultSnapshotStore`, and `PinStateStore`.
- Preserve the repo pattern that shared truth lives under `Shared/Engine/` and `Shared/Domain/`.

**Test scenarios:**
- Happy path: a curated destination definition restores with the same identity, label, and rule-backed metadata across launches.
- Happy path: destination assignment persistence restores current strategy and node/provider without losing the relationship to the destination identity.
- Edge case: missing assignment for one destination leaves other destination assignments intact.
- Edge case: a restored snapshot with no current assignment still remains inspectable as “measured but not applied.”
- Error path: corrupted assignment payload falls back safely without clearing valid subscription or snapshot state.
- Integration: `AutoModeViewModel.restoreState()` can hydrate destination-aware state alongside existing subscription and benchmark truth.

**Verification:**
- The shared layer can restore destination routing state reliably, and no destination-aware UI needs to invent its own persistence or lookup model.

- [ ] **Unit 3: Sprint 3 - Optimization policy, Auto vs Manual mode, and foreground refinement**

**Goal:** Add the destination-aware optimization engine that powers fast pass, foreground refinement, and the behavioral split between Auto Mode and Manual Mode.

**Requirements:** R9-R20

**Dependencies:** Unit 2

**Files:**
- Create: `Shared/Engine/DestinationOptimizationPolicy.swift`
- Create: `Shared/Engine/DestinationProbeRunner.swift`
- Create: `Shared/Engine/ForegroundRefinementCoordinator.swift`
- Modify: `Shared/Engine/ProbeRunner.swift`
- Modify: `Shared/Domain/RecommendationState.swift`
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Modify: `App/RockeRoomApp.swift`
- Test: `Tests/RoutingOptimizationPolicyTests.swift`
- Test: `Tests/ForegroundRefinementCoordinatorTests.swift`
- Test: `Tests/AutoModeViewModelTests.swift`
- Test: `Tests/AppSessionRestoreTests.swift`

**Approach:**
- Build a destination-aware policy layer that evaluates destination x strategy x provider combinations and decides current quality, optimization opportunity, and whether a change is justified.
- Model `Auto Mode` and `Manual Mode` as policy-controlled behavior over the same evidence, with Auto allowed to apply changes and Manual limited to advisory output.
- Keep fast pass and refinement as distinct phases: fast pass produces a useful initial assignment quickly, refinement keeps evaluating only while the app is active.
- Make switch thresholds explicit so the product can hold steady when gains are weak, evidence is stale, or confidence is low.

**Execution note:** Start with failing policy tests for Auto apply, Manual hold, and foreground-only refinement triggers before changing runtime orchestration.

**Patterns to follow:**
- Reuse the existing central-policy pattern from `Shared/Engine/RecommendationPolicy.swift`.
- Reuse the lifecycle-triggered refresh pattern already established by `Shared/Engine/RefreshCoordinator.swift` and `App/RockeRoomApp.swift`.

**Test scenarios:**
- Happy path: fast pass produces an initial assignment for each supported destination with current strategy and current provider labels.
- Happy path: Auto Mode applies a better destination assignment when the measured gain clears the switch threshold.
- Happy path: Manual Mode surfaces the same better assignment as advisory without applying it.
- Edge case: destination evidence is stale or partial, so the policy holds the current assignment and surfaces uncertainty.
- Edge case: foreground refinement discovers no meaningful gain and leaves the current assignment unchanged.
- Error path: a failed destination reassignment preserves the last known-good assignment and marks the destination degraded or recoverable.
- Integration: relaunch restores the current mode, destination assignments, and current evidence without running an unsolicited background optimization pass.

**Verification:**
- The app can compute destination-aware opportunities and differentiate Auto apply from Manual advisory while staying within foreground-only lifecycle limits.

- [ ] **Unit 4: Sprint 4 - Destination-aware Home and Expert Console integration**

**Goal:** Surface destination-level routing truth in `Home` and `Expert Console` without breaking the current calm summary-first information architecture.

**Requirements:** R21-R24

**Dependencies:** Unit 3

**Files:**
- Modify: `App/Home/HomeView.swift`
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Modify: `App/ExpertConsole/ExpertConsoleView.swift`
- Modify: `App/ExpertConsole/ExpertConsoleViewModel.swift`
- Modify: `App/AppRootView.swift`
- Create: `App/Home/DestinationRoutingSummaryView.swift`
- Test: `Tests/HomeSummaryMetricTests.swift`
- Test: `Tests/ExpertConsoleDestinationTests.swift`
- Test: `UITests/FirstRunOptimizeFlowTests.swift`
- Test: `UITests/ManualPinFlowTests.swift`

**Approach:**
- Update `Home` so it answers the new core question: is this device currently well-routed, which destinations need attention, and has RockeRoom already applied useful changes.
- Update `Expert Console` so users can inspect per-destination current strategy, current provider, alternatives, and override or pin semantics in one detailed surface.
- Preserve the current high-level structure: `Home` stays summary-oriented, `Expert Console` stays detailed and operational.
- Keep destination-aware UI fed from shared destination-routing state and policy outputs rather than bespoke view-owned transformations.

**Execution note:** Add failing UI and view-model assertions for the new destination-level summaries before redesigning visible surfaces.

**Patterns to follow:**
- Preserve the current split where `AppRootView` synchronizes shared state into `ExpertConsoleViewModel`.
- Reuse the current “summary on Home, detail in Expert Console” pattern from the shipped product reset.

**Test scenarios:**
- Happy path: after fast pass, `Home` shows current routing health and highlights at least one destination with current strategy and current provider information.
- Happy path: `Expert Console` shows a supported destination's current assignment, alternatives, and whether the current state was auto-applied or remains advisory.
- Edge case: a destination with inconclusive evidence shows a hold or caution state rather than a fake winner.
- Edge case: switching between Auto and Manual preserves current evidence while changing only the allowed action semantics.
- Error path: degraded destination routing remains inspectable in `Expert Console` and summarized honestly on `Home`.
- Integration: a user override or pin in the detailed surface immediately updates the top-level summary state on `Home`.

**Verification:**
- Users can understand current destination routing state and optimization opportunity from the two existing primary surfaces without needing a second mental model.

- [ ] **Unit 5: Sprint 5 - Live E2E expansion, true-live validation, and rollout hardening**

**Goal:** Expand the current simulator-driven E2E workflow to prove the new routing core under deterministic and real-provider conditions, then document and harden the release path.

**Requirements:** R25-R29

**Dependencies:** Units 1-4

**Files:**
- Modify: `App/Automation/LiveE2EScenario.swift`
- Modify: `App/Automation/LiveE2ERunner.swift`
- Modify: `UITests/LiveE2EWorkflowTests.swift`
- Modify: `UITests/FirstRunOptimizeFlowTests.swift`
- Modify: `UITests/ManualPinFlowTests.swift`
- Modify: `docs/testing/live-e2e-workflow.md`
- Modify: `docs/release/alpha-testflight-checklist.md`
- Modify: `README.md`

**Approach:**
- Extend the current launch-driven scenario contract so it can validate destination-aware setup, Auto apply, Manual advisory, override, stale-state refresh, and failed reassignment recovery.
- Keep deterministic simulator coverage fixture-backed, but require an explicit true-live validation path against real providers before calling the feature shipped.
- Make the docs say exactly what evidence must be captured for destination-aware routing: current destination state, current strategy, current provider, optimization opportunity, mode, and resulting user-visible change.
- Preserve the current repo rule that simulator inspection with MCP is part of the ship bar for flow changes.

**Execution note:** Start by extending the scenario list and E2E assertions before polishing docs, so the documentation only describes flows that are actually testable.

**Patterns to follow:**
- Reuse the existing launch-driven automation contract in `App/Automation/LiveE2ERunner.swift`.
- Reuse the current split between deterministic regression mode and true live import mode in `docs/testing/live-e2e-workflow.md`.

**Test scenarios:**
- Happy path: Auto Mode fast pass applies destination assignments and the UI shows the applied result on simulator.
- Happy path: Manual Mode shows the same destination opportunity as advisory without applying it.
- Happy path: a destination override or pin survives relaunch and remains visible in both `Home` and `Expert Console`.
- Edge case: foreground refinement finds a better destination route and updates the UI only while the app stays active.
- Edge case: a destination remains unchanged because the gain is too small, and the UI explains the hold cleanly.
- Error path: a failed destination routing change preserves last-known-good state and shows recovery messaging.
- Integration: explicit MCP live-provider launch lands on a destination-aware `Home` state with visible current strategy, provider, and optimization evidence.

**Verification:**
- The routing-optimization core has one dependable validation story across deterministic regression, simulator inspection, and true-live provider checks.

## System-Wide Impact

- **Interaction graph:** subscription import feeds the curated destination catalog, which feeds destination-aware measurement and policy; the resulting assignment state then drives `Home`, `Expert Console`, persistence, and the live E2E harness.
- **Error propagation:** failed measurements or failed assignment changes must preserve last-known-good routing state and surface degraded or recoverable status rather than silently clearing destination truth.
- **State lifecycle risks:** fast pass, foreground refinement, override state, and restored assignments can drift if state is persisted in more than one place; this plan keeps persistence in shared stores and policy decisions in shared engine seams.
- **API surface parity:** `Home`, `Expert Console`, README and release docs, deterministic E2E, and true-live validation all need to describe the same destination-routing model and observability constraint.
- **Integration coverage:** destination-aware mode switching, assignment persistence, foreground-only refinement, and failed reassignment recovery all require cross-layer proof beyond unit tests alone.
- **Unchanged invariants:** one shared truth spine, no private per-app telemetry claim, no background optimizer promise while closed, and no more than two routing modes remain fixed.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| The destination model forks into a second ranking engine separate from the current snapshot/policy spine | Keep new destination-aware types in `Shared/` and route all apply or hold decisions through one shared optimization policy |
| The top 10 curated set grows informally into an unbounded catalog | Lock the v1 catalog in fixtures and tests first, and treat any expansion as explicit follow-on scope |
| Fast pass becomes too slow because the destination x strategy x provider search space explodes | Set test-backed upper bounds in Sprint 1 and refine thresholds in Sprint 3 before widening scope |
| Auto apply feels unsafe or surprising | Distinguish Auto vs Manual in policy and UI semantics, and require visible E2E proof for apply versus advisory behavior |
| The true-live validation story drifts from deterministic regression coverage | Extend the existing scenario contract so both validation modes prove the same product semantics |

## Documentation / Operational Notes

- `docs/testing/live-e2e-workflow.md` should become the canonical validation contract for this feature instead of only a generic app-flow checklist.
- `docs/release/alpha-testflight-checklist.md` should add destination-aware validation items once Sprint 5 lands.
- `README.md` should stay concise and explain the new routing core in terms of curated destinations, shared truth, and current observability limits.

## Sources & References

- **Origin document:** `docs/brainstorms/2026-04-04-routing-optimization-core-requirements.md`
- Related code: `App/AutoMode/AutoModeViewModel.swift`
- Related code: `App/Home/HomeView.swift`
- Related code: `App/ExpertConsole/ExpertConsoleViewModel.swift`
- Related code: `Shared/Engine/ProbeRunner.swift`
- Related code: `Shared/Engine/ResultSnapshot.swift`
- Related docs: `docs/testing/live-e2e-workflow.md`
- External docs: `https://github.com/limbopro/Profiles4limbo`
- External docs: `https://github.com/blackmatrix7/ios_rule_script`
