---
title: feat: RockeRoom v1 product reset
type: feat
status: completed
date: 2026-04-04
origin: docs/brainstorms/2026-04-04-rockeroom-v1-product-reset-requirements.md
---

# feat: RockeRoom v1 product reset

## Overview

This plan resets RockeRoom from an Auto Mode-first prototype into a conventional v1 proxy-client flow. The current app opens into `AutoModeView`, hides subscription import behind a modal sheet, and pushes `Expert Console` and `Marketplace` as secondary destinations from the same screen. The reset changes the product spine:
- a focused setup screen before import
- automatic entry into a bottom-tab app shell after successful import
- `Home` as the default landing tab
- explicit user-triggered benchmarking
- a simple post-benchmark recommendation card with four user-facing metrics
- `Expert Console` as the deeper inspection/manual-control surface
- `Marketplace` as a dummy placeholder tab in v1

The goal is not to replace the current benchmark and recommendation engine. It is to reframe the app around a legible, trustable loop that matches the category expectations captured in the origin document (see origin: `docs/brainstorms/2026-04-04-rockeroom-v1-product-reset-requirements.md`).

## Problem Frame

RockeRoom’s current navigation and copy are backwards for the product it is trying to be. `AppRootView` centers the entire app on `AutoModeView`, and `SubscriptionImportView` only appears as a sheet triggered from that home screen. That forces users to encounter recommendation language and “proof” UI before they have completed the basic task of importing a Clash subscription and running a benchmark. It also makes the first-run path harder than it should be for the simplest, most common action: paste a subscription link and continue.

The reset must fix two classes of problems at once:
- **Information architecture:** move from single-screen/push navigation to a normal tab shell with a dedicated setup-first state.
- **Trust model:** make recommendations visibly downstream of measurement rather than the app’s opening identity.

This also exposes one technical constraint that planning cannot ignore: the current probe/evidence model is effectively latency-only. `ProbeRunner`, `ProofPayload`, `ExpertConsoleViewModel`, and the supporting tests only exercise `latency`. Because the origin requirements intentionally insist on `Latency`, `Jitter`, `Packet Loss`, and `Throughput` for `Home`, the plan must create an explicit metric-contract unit instead of quietly faking the UI around nonexistent data (see origin: `docs/brainstorms/2026-04-04-rockeroom-v1-product-reset-requirements.md`, R15, R23).

## Requirements Trace

- R1-R8: setup-first root flow, non-modal import, auto-entry into the main shell, `Home` as landing tab
- R9-R12: benchmarking stays manual and recommendation stays downstream of completed measurement
- R13-R17: `Home` remains summary-oriented, shows exactly one recommendation card plus four metrics, and clearly distinguishes unbenchmarked vs benchmarked state
- R18-R20: `Expert Console` remains the dense inspection/manual-control tab and must stay consistent with `Home`
- R21-R23: product language must earn automation through measurement and must not overclaim metrics that are not honestly measured

## Scope Boundaries

- No background or continuous benchmark loop
- No attempt to complete Marketplace as a real product surface
- No final resolution of the long-term `Expert Console` ranking model beyond preserving it as the detailed control tab
- No manual node/provider controls on `Home`
- No change to the underlying Clash import pipeline or tunnel start contract unless required to support the new shell or metric contract

## Context & Research

### Relevant Code and Patterns

- `App/AppRootView.swift` currently owns the root navigation, import-sheet presentation, and push navigation to `Expert Console`, `Why This`, and `Marketplace`. This is the primary seam for the reset.
- `App/RockeRoomApp.swift` already owns restore/foreground lifecycle handling through `AutoModeViewModel`; the reset should preserve this bootstrap pattern rather than introducing a second state owner.
- `App/AutoMode/AutoModeView.swift` is the current “home” surface, but its layout and language are too tied to Auto Mode identity to be repurposed wholesale. It is a source of useful sub-states, not the destination architecture.
- `App/AutoMode/AutoModeViewModel.swift` already contains the important state transitions: imported vs ready vs optimizing, persisted snapshot restore, stale refresh hinting, failure messaging, pin state, and recommendation reevaluation. The plan should continue using it as the core orchestration seam or extract a thinner home-facing adapter from it rather than reimplementing those rules.
- `App/ExpertConsole/ExpertConsoleView.swift` and `App/ExpertConsole/ExpertConsoleViewModel.swift` already reserve the right product location for ranked candidates, evidence rows, and pin/unpin control.
- `App/Marketplace/MarketplaceView.swift` and `App/Marketplace/MarketplaceTeaserView.swift` currently render the same evidence graph as the rest of the product. v1 should collapse this into a dummy tab, which reduces scope rather than growing it.
- Existing tests already cover restore, stale evidence, failed tunnel start, pin/unpin, and UI import/optimize flows in `Tests/AppSessionRestoreTests.swift`, `Tests/AutoModeViewModelTests.swift`, `UITests/FirstRunOptimizeFlowTests.swift`, and `UITests/ManualPinFlowTests.swift`. They are strong leverage, but many assertions are anchored to old copy and old navigation.

### Institutional Learnings

- No `docs/solutions/` directory exists today, so there are no durable repo learnings to carry forward.
- The recently shipped alpha hardening work established that the repo already has trustworthy restore/failure test seams. The reset should reuse that behavioral core rather than tearing it out.

### External References

- Earlier category research during brainstorm found that comparable apps expose visible benchmark results and let automation follow measured performance instead of leading the story. That supports the origin decisions around manual benchmark triggering, summary-on-home, and detailed inspection in a separate surface.
- No further framework-specific external research is needed for this plan. The work is mostly SwiftUI information architecture and local state composition, and the codebase already has strong local patterns for those seams.

## Key Technical Decisions

- **Introduce an explicit app-shell state instead of overloading `AutoModeView`:** the root should model “setup required” versus “main shell available” directly, because the pre-import and post-import experiences have different information architecture.
- **Keep one source of truth for operational state:** `AutoModeViewModel` already knows whether a subscription exists, whether a benchmark has run, and whether evidence is stale. The plan should expose those states to `Home` and the shell rather than duplicating orchestration in another view model.
- **Treat `Home` as a summary adapter, not a renamed `AutoModeView`:** the new home screen should consume recommendation/metric state and offer benchmark actions, but should not carry proof cards, marketplace teaser logic, or deep control UI.
- **Make the metric contract explicit before redesigning the cards:** `Latency`, `Jitter`, `Packet Loss`, and `Throughput` must map to real `ProbeMetric` values and a stable rendering contract. If `Throughput` cannot be measured honestly enough from the existing probe executor, the implementation must either relabel it clearly or stage it behind a documented fallback path to satisfy R23.
- **Preserve existing recommendation, stale-data, and pinning rules:** the UX changes should not silently rewrite recommendation policy behavior; they should re-present it more clearly.
- **Reduce Marketplace scope aggressively:** the v1 `Marketplace` tab should be a static or near-static placeholder, because the origin document explicitly removed it from the product loop.

## Open Questions

### Resolved During Planning

- **Should the reset keep the current Auto Mode-first navigation?** No. The shell must become setup-first and tab-based (see origin: `docs/brainstorms/2026-04-04-rockeroom-v1-product-reset-requirements.md`).
- **Should benchmarking remain automatic after import?** No. The first and subsequent benchmark runs stay manual-only in v1.
- **Should `Home` include manual node selection?** No. Manual control remains in `Expert Console`.
- **Should `Marketplace` be treated as a real v1 surface?** No. It is a dummy placeholder tab only.

### Deferred to Implementation

- **Metric honesty for throughput:** the implementation must validate whether the current probe stack can produce a defensible throughput number. If not, it must apply the fallback policy defined in Unit 1 rather than inventing precision.
- **How much of `AutoModeViewModel` should be split into a home-specific presenter:** this is an implementation-time shaping choice as long as a single operational source of truth remains.
- **Whether the dummy `Marketplace` tab is fully static or lightly informed by current app state:** either is acceptable if it clearly reads as incomplete and does not pull users into the main loop.
- **Exact `Expert Console` ranking semantics:** still intentionally deferred by the origin document.

## High-Level Technical Design

> This is directional design guidance for review, not implementation specification.

```text
app launch
    -> restore persisted subscription + benchmark/tunnel state
    -> if no subscription
          show focused setup screen
       else
          show tab shell
              Home
              Expert Console
              Marketplace

Home
    -> no benchmark yet
          show imported subscription + "Run Benchmark"
       benchmark complete
          show one recommendation card
          show 4 metric summaries
          show refresh action

Expert Console
    -> same underlying snapshot/recommendation/pin truth
    -> deeper evidence + pin/unpin/manual control

Marketplace
    -> dummy placeholder only

metric contract
    -> define home-facing metrics from ProbeMetric inventory
    -> if throughput is not honest enough
          label or fallback explicitly
```

## Implementation Units

- [ ] **Unit 1: Define the v1 metric contract and benchmark summary model**

**Goal:** Create the data contract that powers `Home` so the new UI is built on real, consistent benchmark evidence rather than hard-coded or latent assumptions.

**Requirements:** R9-R17, R20-R23

**Dependencies:** Existing `ResultSnapshot`, `ProbeMetric`, recommendation policy, and proof/evidence graph

**Files:**
- Modify: `Shared/Domain/ProofPayload.swift`
- Modify: `Shared/Engine/ProbeRunner.swift`
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Modify: `App/ExpertConsole/ExpertConsoleViewModel.swift`
- Modify: `Tests/ProbeRunnerTests.swift`
- Modify: `Tests/AutoModeViewModelTests.swift`
- Modify: `Tests/RecommendationPolicyTests.swift`
- Modify: `Tests/MarketplaceEvidenceProjectionTests.swift`
- Create: `Tests/HomeSummaryMetricTests.swift`

**Approach:**
- Audit the existing `ProbeMetric` production path and formalize which metrics are guaranteed after a successful benchmark.
- Add a home-facing summary representation that exposes exactly four display slots: `Latency`, `Jitter`, `Packet Loss`, and `Throughput`.
- Define a fallback policy for any slot that is not currently measurable with enough honesty. The fallback must be explicit in code and copy rather than leaving the UI to infer missing meaning.
- Keep the underlying recommendation state and proof machinery aligned with this metric inventory so `Home` and `Expert Console` do not drift into different stories.

**Patterns to follow:**
- Reuse `ResultSnapshot` and `ProbeMetric` as the canonical evidence container rather than inventing a parallel benchmark result type.
- Follow the existing `AutoModeViewModel` pattern of deriving user-facing text/state from recommendation and runtime truth.

**Test scenarios:**
- Happy path: after a successful benchmark, the home summary exposes exactly four metrics in the expected order with stable formatting.
- Happy path: the same metric names and values used on `Home` remain visible in `Expert Console` evidence rows where applicable.
- Edge case: partial or degraded benchmark data still produces a coherent summary model without silently fabricating values.
- Error path: when throughput cannot be computed honestly, the fallback policy is rendered explicitly and does not claim a measured number.
- Integration: recommendation proof and benchmark summary remain semantically aligned when the selected candidate changes.

**Verification:**
- An implementer can design `Home` against one stable benchmark-summary contract rather than view-specific ad hoc formatting.

- [ ] **Unit 2: Replace the Auto Mode-first root with a setup-first app shell**

**Goal:** Restructure the root navigation so the app shows a focused import experience before subscription setup and a bottom-tab shell afterward.

**Requirements:** R1-R8, R21-R22

**Dependencies:** Unit 1 for the unbenchmarked vs benchmarked home state contract

**Files:**
- Modify: `App/AppRootView.swift`
- Modify: `App/RockeRoomApp.swift`
- Modify: `App/Import/SubscriptionImportView.swift`
- Create: `App/Home/HomeView.swift`
- Create: `App/Home/SetupHomeView.swift`
- Create: `App/Shell/MainTabView.swift`
- Modify: `UITests/FirstRunOptimizeFlowTests.swift`
- Create: `Tests/AppRootNavigationTests.swift`

**Approach:**
- Replace the current `NavigationStack`-driven “Auto Mode as home” structure with an explicit branch:
  - no stored/imported subscription -> focused setup screen
  - stored/imported subscription -> tab shell
- Move import out of modal-sheet-first flow and make it the main content of the setup state.
- Keep lifecycle restore in `RockeRoomApp` but make tab selection explicit so `Home` is the default tab on fresh import and reopen.
- Reserve `Expert Console` and `Marketplace` as sibling tabs, not pushed destinations.

**Patterns to follow:**
- Preserve the current app bootstrap in `RockeRoomApp.swift` for restore and foreground refresh.
- Keep the import action routed through the existing importer and repository logic in `AutoModeViewModel`.

**Test scenarios:**
- Happy path: fresh launch with no stored subscription lands on the focused setup screen with a paste-friendly import field.
- Happy path: successful import automatically transitions into the tab shell and selects `Home`.
- Happy path: app relaunch with an existing subscription reopens directly into the tab shell on `Home`.
- Edge case: invalid import remains in setup state and shows a recoverable error without requiring a modal dismissal.
- Integration: restore after prior successful import still executes lifecycle refresh before the shell renders benchmark state.

**Verification:**
- The app’s first-run and normal reopen paths match the conventional flow defined in the origin requirements.

- [ ] **Unit 3: Build the new Home tab around explicit benchmark action and simple recommendation summary**

**Goal:** Replace the current proof-heavy Auto Mode screen with a summary-oriented `Home` that makes benchmarking explicit and keeps the post-benchmark state legible.

**Requirements:** R8-R17, R21-R22

**Dependencies:** Units 1-2

**Files:**
- Create: `App/Home/HomeViewModel.swift`
- Create: `App/Home/HomeView.swift`
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Modify: `UITests/FirstRunOptimizeFlowTests.swift`
- Create: `UITests/HomeBenchmarkFlowTests.swift`
- Create: `Tests/HomeViewModelTests.swift`

**Approach:**
- Introduce a dedicated home-facing presentation layer that consumes the existing operational state and emits:
  - imported but unbenchmarked
  - benchmarking in progress
  - benchmark complete with recommendation
  - benchmark failed or degraded
- Make the primary action `Run Benchmark` before any benchmark exists, then `Refresh Benchmark` or equivalent after a result exists.
- Show a single recommendation card and exactly four top-line metrics after benchmarking.
- Remove deep proof cards, “Why this?” routing, and direct marketplace teaser behavior from `Home`.

**Patterns to follow:**
- Follow the current view-model-driven state mapping style in `AutoModeViewModel` instead of burying state logic inside SwiftUI view conditionals.
- Preserve the existing stale/failure messaging semantics where still true, but rewrite copy into conventional category language rather than Auto Mode branding.

**Test scenarios:**
- Happy path: imported subscription with no benchmark shows a clear `Run Benchmark` call to action and no fabricated recommendation.
- Happy path: completing a benchmark shows one recommendation card and exactly four metric summaries.
- Edge case: stale restored evidence is visually distinct from “never benchmarked” and still allows explicit refresh.
- Error path: failed benchmark attempt keeps the user on `Home`, preserves import state, and offers a clear retry path.
- Integration: rerunning the benchmark updates the recommendation card and summary metrics without requiring navigation away from `Home`.

**Verification:**
- `Home` reads like a normal benchmark summary screen instead of a partial expert dashboard.

- [ ] **Unit 4: Reframe Expert Console as the detailed inspection/manual-control tab**

**Goal:** Keep `Expert Console` as the place for deeper evidence and pinning, while aligning its information with the new `Home` metric story.

**Requirements:** R18-R20

**Dependencies:** Units 1-3

**Files:**
- Modify: `App/ExpertConsole/ExpertConsoleView.swift`
- Modify: `App/ExpertConsole/ExpertConsoleViewModel.swift`
- Modify: `UITests/ManualPinFlowTests.swift`
- Create: `Tests/ExpertConsoleConsistencyTests.swift`

**Approach:**
- Preserve the current ranked-candidate and pin/unpin interaction model for v1.
- Update sectioning, labels, and metric presentation so `Expert Console` feels like the detailed companion to `Home`, not a leftover from a different product concept.
- Ensure the currently selected/recommended/pinned stories remain aligned with the same metric inventory and recommendation state exposed on `Home`.

**Patterns to follow:**
- Reuse the existing `CandidateRow` and current/pinned/recommended badge semantics where they still fit.
- Keep manual control confined here, as already established by the origin decisions.

**Test scenarios:**
- Happy path: after benchmarking, `Expert Console` shows ranked candidates plus evidence rows that match `Home`’s metric vocabulary.
- Happy path: pin and unpin still change the current setup and recommendation hold state correctly.
- Edge case: opening `Expert Console` before any benchmark has run shows an intentional empty/dormant state rather than stale Auto Mode copy.
- Integration: state changes initiated from pin/unpin are reflected back on `Home` without conflicting badges or copy.

**Verification:**
- `Expert Console` remains the power-user tab without leaking that density back into `Home`.

- [ ] **Unit 5: Collapse Marketplace into a true dummy tab**

**Goal:** Remove Marketplace from the main evidence loop and replace it with a clearly incomplete placeholder surface that does not pretend to be a shipped feature.

**Requirements:** R3-R5

**Dependencies:** Unit 2

**Files:**
- Modify: `App/Marketplace/MarketplaceView.swift`
- Delete or retire from flow: `App/Marketplace/MarketplaceTeaserView.swift`
- Modify: `UITests/FirstRunOptimizeFlowTests.swift`
- Create: `Tests/MarketplacePlaceholderTests.swift`

**Approach:**
- Replace the current evidence-driven Marketplace screen with a simple placeholder that clearly communicates “not part of the v1 loop yet”.
- Remove Marketplace teaser content from `Home` entirely.
- Keep the tab present in the shell so the information architecture matches the origin decision, but do not preserve old evidence cards just because they already exist.

**Patterns to follow:**
- Prefer scope reduction over compatibility with the previous teaser design.
- Keep the placeholder visually consistent with the rest of the v1 shell without adding fake interactivity.

**Test scenarios:**
- Happy path: the tab exists in the bottom bar and opens a placeholder screen.
- Edge case: pre-benchmark and post-benchmark states do not change Marketplace into a pseudo-functional surface.
- Integration: removing the teaser from `Home` does not break shell navigation or test setup.

**Verification:**
- Marketplace is visibly a dummy tab and no longer competes with the core v1 loop.

## System-Wide Impact

- **Navigation graph:** the app moves from single-root push navigation to an explicit two-state root plus bottom-tab shell.
- **State lifecycle:** restore, stale-data decay, failure messaging, and pinning remain anchored in the same operational view model, but will feed different presentation layers.
- **Metric contract:** benchmark evidence becomes more important because `Home` is explicitly built around four named metrics; this raises the bar for consistency and honesty.
- **Test impact:** both unit and UI suites need meaningful rewrites because many current assertions encode the old Auto Mode-first copy and navigation.
- **Risk concentration:** the highest risk is not SwiftUI tab wiring; it is accidentally presenting four “benchmark” metrics that the current probe stack does not truly measure.
- **Unchanged invariants:** import validation, persisted subscription restore, recommendation policy behavior, and pin-means-no-auto-switch remain authoritative.

## Recommended Execution Order

1. Unit 1: lock the metric contract before redesigning views.
2. Unit 2: establish the setup-first root and tab shell.
3. Unit 3: build the new `Home` against the new shell and summary model.
4. Unit 4: align `Expert Console` with the new vocabulary and tab role.
5. Unit 5: downgrade `Marketplace` to a real placeholder and remove teaser coupling.
