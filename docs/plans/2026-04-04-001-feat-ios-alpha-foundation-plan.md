---
title: feat: Build iOS alpha foundation
type: feat
status: active
date: 2026-04-04
---

# feat: Build iOS alpha foundation

## Overview

Build the first sprint of RockeRoom as an iOS-first alpha foundation: a native app shell, a packet-tunnel integration boundary around Clash, a scoring and recommendation pipeline, a trust-first Auto Mode screen, and the minimum supporting tests needed to prove the core loop end to end.

This sprint is not a prototype toy. It should leave the repo in a shape where future work can add deeper observability, richer expert tooling, and curated marketplace content without rewriting the first sprint.

## Problem Frame

RockeRoom's product promise is stronger than "another proxy client." It needs to accept a Clash subscription link, fetch and validate provider data, evaluate connection quality against real app-adjacent experiences, recommend the best current setup, and explain that recommendation honestly. The design and engineering reviews already narrowed the first release shape:

- Auto Mode is the home screen
- Expert Console is a secondary inspect surface
- Marketplace is tertiary and read-only
- Clash is the v1 execution core
- Recommendation behavior must be centralized
- Binary import validation, no silent partial imports
- Manual pin means no auto-switch

Sprint 1 should therefore establish the product's trust boundary and technical spine, not chase the full long-term platform story.

## Requirements Trace

- R1. Create a runnable iOS app and packet-tunnel foundation using native Apple primitives and a Clash-backed execution boundary.
- R2. Support strict Clash subscription link import with deterministic accept/reject behavior and clear user recovery paths.
- R3. Implement a normalized probe -> score -> recommend pipeline with freshness and confidence handling.
- R4. Ship a trust-first Auto Mode screen that can run optimize, show 2-3 inline proof deltas, and drill into "Why this?"
- R5. Establish a secondary Expert Console shell that reads the same shared result snapshot without owning separate refresh logic.
- R6. Preserve user sovereignty: pinned providers never auto-switch.
- R7. Add sprint-1 tests for import policy, recommendation policy, freshness regressions, honesty UI behavior, and key first-run E2E flows.
- R8. Leave marketplace behavior read-only and minimal for this sprint.

## Scope Boundaries

- No seller onboarding, payments, or user-published strategy marketplace
- No cross-platform work beyond the iOS-first structure
- No deep per-app private telemetry beyond what the current observability research proves feasible
- No full Expert Console feature set beyond shell, ranking surface, and manual override path
- No visual polish pass beyond what is necessary to implement the approved hierarchy and trust states

## Context & Research

### Relevant Code and Patterns

- The repo is effectively empty today, so this plan must define the initial application structure instead of following local app patterns.
- `TODOS.md` already captures the deeper iOS observability spike and should be treated as an active constraint on how far this sprint leans on app-specific measurement claims.

### Institutional Learnings

- Earlier planning decisions already established that the tunnel layer should stay boring while RockeRoom differentiates in scoring, recommendation, and proof UX.
- The design review clarified that Auto Mode, Expert Console, and Marketplace must all read as one coherent product rather than three equal destinations.

### External References

- Apple `NEPacketTunnelProvider` tunnel lifecycle and startup contract:
  - https://developer.apple.com/documentation/networkextension/nepackettunnelprovider/starttunnel%28options%3Acompletionhandler%3A%29
- Apple Network Extension deployment constraints and TN3134 release considerations:
  - https://developer.apple.com/news/site-updates/?id=08192025a
- Clash-compatible core / mihomo configuration references for provider and rule-provider structures:
  - https://wiki.metacubex.one/en/config/proxy-providers/
  - https://wiki.metacubex.one/en/config/rule-providers/content/
  - https://wiki.metacubex.one/en/config/rules/

## Key Technical Decisions

- **Use Clash as the v1 execution core:** RockeRoom owns the adapter, policy, scoring, and UI layers rather than re-implementing tunnel/runtime behavior.
- **Keep recommendation policy centralized:** import validity, switch/no-switch, freshness, confidence, and proof payload all come from one policy layer.
- **Use binary import validation in sprint 1:** subscription content is either accepted or rejected with a clear reason; partially valid payloads do not silently proceed.
- **Share one result snapshot across surfaces:** Auto Mode, Expert Console, and marketplace evidence all read the same normalized snapshot with freshness metadata.
- **Treat the first sprint as alpha foundation, not marketplace build-out:** this keeps the work inside one coherent sprint and preserves future optionality.

## Open Questions

### Resolved During Planning

- **Sprint depth:** Use the alpha-foundation version of sprint 1 rather than a thin demo loop.
- **Execution core:** Use Clash, not a custom tunnel engine.
- **Import policy:** Use strict binary accept/reject.
- **Manual override behavior:** Pinned providers never auto-switch.
- **Freshness behavior:** Add a dedicated regression suite instead of relying on incidental score coverage.
- **Honesty UI:** Add explicit UI tests for simplified Auto Mode uncertainty and richer Expert Console uncertainty.

### Deferred to Implementation

- **Exact Clash embedding strategy on iOS:** whether the first runnable integration wraps an existing iOS Clash-compatible client layer or a thinner internal bridge depends on what is feasible in the initial app shell.
- **Exact app-experience probe set:** the scoring categories are known, but the specific endpoints and thresholds should be finalized while building the probe runner.
- **Exact confidence copy:** the plan requires the behavior and test coverage, but exact wording can be finalized during implementation.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```text
                     +----------------------+
                     |   Auto Mode Screen   |
                     +----------+-----------+
                                |
                                v
                     +----------------------+
                     | Recommendation VM    |
                     +----------+-----------+
                                |
                                v
                     +----------------------+
                     | RecommendationPolicy |
                     +----------+-----------+
                                |
                  +-------------+--------------+
                  |                            |
                  v                            v
        +--------------------+      +----------------------+
        | ResultSnapshotStore|<-----| ProbeRunner          |
        +---------+----------+      +----------+-----------+
                  |                            |
                  v                            v
        +--------------------+      +----------------------+
        | Shared proof data   |      | ClashAdapter        |
        +---------+----------+      +----------+-----------+
                  |                            |
                  v                            v
        +--------------------+      +----------------------+
        | Expert Console VM  |      | PacketTunnelProvider |
        +--------------------+      +----------------------+
```

Import and switching rules:

```text
Imported config
  ├── valid      -> allow tunnel setup + scoring
  └── invalid    -> reject + recovery UI

Recommendation result
  ├── no pin + confidence threshold met -> may switch
  ├── no pin + confidence low           -> hold current setup
  └── pin active                        -> notify only, no auto-switch
```

## Implementation Units

- [ ] **Unit 1: Create the native iOS and tunnel project skeleton**

**Goal:** Establish the baseline project structure for the iOS app, packet-tunnel extension, shared domain modules, and test targets.

**Requirements:** R1, R7

**Dependencies:** None

**Files:**
- Create: `RockeRoom.xcodeproj/project.pbxproj`
- Create: `App/RockeRoomApp.swift`
- Create: `App/AppRootView.swift`
- Create: `Extension/PacketTunnelProvider.swift`
- Create: `Shared/Domain/`
- Create: `Shared/Engine/`
- Create: `Tests/`
- Create: `UITests/`

**Approach:**
- Create a minimal but durable Xcode project layout with separate app, extension, shared code, unit tests, and UI tests.
- Keep the initial app root intentionally small so later screens can attach without refactoring startup code.
- Add the packet-tunnel extension target early so later units are working against the real distribution shape, not a fake single-target app.

**Patterns to follow:**
- Apple `NEPacketTunnelProvider` lifecycle expectations.
- Standard iOS app + extension separation, with shared logic kept outside UI and extension entry points.

**Test scenarios:**
- Happy path: app target launches to the root navigation shell.
- Happy path: packet-tunnel target builds with the expected extension entry point.
- Integration: shared modules can be imported by both app and extension targets without circular dependency issues.
- Error path: misconfigured target membership is caught by CI/build verification before later units pile onto the wrong structure.

**Verification:**
- The repo contains a compilable project structure with app, extension, shared code, unit-test target, and UI-test target.

- [ ] **Unit 2: Build strict Clash subscription import and canonical config modeling**

**Goal:** Accept Clash subscription links only when the fetched subscription data can be safely normalized into one internal model that the rest of the product can trust.

**Requirements:** R2, R6, R7

**Dependencies:** Unit 1

**Files:**
- Create: `Shared/Domain/SubscriptionConfig.swift`
- Create: `Shared/Domain/SubscriptionImportResult.swift`
- Create: `Shared/Engine/ClashSubscriptionImporter.swift`
- Modify: `App/AppRootView.swift`
- Create: `App/Import/SubscriptionImportView.swift`
- Test: `Tests/ClashSubscriptionImporterTests.swift`
- Test: `UITests/SubscriptionImportFlowTests.swift`

**Approach:**
- Define one canonical internal config model for imported Clash subscription data and reject anything that cannot be normalized cleanly.
- Keep import result states explicit so UI can distinguish successful import from rejected import without inventing extra logic.
- Wire the first-run empty state to this importer so the user can recover immediately from invalid input.

**Execution note:** Implement the import policy test-first because this is a hard trust boundary and the app should not evolve around ambiguous parsing behavior.

**Patterns to follow:**
- Binary accept/reject import policy already decided in review.
- Shared domain model used by downstream engine and UI layers rather than format-specific branches.

**Test scenarios:**
- Happy path: valid Clash subscription link fetches successfully, parses into the canonical model, and becomes available for optimize.
- Edge case: empty or unreachable subscription response is rejected with a clear reason.
- Edge case: unsupported but syntactically valid subscription fields still produce rejection if they would affect runtime behavior.
- Error path: malformed subscription content rejects cleanly without creating partially usable state.
- Integration: first-run empty state transitions into a successful import state after a valid subscription link import.
- Integration: first-run invalid subscription link path shows recovery UI and leaves no active provider behind.

**Verification:**
- The app can accept a valid Clash subscription link, reject an invalid one deterministically, and never produce a partially trusted provider state.

- [ ] **Unit 3: Add the Clash adapter, probe runner, and shared result snapshot**

**Goal:** Establish the core measurement pipeline and shared snapshot model that all surfaces will read.

**Requirements:** R1, R3, R5, R7

**Dependencies:** Units 1-2

**Files:**
- Create: `Shared/Engine/ClashAdapter.swift`
- Create: `Shared/Engine/ProbeRunner.swift`
- Create: `Shared/Engine/ResultSnapshot.swift`
- Create: `Shared/Engine/ResultSnapshotStore.swift`
- Modify: `Extension/PacketTunnelProvider.swift`
- Test: `Tests/ProbeRunnerTests.swift`
- Test: `Tests/ResultSnapshotStoreTests.swift`

**Approach:**
- Define a narrow adapter boundary around Clash so later engine changes do not leak through the app.
- Keep probe execution and snapshot normalization separate: the runner gathers signals, the snapshot store owns freshness metadata and shared read access.
- Ensure Auto Mode, Expert Console, and later marketplace evidence all read the same normalized result snapshot rather than triggering independent measurements.

**Technical design:** *(directional guidance, not implementation specification)*

```text
ClashAdapter
  ├── start(using canonical config)
  ├── stop()
  └── currentStatus()

ProbeRunner
  ├── run candidate probes
  ├── normalize raw timings / successes
  └── emit ResultSnapshotCandidate

ResultSnapshotStore
  ├── persist latest snapshot
  ├── annotate freshness
  └── serve same snapshot to all consumers
```

**Patterns to follow:**
- Shared snapshot, not surface-owned refreshes.
- Boring engine boundary, custom intelligence above it.

**Test scenarios:**
- Happy path: valid config starts the adapter and produces a result snapshot candidate.
- Edge case: one probe times out while others succeed and the snapshot still records partial measurement state.
- Edge case: bounded concurrency stops early once decisive results are reached.
- Error path: adapter start failure surfaces a structured error path without corrupting prior snapshot state.
- Integration: Auto Mode and Expert Console read the same snapshot instance and freshness metadata.
- Integration: snapshot freshness updates without duplicating probe execution per surface.

**Verification:**
- The system can start the execution core, run normalized probes, and expose one shared snapshot source for downstream policy and UI work.

- [ ] **Unit 4: Implement recommendation policy, freshness regressions, and pinning logic**

**Goal:** Turn raw snapshots into trustworthy product behavior with centralized recommendation policy.

**Requirements:** R3, R5, R6, R7

**Dependencies:** Unit 3

**Files:**
- Create: `Shared/Engine/RecommendationPolicy.swift`
- Create: `Shared/Domain/RecommendationState.swift`
- Create: `Shared/Domain/ProofPayload.swift`
- Test: `Tests/RecommendationPolicyTests.swift`
- Test: `Tests/FreshnessRegressionTests.swift`
- Test: `Tests/PinningPolicyTests.swift`

**Approach:**
- Centralize ranking, confidence thresholds, stale-data behavior, proof payload generation, and pin/no-switch rules into one recommendation policy layer.
- Keep the policy outputs structured enough that UI layers only render them rather than improvising business logic.
- Separate freshness-specific regressions from general scoring tests so stale-data trust behavior cannot silently rot.

**Execution note:** Start with failing unit tests for freshness, confidence, and pinning behavior before implementing policy logic.

**Technical design:** *(directional guidance, not implementation specification)*

```text
RecommendationPolicy(snapshot, currentState, pinState)
  ├── score candidate results
  ├── apply freshness / confidence gates
  ├── if pinned -> never switch
  ├── if delta insignificant -> hold
  ├── if confidence low -> hold with warning
  └── emit:
        - recommendation state
        - proof payload
        - console detail payload
```

**Patterns to follow:**
- Single recommendation policy layer.
- Freshness and confidence are explicit trust mechanics, not secondary metadata.

**Test scenarios:**
- Happy path: better fresh result above threshold produces a recommendation change.
- Edge case: lower-confidence but nominally faster result does not force a switch.
- Edge case: pinned provider blocks auto-switch while still allowing better-option notification.
- Edge case: unpin resumes policy-owned switching.
- Error path: missing or partial snapshot yields a safe hold/partial state rather than a false confident recommendation.
- Integration: proof payload uses the same winning snapshot and does not drift from recommendation state.
- Integration: stale snapshot receives badge-worthy stale state and decayed ranking behavior.

**Verification:**
- One policy layer fully determines whether the app switches, holds, warns, or only notifies, and this behavior is regression-tested.

- [ ] **Unit 5: Ship Auto Mode, Expert Console shell, and the sprint E2E loop**

**Goal:** Build the first user-facing loop that proves RockeRoom's trust-first product shape.

**Requirements:** R4, R5, R6, R7, R8

**Dependencies:** Units 2-4

**Files:**
- Create: `App/AutoMode/AutoModeView.swift`
- Create: `App/AutoMode/AutoModeViewModel.swift`
- Create: `App/AutoMode/WhyThisView.swift`
- Create: `App/ExpertConsole/ExpertConsoleView.swift`
- Create: `App/ExpertConsole/ExpertConsoleViewModel.swift`
- Create: `App/Marketplace/MarketplaceTeaserView.swift`
- Test: `Tests/AutoModeViewModelTests.swift`
- Test: `Tests/ExpertConsoleViewModelTests.swift`
- Test: `Tests/HonestyUITests.swift`
- Test: `UITests/FirstRunOptimizeFlowTests.swift`
- Test: `UITests/ManualPinFlowTests.swift`

**Approach:**
- Implement Auto Mode as the trust-first home screen with import, optimize, inline proof, freshness summary, and "Why this?" drilldown.
- Implement Expert Console as a secondary inspect surface using the same shared snapshot and richer uncertainty detail.
- Keep marketplace scope to a teaser/read-only evidence panel so the sprint proves the information architecture without building commerce.

**Patterns to follow:**
- Home-first navigation
- Auto Mode simplified uncertainty
- Expert Console full uncertainty
- Inline proof limited to 2-3 key deltas plus drilldown

**Test scenarios:**
- Happy path: first-run import -> optimize -> recommendation -> inline proof -> drilldown works end to end.
- Happy path: Expert Console becomes available after first successful recommendation.
- Edge case: low-confidence recommendation still shows honest simplified warning in Auto Mode.
- Edge case: Expert Console shows richer uncertainty from the same underlying result.
- Edge case: user pins a provider, sees a better option notification, and the app does not auto-switch.
- Error path: optimize failure shows recovery UI rather than a dead-end or empty recommendation card.
- Integration: inline proof and "Why this?" both reflect the same policy output.
- Integration: marketplace teaser reads the shared snapshot evidence model without owning its own measurement logic.

**Verification:**
- A user can go from first launch to trusted recommendation on iPhone, inspect why the app chose it, pin manually, and see the app respect that decision.

## System-Wide Impact

- **Interaction graph:** `ProviderConfigImporter` feeds canonical config into `ClashAdapter`; `ProbeRunner` produces normalized results; `ResultSnapshotStore` feeds both Auto Mode and Expert Console; `RecommendationPolicy` owns switch and proof behavior.
- **Error propagation:** import, tunnel startup, probe failures, and stale-data conditions should all surface as structured result states rather than thrown UI surprises.
- **State lifecycle risks:** stale snapshots, pin state persistence, and tunnel restart timing are the key lifecycle edges.
- **API surface parity:** both user-facing surfaces must reflect the same underlying result snapshot and recommendation state, even when they render uncertainty differently.
- **Integration coverage:** first-run import/optimize, pin/no-switch, stale-data behavior, and proof payload parity all need integration or UI coverage.
- **Unchanged invariants:** sprint 1 does not add marketplace write flows, payments, or deep app-private telemetry assumptions.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Clash integration on iOS is slower or trickier than expected | Keep the adapter boundary narrow and validate integration in Unit 3 before expanding UI expectations |
| Recommendation quality feels arbitrary early | Build freshness and confidence behavior into the policy and prove it with dedicated regressions |
| Auto Mode and Expert Console drift apart | Force both surfaces to read the same snapshot and policy outputs |
| Early UI work overreaches into full marketplace scope | Keep marketplace to a teaser/read-only unit in this sprint |
| Observability assumptions exceed what Apple allows | Respect `TODOS.md` as a blocking research constraint for anything beyond synthetic or app-adjacent probes |

## Documentation / Operational Notes

- Add a short setup/readme note once the Xcode project structure exists so future contributors know where app, extension, shared code, and tests live.
- Treat TestFlight distribution as the initial release target for sprint validation; App Store packaging details can remain lighter until the core loop is stable.
- Keep the observability spike separate from sprint completion criteria so the sprint can finish even if deeper telemetry remains unresolved.

## Sources & References

- Related repo document: `TODOS.md`
- External planning artifacts consulted outside the repo: approved design review notes and engineering test-plan notes from the same planning session
- Apple docs: `NEPacketTunnelProvider` startup contract and Network Extension deployment notes
- Mihomo / Clash docs: provider config, rule provider config, and rule syntax references
