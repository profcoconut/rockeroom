---
title: feat: Plan iOS next sprints roadmap
type: feat
status: active
date: 2026-04-04
---

# feat: Plan iOS next sprints roadmap

## Overview

Sprint 1 established RockeRoom's alpha foundation: a native iOS app shell, packet-tunnel extension target, shared scoring and recommendation layer, trust-first Auto Mode surface, Expert Console shell, and a passing build/test baseline.

The next sprints should convert that foundation into a truthful product loop:
- replace local demo fetch/probe behavior with real persisted Clash subscription and tunnel lifecycle handling
- complete honest automation, freshness, and manual pin behavior across Auto Mode and Expert Console
- ship marketplace evidence surfaces only after the same shared snapshot can support them honestly
- run the observability spike before any roadmap branch assumes deeper per-app visibility than synthetic probes can prove

## Problem Frame

The current codebase proves shape, not substance. The app still relies on `LocalDevelopmentSubscriptionFetcher` and `DemoProbeExecutor` in `App/AutoMode/AutoModeViewModel.swift`, the extension uses an in-memory Clash engine in `Shared/Engine/ClashAdapter.swift`, and several UI tests are intentionally skipped in `UITests/FirstRunOptimizeFlowTests.swift` and `UITests/ManualPinFlowTests.swift`.

That leaves a gap between "alpha foundation compiles and renders" and "the product can honestly claim to optimize a Clash-backed setup on iOS." The next sprints need to close that gap without violating the design and engineering constraints already decided:

- Auto Mode stays home-first and calm
- Expert Console stays a secondary inspect surface
- Recommendation policy stays centralized
- Pin means no auto-switch
- Shared result snapshots feed all user-facing evidence
- Deeper per-app observability remains unproven until the spike in `docs/research/2026-04-04-ios-observability-spike.md` confirms otherwise

## Requirements Trace

- R1. Replace demo subscription import behavior with a real persisted Clash subscription link workflow.
- R2. Replace the in-memory tunnel/session path with a real app-to-extension tunnel configuration lifecycle suitable for iOS alpha use.
- R3. Persist and refresh result snapshots so freshness, stale warnings, and re-entry behavior are real rather than session-local.
- R4. Complete Expert Console and manual pin flows so they are interactive product behavior, not shell navigation.
- R5. Unskip and expand the first-run, honesty, and pinning UI/E2E tests so the trust boundary is regression-tested end to end.
- R6. Add read-only marketplace evidence surfaces only from the same shared snapshot and recommendation outputs used by Auto Mode and Expert Console.
- R7. Run the deeper iOS observability feasibility spike before roadmap work assumes true per-app private telemetry exists, and capture the answer in `docs/research/2026-04-04-ios-observability-spike.md`.
- R8. Keep product language and scoring claims aligned with what synthetic probes and current iOS constraints can actually prove.

## Scope Boundaries

- No seller onboarding, payments, or user-published strategy marketplace in these next sprints
- No cross-platform client work
- No custom tunnel engine replacing Clash
- No claim of private per-app observability before the spike proves it
- No broad visual redesign beyond the approved design review direction

## Context & Research

### Relevant Code and Patterns

- `project.yml` already defines the correct long-lived target structure: app, packet tunnel extension, shared framework, unit tests, and UI tests.
- `App/AutoMode/AutoModeViewModel.swift` is the main seam between sprint-1 scaffolding and real product behavior. It currently contains both placeholder fetch/probe implementations and the core recommendation flow.
- `Shared/Engine/ClashSubscriptionImporter.swift`, `Shared/Engine/ProbeRunner.swift`, `Shared/Engine/ResultSnapshotStore.swift`, and `Shared/Engine/RecommendationPolicy.swift` are already the canonical shared engine spine and should remain the single source of truth.
- `Extension/PacketTunnelProvider.swift` already accepts serialized `SubscriptionConfig`, so the app-side session manager should be designed around that contract rather than inventing a second configuration format.
- `UITests/FirstRunOptimizeFlowTests.swift` and `UITests/ManualPinFlowTests.swift` already identify the intentionally incomplete flows; those test files should be completed rather than replaced.

### Institutional Learnings

- No `docs/solutions/` knowledge base exists yet, so there are no prior implementation learnings to reuse.
- The existing design and eng review artifacts converge on the same constraints: shared snapshot, centralized recommendation policy, home-first information hierarchy, strict import boundary, and honest freshness/confidence behavior.

### External References

- Apple Network Extension packet tunnel lifecycle and startup contract:
  - https://developer.apple.com/documentation/networkextension/nepackettunnelprovider/starttunnel%28options%3Acompletionhandler%3A%29
- Apple Network Extension manager persistence and configuration model:
  - https://developer.apple.com/documentation/networkextension/netunnelprovidermanager
- Clash-compatible provider configuration references already used in sprint 1:
  - https://wiki.metacubex.one/en/config/proxy-providers/
  - https://wiki.metacubex.one/en/config/rule-providers/content/

## Key Technical Decisions

- **Use a phased roadmap rather than one oversized sprint:** the next work splits naturally into runtime truth, automation trust, evidence surfaces, and release hardening.
- **Keep the shared engine authoritative:** new work should extend `Shared/` rather than moving trust decisions into SwiftUI view models.
- **Introduce app-owned tunnel session management before marketplace expansion:** the product cannot credibly present rankings or evidence while subscription/tunnel state is still ephemeral.
- **Treat the observability spike as a parallel prerequisite, not a hidden assumption:** roadmap work may continue with synthetic probes, but deeper app-specific claims must remain blocked until the research artifact says otherwise.
- **Use the existing skipped UI tests as roadmap checkpoints:** they are already the clearest executable statement of what sprint 1 intentionally deferred.

## Open Questions

### Resolved During Planning

- **Roadmap shape:** use four follow-on sprint units after sprint 1, not one undifferentiated backlog.
- **Near-term product spine:** prioritize real Clash subscription lifecycle and tunnel/session truth before marketplace or richer ranking polish.
- **Marketplace timing:** keep marketplace read-only and evidence-backed until the shared snapshot and recommendation flows are fully real.
- **Observability timing:** run the iOS observability spike in parallel with feature work, but treat it as a gate for deeper app-experience claims and record the decision in-repo.

### Deferred to Implementation

- **Exact persistence mechanism for subscription metadata and latest snapshot:** the plan requires durable local persistence, but the concrete storage choice can be finalized while integrating app and extension code.
- **Exact refresh triggers:** the roadmap requires foreground re-entry and explicit optimize refreshes; whether background refresh is timer-driven, lifecycle-driven, or both should be finalized during implementation.
- **Exact evidence-card schema for marketplace read-only surfaces:** the fields are constrained by shared snapshot outputs, but the final projection model can be shaped once real snapshot persistence exists.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```text
Sprint 1 foundation
  ├── app shell
  ├── shared scoring/policy
  └── extension stub
          │
          ▼
Sprint 2: runtime truth
  ├── persisted subscription link
  ├── tunnel manager/session lifecycle
  └── real import -> configure -> start path
          │
          ▼
Sprint 3: trustworthy automation
  ├── persisted snapshots + refresh
  ├── stale/fresh entry behavior
  ├── completed Expert Console interactions
  └── completed pin/no-switch flows
          │
          ▼
Sprint 4: evidence surfaces
  ├── shared snapshot -> marketplace evidence projection
  ├── observability spike result folded into claims
  └── honest fallback if only synthetic probes are feasible
          │
          ▼
Sprint 5: alpha hardening
  ├── unskipped UI/E2E coverage
  ├── failure-state polish
  └── TestFlight-ready packaging and docs
```

## Phased Delivery

### Phase 1
- Sprint 2: real Clash subscription and tunnel runtime loop

### Phase 2
- Sprint 3: trustworthy automation, persistence, and Expert Console completion

### Phase 3
- Sprint 4: marketplace evidence surfaces and observability decision

### Phase 4
- Sprint 5: alpha hardening and release readiness
  - Current alpha gate is the serialized `RockeRoom` scheme test run with `-parallel-testing-enabled NO`
  - Residual risk is host simulator service instability, not uncovered RockeRoom product assertions

## Implementation Units

- [ ] **Unit 1: Sprint 2 - Real subscription and tunnel session lifecycle**

**Goal:** Replace sprint-1 demo behavior with a real Clash subscription import, persistence, and tunnel configuration lifecycle that the app and extension both understand.

**Requirements:** R1, R2, R8

**Dependencies:** Sprint 1 foundation only

**Files:**
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Modify: `App/Import/SubscriptionImportView.swift`
- Modify: `App/AppRootView.swift`
- Modify: `Extension/PacketTunnelProvider.swift`
- Modify: `Shared/Engine/ClashAdapter.swift`
- Create: `Shared/Engine/TunnelSessionStore.swift`
- Create: `Shared/Engine/SubscriptionRepository.swift`
- Test: `Tests/ClashSubscriptionImporterTests.swift`
- Test: `Tests/ClashAdapterTests.swift`
- Test: `UITests/FirstRunOptimizeFlowTests.swift`

**Approach:**
- Move subscription link fetching and accepted config persistence out of local development stubs into a real repository/session layer.
- Add app-side tunnel session orchestration that serializes accepted `SubscriptionConfig` into the extension configuration boundary and can restore current state on relaunch.
- Keep `ClashAdapter` as the runtime seam, but replace the in-memory-only behavior with a shape that can represent real extension-managed startup, stop, and status.
- Maintain binary accept/reject import behavior while making recovery and relaunch state durable.

**Execution note:** Start with failing tests for persisted import and tunnel-session restoration before replacing the demo path.

**Patterns to follow:**
- Reuse the existing `SubscriptionConfig` serialization contract already consumed by `Extension/PacketTunnelProvider.swift`.
- Extend the existing importer and adapter types in `Shared/` rather than creating app-only parallel models.

**Test scenarios:**
- Happy path: valid Clash subscription link imports, persists, and is available after app relaunch.
- Happy path: accepted config can be handed off to the tunnel extension and startup reports running status back to the app layer.
- Edge case: unreachable subscription URL leaves the previous valid persisted config untouched and surfaces retryable failure state.
- Error path: invalid or malformed subscription content clears pending import state and does not create a tunnel session.
- Integration: first-run import -> optimize path now exercises real session persistence instead of the local development fetcher.
- Integration: app relaunch with a previously accepted subscription restores import state without rerunning manual entry.

**Verification:**
- The app no longer depends on `LocalDevelopmentSubscriptionFetcher` for normal behavior and can restore a previously accepted Clash subscription + tunnel session state.

- [ ] **Unit 2: Sprint 3 - Snapshot persistence, refresh, and interactive Expert Console**

**Goal:** Make freshness, stale warnings, manual pinning, and Expert Console inspection behavior real and durable across launches and re-entry.

**Requirements:** R3, R4, R5, R8

**Dependencies:** Unit 1

**Files:**
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Modify: `App/AutoMode/AutoModeView.swift`
- Modify: `App/ExpertConsole/ExpertConsoleViewModel.swift`
- Modify: `App/ExpertConsole/ExpertConsoleView.swift`
- Modify: `Shared/Engine/ResultSnapshotStore.swift`
- Modify: `Shared/Engine/RecommendationPolicy.swift`
- Create: `Shared/Engine/RefreshCoordinator.swift`
- Test: `Tests/ResultSnapshotStoreTests.swift`
- Test: `Tests/FreshnessRegressionTests.swift`
- Test: `Tests/PinningPolicyTests.swift`
- Test: `Tests/RecommendationPolicyTests.swift`
- Test: `UITests/ManualPinFlowTests.swift`

**Approach:**
- Persist the latest shared snapshot and make freshness decay visible across app relaunch and foreground re-entry.
- Introduce a refresh coordinator that decides when to rerun probes and when to hold stale state with explicit warnings instead of silently presenting old evidence.
- Complete Expert Console interactions so users can inspect current evidence, pin/unpin, and see hold reasons that stay aligned with the centralized recommendation policy.
- Keep Auto Mode simplified while ensuring it reflects the same underlying stale/pinned/low-confidence truth as the console.

**Patterns to follow:**
- Continue using `RecommendationPolicy` as the only place that decides recommended vs held states.
- Keep `ExpertConsoleViewModel` a consumer of shared state rather than a second recommendation engine.

**Test scenarios:**
- Happy path: optimize stores a snapshot that is visible after relaunch and rendered consistently in Auto Mode and Expert Console.
- Happy path: user pins the active candidate in Expert Console and Auto Mode immediately reflects the no-auto-switch hold state.
- Edge case: app reopens with stale snapshot data and shows stale/freshness messaging before a new optimize run completes.
- Edge case: refresh runs with partial probe results and the UI shows partial evidence without claiming certainty.
- Error path: refresh failure preserves the last known snapshot while surfacing degraded state rather than blanking the UI.
- Integration: pin -> better candidate measured -> hold reason remains pinned until unpin.
- Integration: unpin -> next qualifying recommendation can resume auto control using the shared snapshot and policy outputs.

**Verification:**
- Snapshot freshness, pinning, and Expert Console behavior survive app lifecycle transitions and stay aligned with the centralized policy layer.

- [ ] **Unit 3: Sprint 4 - Evidence marketplace and observability decision**

**Goal:** Add read-only marketplace evidence cards backed by the same shared snapshot pipeline, and complete the iOS observability spike so product claims stay honest.

**Requirements:** R6, R7, R8

**Dependencies:** Units 1-2

**Files:**
- Modify: `App/Marketplace/MarketplaceTeaserView.swift`
- Modify: `App/AppRootView.swift`
- Create: `Shared/Engine/EvidenceProjection.swift`
- Create: `App/Marketplace/MarketplaceView.swift`
- Create: `docs/research/2026-04-04-ios-observability-spike.md`
- Modify: `TODOS.md`
- Test: `Tests/MarketplaceEvidenceProjectionTests.swift`
- Test: `UITests/FirstRunOptimizeFlowTests.swift`

**Approach:**
- Project the shared recommendation/snapshot outputs into provider and strategy evidence cards instead of inventing a second ranking source for marketplace surfaces.
- Keep the marketplace read-only and evidence-first: no seller flows, no user submissions, no unsupported ranking claims.
- Run the observability spike as a concrete research artifact in-repo so future roadmap work can reference a durable answer.
- If the spike concludes that only synthetic probes are feasible, explicitly align marketplace and product copy around that fallback instead of vague “app-aware” language.

**Patterns to follow:**
- Reuse the shared snapshot and proof payload model; do not fork marketplace evidence generation from Auto Mode proof logic.
- Follow the design review rule that stale or incomplete evidence must be labeled explicitly.

**Test scenarios:**
- Happy path: marketplace teaser and/or full view render evidence cards derived from the current shared snapshot.
- Edge case: no snapshot yet renders an honest empty-state marketplace teaser rather than fake rankings.
- Edge case: stale or partial snapshots produce stale/missing-evidence badges on marketplace cards.
- Error path: evidence projection fails safely when snapshot content is incomplete and does not crash the app shell.
- Integration: marketplace evidence for the active recommendation matches the same proof and freshness data shown in Auto Mode.
- Integration: observability spike document records explicit success criteria, constraints, and fallback guidance.

**Verification:**
- Marketplace read-only surfaces are backed by shared evidence, and the repo contains a concrete observability decision artifact rather than an unresolved TODO.

- [ ] **Unit 4: Sprint 5 - Alpha hardening and TestFlight readiness**

**Goal:** Turn the now-real flows into a stable alpha candidate with completed regression coverage, unskipped UI tests, and minimal release documentation.

**Requirements:** R5, R8

**Dependencies:** Units 1-3

**Files:**
- Modify: `UITests/FirstRunOptimizeFlowTests.swift`
- Modify: `UITests/ManualPinFlowTests.swift`
- Modify: `Tests/ClashAdapterTests.swift`
- Modify: `Tests/FreshnessRegressionTests.swift`
- Modify: `Tests/RecommendationPolicyTests.swift`
- Create: `docs/release/alpha-testflight-checklist.md`
- Create: `README.md`

**Approach:**
- Replace sprint-1 skip markers with full UI/E2E coverage for first-run import, optimize, Why this, Expert Console, and pin/no-auto-switch flows.
- Add regression coverage for the failure states most likely to undermine trust: stale snapshots, tunnel startup failures, recovery after invalid subscription input, and pin/unpin transitions.
- Add a small release-facing doc set so the alpha can be installed and evaluated consistently.
- Keep the release target TestFlight-grade rather than App Store-grade.

**Patterns to follow:**
- Build on the existing UI test files instead of creating separate duplicates for the same flows.
- Keep verification centered on user-visible outcomes already captured by the design and eng review artifacts.

**Test scenarios:**
- Happy path: valid subscription -> optimize -> recommendation -> Why this -> Expert Console all pass in UI automation.
- Happy path: pin/unpin flow behaves consistently across Auto Mode and Expert Console in UI automation.
- Edge case: invalid subscription import followed by corrected retry reaches a successful optimize flow without app restart.
- Edge case: stale snapshot on launch shows honest warning state before refresh.
- Error path: tunnel startup failure keeps the user in a recoverable state and surfaces a clear message.
- Integration: release checklist covers build, test, and install verification for the alpha candidate.

**Verification:**
- All current skipped UI tests are replaced by real automated coverage, the alpha install/review path is documented, and the app is ready for controlled TestFlight distribution.

## System-Wide Impact

- **Interaction graph:** Auto Mode import/optimize, packet tunnel extension startup, shared snapshot persistence, recommendation policy, Expert Console, and marketplace evidence all remain linked through `Shared/`.
- **Error propagation:** import, tunnel startup, probe execution, and refresh failures must propagate into explicit hold/rejected UI states rather than silent fallback.
- **State lifecycle risks:** persisted subscription data, tunnel configuration, and latest snapshot can drift if app and extension disagree on active config; the roadmap therefore prioritizes a single serialized config/session path.
- **API surface parity:** Auto Mode, Expert Console, marketplace evidence, and the extension must continue consuming the same shared models and recommendation outputs.
- **Integration coverage:** app relaunch, stale snapshot restoration, extension startup, and pin/unpin transitions all require cross-layer tests beyond unit coverage.
- **Unchanged invariants:** the design decisions from sprint 1 remain fixed: home-first navigation, centralized policy, shared snapshot, binary import validation, and pin means no auto-switch.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Tunnel/session integration on iOS proves trickier than the app shell suggests | Isolate runtime/session work in Sprint 2 before taking on marketplace or richer console behavior |
| The observability spike concludes that private per-app telemetry is not feasible | Keep the roadmap grounded in synthetic probes and explicitly align product language and evidence cards with that fallback |
| Shared snapshot persistence drifts from extension state | Introduce a single session/config repository and require relaunch/restore integration tests |
| Marketplace evidence expands scope prematurely | Keep marketplace work read-only and projection-based until the runtime and trust loops are fully real |

## Documentation / Operational Notes

- The observability spike should become an in-repo research artifact so future planning stops depending on a free-floating TODO.
- Alpha release readiness should end with a small TestFlight checklist and top-level README, not a full public launch doc set.

## Sources & References

- Existing sprint plan: `docs/plans/2026-04-04-001-feat-ios-alpha-foundation-plan.md`
- Existing sprint checklist: `docs/plans/2026-04-04-002-feat-ios-alpha-foundation-checklist.md`
- Current gap seam: `App/AutoMode/AutoModeViewModel.swift`
- Current extension boundary: `Extension/PacketTunnelProvider.swift`
- Current runtime stub: `Shared/Engine/ClashAdapter.swift`
- Current shared policy: `Shared/Engine/RecommendationPolicy.swift`
- Current UI/E2E gap markers: `UITests/FirstRunOptimizeFlowTests.swift`, `UITests/ManualPinFlowTests.swift`
- Research dependency: `TODOS.md`
- External design review artifact consulted: `profcoconut-unknown-design-20260404-111949.md`
- External eng review artifact consulted: `profcoconut-unknown-eng-review-test-plan-20260404-113300.md`
