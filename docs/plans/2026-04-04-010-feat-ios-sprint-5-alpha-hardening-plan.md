---
title: feat: Detail iOS sprint 5 alpha hardening
type: feat
status: completed
date: 2026-04-04
---

# feat: Detail iOS sprint 5 alpha hardening

## Overview

This plan deepens the final roadmap slice for the current alpha. Sprint 4 completed the first truthful Marketplace surface and landed the observability constraint as a repo artifact. The product loop now exists end to end:
- import a Clash subscription link
- start or restore tunnel/runtime truth
- evaluate and persist recommendation evidence
- inspect and pin in Expert Console
- browse the same evidence in Marketplace

Sprint 5 should not add new product scope. It should harden what already exists into a stable alpha candidate:
- close the remaining failure-state and cross-surface regression gaps
- make the combined simulator-backed test path reliable enough to be a real release gate
- add the minimal release and validation docs needed for TestFlight distribution

## Problem Frame

RockeRoom is now feature-complete for the intended alpha shape, but it is not yet release-ready. The repo has good isolated test coverage, yet the last full `xcodebuild ... test` run exposed an important gap: `SharedKitTests`, `RockeRoomAppTests`, and the UI slices pass in isolation, but the combined simulator-backed path still hit an early bootstrap/harness failure during one integrated run. That is not a product-behavior failure, but it is still a release-readiness problem because the alpha gate needs a dependable validation path rather than a collection of individually green fragments.

There are also still thin areas around negative-path trust behavior and operator handoff:
- the UI paths strongly cover happy flows, but not enough degraded/retry states at the user-visible level
- the docs explain the evidence model and observability limit, but there is no release-facing TestFlight checklist yet
- the current repo does not define one stable alpha-verification story for contributors or evaluators

Sprint 5 should therefore be an alpha hardening sprint, not a feature sprint.

## Requirements Trace

- R1. Make the combined build-and-test path reliable enough to serve as an alpha release gate.
- R2. Expand failure-state and degraded-state regression coverage for the trust-sensitive product surfaces already shipped.
- R3. Keep Auto Mode, Expert Console, and Marketplace aligned under failure, stale, retry, and relaunch conditions.
- R4. Preserve the current product invariants: home-first navigation, centralized recommendation policy, shared snapshot truth, binary import validation, and pin-means-no-auto-switch.
- R5. Add a minimal TestFlight-facing release checklist and contributor-facing validation notes so the alpha can be installed and evaluated consistently.
- R6. Keep scope bounded to hardening and release readiness; do not add new marketplace, telemetry, or tunnel-runtime capabilities.

## Scope Boundaries

- No new user-facing modes or navigation surfaces
- No new marketplace write flows, payments, or seller concepts
- No deeper per-app telemetry claims beyond the sprint-4 observability memo
- No major UI redesign; only targeted copy/state polish tied to hardening
- No replacement of the Clash execution core or the current shared policy architecture

## Context & Research

### Relevant Code and Patterns

- `UITests/FirstRunOptimizeFlowTests.swift` now covers import, optimize, restore, and Marketplace navigation. It is the right place to extend first-run and degraded-state UI coverage rather than creating parallel flows.
- `UITests/ManualPinFlowTests.swift` now proves Expert Console reachability and pin/no-auto-switch behavior. Sprint 5 should deepen this file with unpin and retry-oriented assertions rather than adding a third UI harness.
- `App/AutoMode/AutoModeViewModel.swift` remains the main orchestration seam for import, optimize, restore, stale-state mapping, pinning, and user-visible recommendation summaries. Failure-state hardening should stay centered here.
- `Shared/Engine/ClashAdapter.swift` and `Tests/ClashAdapterTests.swift` already define the tunnel-start failure contract. Sprint 5 should extend those tests around repeated failure/recovery behavior and app-facing implications rather than inventing new runtime abstractions.
- `Shared/Engine/RefreshCoordinator.swift`, `Shared/Engine/RecommendationPolicy.swift`, and `Shared/Engine/EvidenceProjection.swift` already contain the semantics that must stay aligned across Auto Mode, Expert Console, and Marketplace.
- `README.md` now explains the alpha evidence model, but `docs/release/alpha-testflight-checklist.md` does not exist yet.

### Institutional Learnings

- The sprint-4 work showed an important practical truth: isolated suites can all be green while the combined simulator-backed run still flakes at harness/bootstrap time. Alpha readiness therefore needs both behavioral coverage and runner stability treatment.
- Earlier design and eng reviews already fixed the trust boundaries. Sprint 5 should avoid reopening those decisions and instead prove them more thoroughly under stress.

### External References

- No new external research is needed. This sprint is about stabilizing the current repo’s runtime, test, and release posture rather than designing against a new framework or product surface.

## Key Technical Decisions

- **Treat full-suite reliability as a product-quality concern, not “just CI noise”:** if the integrated simulator run is flaky, the alpha gate is weak even when isolated tests are green.
- **Harden existing test seams instead of creating new ones:** sprint 5 should deepen `FirstRunOptimizeFlowTests`, `ManualPinFlowTests`, and the current shared/app-hosted unit tests rather than fragmenting coverage.
- **Prefer negative-path coverage over new behavior:** the most valuable sprint-5 work is proving recovery, degradation, and cross-surface consistency under bad conditions.
- **Keep release docs operational and alpha-specific:** the new checklist should help a contributor or evaluator install, run, and validate the app on TestFlight; it should not read like public launch marketing.
- **Do not resolve harness issues by weakening the gate:** if the integrated run needs structural stabilization, fix the test shape or app-launch assumptions rather than narrowing coverage to “easy” slices.

## Open Questions

### Resolved During Planning

- **Should sprint 5 add new end-user features?** No. This sprint is hardening-only.
- **Should combined-suite instability be treated as out of scope because isolated suites already pass?** No. Reliable integrated verification is part of alpha readiness.
- **Should TestFlight docs stay in `README.md` only?** No. `README.md` should stay lightweight; the release checklist should live in `docs/release/`.

### Deferred to Implementation

- **Exact root cause of the combined-run bootstrap failure:** the plan requires isolating and fixing it, but the concrete cause is an execution-time discovery problem.
- **Exact copy polish for degraded and retry states:** the plan requires trust alignment under failure, but final wording can be tuned during implementation.
- **Whether the final release checklist also needs screenshots or install notes for non-developers:** this depends on how much friction is discovered while writing the alpha handoff doc.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```text
isolated green suites
    + integrated simulator run
        -> identify harness or app-launch instability
        -> stabilize combined gate

existing trust surfaces
    -> add degraded/retry/relaunch assertions
    -> verify same recommendation story across:
       Auto Mode
       Expert Console
       Marketplace

release handoff
    -> alpha checklist
    -> validation notes
    -> TestFlight-ready operator path
```

## Implementation Units

- [ ] **Unit 1: Stabilize the integrated alpha test gate**

**Goal:** Make the combined simulator-backed test path reliable enough that `RockeRoom` scheme test runs can serve as the alpha release gate.

**Requirements:** R1, R4

**Dependencies:** Current sprint-4 codebase and passing isolated suites

**Files:**
- Modify: `project.yml`
- Modify: `UITests/FirstRunOptimizeFlowTests.swift`
- Modify: `UITests/ManualPinFlowTests.swift`
- Modify: `Tests/AppSessionRestoreTests.swift`
- Modify: `Tests/TestSupport.swift`

**Approach:**
- Investigate the current combined-run bootstrap failure as a harness-shape problem first: test isolation, launch environment reuse, simulator state leakage, and app-hosted/UI-target interactions.
- Tighten the current test fixtures so suites do not depend on hidden simulator state from earlier runs.
- If necessary, adjust how the scheme groups app-hosted versus UI tests, but keep the integrated `RockeRoom` scheme as the final validation surface rather than replacing it with only isolated commands.
- Preserve the current user-visible assertions while making the gate more deterministic.

**Execution note:** Start with characterization of the current combined-run failure before changing test structure.

**Patterns to follow:**
- Reuse the current test split already codified in `project.yml`.
- Follow the existing per-test launch-environment pattern in the UI tests instead of inventing a second configuration channel.

**Test scenarios:**
- Happy path: a full integrated scheme run completes after shared, app-hosted, and UI tests execute in sequence.
- Edge case: repeated full-suite runs do not inherit broken simulator or app state from previous runs.
- Error path: when a launch/bootstrap failure occurs, the test structure exposes a deterministic failing seam rather than intermittent unexplained exits.
- Integration: app-hosted restore tests and UI tests can coexist under the same scheme without cross-target bootstrap collisions.

**Verification:**
- The `RockeRoom` scheme can be used as a dependable alpha validation gate rather than only isolated target runs.

- [ ] **Unit 2: Deepen failure-state and recovery coverage**

**Goal:** Expand trust-sensitive regression coverage for the user-visible bad paths already present in the product.

**Requirements:** R2, R3, R4

**Dependencies:** Unit 1

**Files:**
- Modify: `UITests/FirstRunOptimizeFlowTests.swift`
- Modify: `UITests/ManualPinFlowTests.swift`
- Modify: `Tests/ClashAdapterTests.swift`
- Modify: `Tests/FreshnessRegressionTests.swift`
- Modify: `Tests/RecommendationPolicyTests.swift`
- Modify: `Tests/AppSessionRestoreTests.swift`

**Approach:**
- Add missing user-visible coverage for degraded runtime truth: tunnel-start failure, stale restore before refresh, retry after prior failure, and unpin resuming policy-controlled recommendation behavior.
- Keep new assertions tied to existing product promises: honest warnings, preserved last-known-good state, and no silent auto-switch while pinned.
- Extend shared-engine tests where UI-only coverage would be too expensive, but ensure every important negative path has at least one user-visible or cross-layer assertion.

**Patterns to follow:**
- Mirror the current UI flow style in `FirstRunOptimizeFlowTests` and `ManualPinFlowTests`.
- Reuse the current failure contracts already encoded in `ClashAdapter`, `RefreshCoordinator`, and `RecommendationPolicy`.

**Test scenarios:**
- Happy path: pin -> unpin -> next qualifying recommendation resumes policy control cleanly across Auto Mode and Expert Console.
- Happy path: stale restore followed by explicit optimize replaces stale evidence with current evidence across Auto Mode and Marketplace.
- Edge case: invalid subscription import followed by recovery still preserves a coherent Marketplace and Expert Console state.
- Edge case: tunnel-start failure preserves the stored subscription and presents recoverable degraded messaging.
- Error path: repeated tunnel-start failure does not corrupt persisted session or recommendation truth.
- Error path: degraded or empty marketplace projection after failure remains navigable and consistent with Auto Mode messaging.
- Integration: Auto Mode, Expert Console, and Marketplace continue to agree on the active setup under stale, pinned, and degraded conditions.

**Verification:**
- The remaining trust-sensitive negative paths are covered by regression tests at the right layer, not only by happy-flow automation.

- [ ] **Unit 3: Polish alpha-facing failure and recovery presentation**

**Goal:** Tighten the user-visible state language and fallback rendering so failure and degraded paths feel intentional rather than incidental.

**Requirements:** R2, R3, R4

**Dependencies:** Unit 2

**Files:**
- Modify: `App/AutoMode/AutoModeView.swift`
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Modify: `App/Marketplace/MarketplaceTeaserView.swift`
- Modify: `App/Marketplace/MarketplaceView.swift`
- Modify: `App/ExpertConsole/ExpertConsoleView.swift`

**Approach:**
- Review the existing degraded, stale, and recovery states now exercised by tests and tighten any copy or badge inconsistencies that make the product feel accidental.
- Keep changes narrow and trust-oriented: clarify the current state, the reason the app is holding, and the next action available to the user.
- Do not redesign layout or add new controls; this is state-polish work tied directly to the hardening scenarios.

**Patterns to follow:**
- Preserve the current calm home-first hierarchy in Auto Mode.
- Reuse the existing freshness, hold-reason, and evidence-badge vocabulary rather than introducing a fourth naming system.

**Test scenarios:**
- Happy path: current/recommended states remain visually and textually unchanged where no hardening change is needed.
- Edge case: stale and partial evidence uses consistent badge vocabulary between Auto Mode and Marketplace.
- Error path: failed tunnel or degraded recommendation states present a clear next action instead of generic failure text.
- Integration: Expert Console hold reasons and Auto Mode summary text remain semantically aligned after copy polish.

**Verification:**
- User-visible failure and degraded states read as deliberate product behavior and stay aligned across surfaces.

- [ ] **Unit 4: Add TestFlight release checklist and alpha validation docs**

**Goal:** Create the minimal documentation needed to install, validate, and review the alpha consistently.

**Requirements:** R5, R6

**Dependencies:** Units 1-3

**Files:**
- Create: `docs/release/alpha-testflight-checklist.md`
- Modify: `README.md`
- Modify: `docs/plans/2026-04-04-003-feat-ios-next-sprints-roadmap-plan.md`

**Approach:**
- Write a compact TestFlight checklist that covers install prerequisites, the core validation flow, expected healthy signals, known constraints, and failure/escalation notes for the alpha.
- Keep `README.md` contributor-focused: project shape, evidence model, observability constraint, and where to find the release checklist.
- Update the roadmap to reflect that sprint 5 is the release-hardening endpoint for the current alpha line.

**Patterns to follow:**
- Match the existing concise markdown style used in plans and research docs.
- Keep docs grounded in the actual shipped alpha loop rather than aspirational post-alpha features.

**Test scenarios:**
- Test expectation: none -- this unit is documentation-focused, but the checklist must enumerate concrete install, run, and validation steps plus known constraints.

**Verification:**
- A contributor or tester can install and validate the alpha from repo docs without guessing the trust model or observability limits.

## System-Wide Impact

- **Interaction graph:** the same shared snapshot, recommendation policy, refresh coordination, and evidence projection continue feeding Auto Mode, Expert Console, and Marketplace; sprint 5 mainly strengthens the validation and presentation layers around them.
- **Error propagation:** import failures, tunnel-start failures, stale restores, and degraded evidence must continue surfacing as explicit user-visible states rather than silent fallback.
- **State lifecycle risks:** simulator/test harness instability can obscure real regressions; sprint 5 therefore treats integrated test determinism as part of product quality.
- **API surface parity:** no new public API surfaces should emerge; the current app, extension, and shared engine contracts remain authoritative.
- **Integration coverage:** release readiness depends on proving the same active recommendation story across restore, pinning, marketplace browsing, and failure recovery.
- **Unchanged invariants:** home-first navigation, centralized recommendation policy, binary import validation, shared snapshot truth, and pin-means-no-auto-switch remain fixed.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Combined simulator-run instability is caused by deeper Xcode/simulator behavior, not app code | Isolate the failing interaction first, then adjust test grouping/fixtures only as much as needed to make the gate dependable |
| Hardening work quietly expands into product redesign | Keep scope tied to existing failure/recovery states and reject net-new controls or flows |
| Release docs drift from actual app behavior | Write docs after failure-state and test-gate behavior are finalized, and ground them in the actual validation loop |
| Negative-path coverage becomes too unit-heavy and misses user-visible regressions | Require at least one cross-layer or UI-facing assertion for each trust-sensitive failure class |

## Documentation / Operational Notes

- `docs/release/alpha-testflight-checklist.md` should become the primary alpha handoff artifact for installation and evaluation.
- `README.md` should remain the contributor entry point and link outward to the release checklist and observability memo rather than duplicating them fully.

## Sources & References

- Related plan: `docs/plans/2026-04-04-003-feat-ios-next-sprints-roadmap-plan.md`
- Related plan: `docs/plans/2026-04-04-008-feat-ios-sprint-4-evidence-surfaces-plan.md`
- Related checklist: `docs/plans/2026-04-04-009-feat-ios-sprint-4-evidence-surfaces-checklist.md`
- Related code: `UITests/FirstRunOptimizeFlowTests.swift`
- Related code: `UITests/ManualPinFlowTests.swift`
- Related code: `App/AutoMode/AutoModeViewModel.swift`
- Related code: `Shared/Engine/ClashAdapter.swift`
- Related code: `Shared/Engine/EvidenceProjection.swift`
