---
title: feat: Detail iOS sprint 4 evidence surfaces
type: feat
status: completed
date: 2026-04-04
---

# feat: Detail iOS sprint 4 evidence surfaces

## Overview

This plan deepens the next roadmap slice after sprint 3. Sprint 3 made runtime truth durable: snapshots persist, stale-state mapping exists, manual pin intent survives relaunch, and Expert Console pin/unpin flows are now real and tested.

Sprint 4 should use that truth to add the first honest marketplace surface:
- project the shared snapshot and recommendation outputs into read-only evidence cards
- turn the existing marketplace teaser into a navigable surface instead of placeholder copy
- keep marketplace claims strictly aligned with synthetic probes, freshness, and partial-data limits
- convert the open observability TODO into an in-repo research artifact so later product language stops depending on a floating assumption

## Problem Frame

The app now has a trustworthy Auto Mode and Expert Console loop, but the marketplace surface is still a static sprint-1 card. That leaves a gap between the approved information architecture and the real product: the design review explicitly made Marketplace a tertiary browse surface, but the repo does not yet contain a marketplace view, projection model, or tests proving that marketplace evidence matches Auto Mode proof.

The risk is not only missing UI. If marketplace evidence is assembled ad hoc in SwiftUI or drifts away from the same snapshot/policy outputs that power Auto Mode and Expert Console, RockeRoom will start telling different stories on different screens. That is a trust failure. The same is true of observability language: `TODOS.md` still holds an unresolved per-app observability question, so sprint 4 needs to turn that into a concrete research artifact and align product claims with the outcome.

## Requirements Trace

- R1. Add a real read-only Marketplace destination that is reachable from Auto Mode without changing the home-first navigation model.
- R2. Back marketplace cards with the same shared snapshot, proof payload, freshness, and partial-state truth used by Auto Mode and Expert Console.
- R3. Render honest empty, stale, and partial evidence states instead of fake rankings or optimistic placeholder copy.
- R4. Keep marketplace scope read-only and evidence-first: no seller flows, submissions, purchases, or second ranking engine.
- R5. Produce an in-repo observability spike document that records feasibility constraints, success criteria, and fallback language for synthetic-probe-only operation.
- R6. Update tests and supporting docs so marketplace evidence and observability claims can regress safely.

## Scope Boundaries

- No marketplace write flows, seller onboarding, payments, or user-published strategies
- No new scoring engine or marketplace-only ranking model
- No background refresh scheduler or hidden measurement loop
- No claim of true private per-app observability unless the spike proves it
- No major redesign of Auto Mode or Expert Console beyond the navigation and teaser changes needed to reach Marketplace

## Context & Research

### Relevant Code and Patterns

- `App/AutoMode/AutoModeView.swift` already contains the tertiary marketplace teaser and is the correct place to keep the entry lightweight.
- `App/AppRootView.swift` already owns navigation between Auto Mode, Why This, and Expert Console, so Marketplace should plug into the same destination routing rather than inventing modal navigation.
- `Shared/Engine/ResultSnapshot.swift`, `Shared/Domain/RecommendationState.swift`, and `Shared/Engine/RecommendationPolicy.swift` are the current trust spine. Marketplace projection should consume those outputs, not recreate them.
- `Shared/Engine/RefreshCoordinator.swift` now classifies evidence as current, stale-usable, or stale-hold. Marketplace cards should reuse those freshness semantics instead of inventing different badge rules.
- `App/AutoMode/WhyThisView.swift` already establishes the product invariant that the same shared snapshot powers Auto Mode, Expert Console, and marketplace evidence.
- `UITests/FirstRunOptimizeFlowTests.swift` is already the right integration seam for first-run marketplace reachability and evidence consistency, because it exercises import, optimize, relaunch, and current-state rendering.
- `project.yml` already has the right test-target split: pure projection logic belongs in `SharedKitTests`, while navigation/render assertions belong in `RockeRoomUITests`.

### Institutional Learnings

- There is still no `docs/solutions/` corpus, so the strongest local source of truth is the roadmap plus the now-implemented sprint-3 persistence and freshness seams.
- Earlier design and eng reviews fixed two important constraints that matter directly here: Marketplace is tertiary, and all trust surfaces must consume one shared snapshot/result story.

### External References

- Apple Network Extension platform constraints remain the right frame for the observability spike:
  - https://developer.apple.com/documentation/networkextension
- The current Clash-core constraint remains unchanged from earlier plans:
  - https://wiki.metacubex.one/en/config/proxy-providers/

## Key Technical Decisions

- **Add a projection layer before adding a marketplace screen:** Marketplace needs a shaped read model, but it must be derived from shared evidence rather than becoming a second source of truth.
- **Keep Marketplace navigation tertiary and explicit:** the teaser should open a dedicated browse surface; Marketplace should not become a peer home tab.
- **Treat freshness and partial-state badges as data, not view logic:** projection output should already say whether a card is current, stale, partial, or empty so SwiftUI stays simple and consistent.
- **Separate product evidence from research evidence:** marketplace cards are runtime product output; the observability spike is a durable research artifact in `docs/research/`, not UI copy hidden in code comments.
- **Prefer synthetic-probe-safe language by default:** unless the spike proves more, the sprint should assume marketplace evidence is based on synthetic probes and current tunnel/session state, not private app telemetry.

## Open Questions

### Resolved During Planning

- **Should Marketplace become a first-class top-level mode?** No. It remains a tertiary destination reached from the Auto Mode teaser.
- **Should Marketplace invent its own ranking model?** No. It projects shared snapshot and recommendation outputs only.
- **Should observability conclusions wait for a later sprint?** No. The unresolved TODO is already shaping product language, so sprint 4 should turn it into a concrete research artifact now.

### Deferred to Implementation

- **Exact evidence-card layout details:** the data contract is part of this plan, but final row/card composition can be refined while implementing SwiftUI.
- **Whether provider and strategy cards are separate sections or one mixed list:** the plan requires evidence-first cards and empty/stale handling, but the exact section grouping can be finalized during UI implementation.
- **Exact wording of fallback copy after the spike:** the sprint requires explicit fallback guidance, but the final user-facing copy can be tuned once the research artifact is written.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```text
shared snapshot + recommendation state + pin state
    -> EvidenceProjection.project(...)
        -> provider cards
        -> strategy cards
        -> freshness / partial / empty badges
        -> active-card marker
    -> Auto Mode teaser shows summary
    -> Marketplace screen shows full read-only card list

observability spike input
    -> iOS / NetworkExtension / Clash constraints
    -> current app architecture assumptions
    -> feasible signals vs infeasible claims
    -> fallback language + roadmap guardrails
```

## Implementation Units

- [ ] **Unit 1: Add shared marketplace evidence projection**

**Goal:** Create a shared read model that turns snapshot and recommendation outputs into marketplace-ready evidence cards without introducing a second ranking source.

**Requirements:** R2, R3, R4

**Dependencies:** Sprint 3 snapshot persistence and refresh coordination

**Files:**
- Create: `Shared/Engine/EvidenceProjection.swift`
- Modify: `Shared/Engine/ResultSnapshot.swift`
- Modify: `Shared/Domain/RecommendationState.swift`
- Test: `Tests/MarketplaceEvidenceProjectionTests.swift`

**Approach:**
- Introduce a projection type that accepts the current snapshot, recommendation state, and pin state and returns a small set of read-only marketplace sections/cards.
- Include enough structured fields for UI to render cards honestly without re-deriving trust state: title, summary proof, active/recommended markers, freshness state, partial/degraded labels, and empty-state copy.
- Keep the projection shape tolerant of missing snapshot data so the marketplace can render an honest empty surface before the first optimize run.
- Reuse existing proof payload and candidate ordering semantics where possible instead of recomputing “best” inside the projection layer.

**Patterns to follow:**
- Mirror the way `RecommendationPolicy` centralizes decision logic: projection should shape outputs, not decide recommendation policy.
- Reuse the current snapshot-first model already consumed by Auto Mode and Expert Console.

**Test scenarios:**
- Happy path: a current snapshot with a recommended candidate produces provider evidence cards with the active recommendation marked and proof values matching the selected candidate.
- Happy path: a pinned recommendation produces a projected active card that reflects the pinned candidate rather than the best unpinned score.
- Edge case: no snapshot returns a deterministic empty-state projection instead of fake provider rankings.
- Edge case: stale or partial snapshots project stale and partial badges while keeping the last known proof visible.
- Error path: malformed or incomplete recommendation/snapshot combinations degrade into safe empty or degraded cards without throwing or crashing.
- Integration: projection output for the active recommendation matches the same proof/freshness values shown in Auto Mode `Why this?`.

**Verification:**
- Shared projection tests prove that marketplace read models are derived from the same trust outputs as the rest of the app.

- [ ] **Unit 2: Turn the teaser into a real Marketplace surface**

**Goal:** Add a dedicated read-only Marketplace screen and wire the existing teaser into the current home-first navigation structure.

**Requirements:** R1, R2, R3, R4

**Dependencies:** Unit 1

**Files:**
- Modify: `App/AutoMode/AutoModeView.swift`
- Modify: `App/Marketplace/MarketplaceTeaserView.swift`
- Create: `App/Marketplace/MarketplaceView.swift`
- Modify: `App/AppRootView.swift`
- Modify: `App/ExpertConsole/ExpertConsoleViewModel.swift`
- Test: `UITests/FirstRunOptimizeFlowTests.swift`

**Approach:**
- Replace the static teaser copy with a compact summary that reflects marketplace readiness: empty before optimize, evidence summary after optimize, and stale/partial hints when appropriate.
- Add a new `Marketplace` destination in `AppRootView` using the existing `NavigationStack` flow.
- Keep Marketplace read-only: the screen should browse evidence cards and explain what the app currently knows, but it should not allow edits, pinning, or subscription changes.
- Feed the screen from the shared projection layer, not from bespoke view-owned transformations.

**Execution note:** Start with navigation and empty-state UI assertions so the marketplace screen shape is fixed before refining evidence card details.

**Patterns to follow:**
- Follow the existing destination wiring style used for `whyThis` and `expertConsole`.
- Keep home-first hierarchy intact by making the teaser the only entry point rather than adding a new tab or global toolbar mode.

**Test scenarios:**
- Happy path: after import and optimize, tapping the marketplace teaser opens a Marketplace screen with evidence cards derived from the current snapshot.
- Happy path: relaunch with persisted snapshot still lets Marketplace render the same read-only evidence without rerunning optimize first.
- Edge case: before any optimize run, Marketplace opens to an honest empty state explaining that no evidence is available yet.
- Edge case: stale evidence renders a visible stale hint on the teaser and corresponding stale badges on marketplace cards.
- Error path: if projection returns degraded/empty content, Marketplace still opens and renders recoverable fallback messaging instead of a blank or crashed screen.
- Integration: the active marketplace card matches Auto Mode’s current setup and Expert Console’s current candidate labeling.

**Verification:**
- The app has a working Marketplace destination that remains tertiary, read-only, and consistent with Auto Mode truth.

- [ ] **Unit 3: Land the observability spike as a repo artifact**

**Goal:** Replace the floating TODO with a concrete research document that records what iOS + Clash can and cannot honestly support.

**Requirements:** R5, R6

**Dependencies:** None for research collection; Unit 1 is helpful for aligning fallback language

**Files:**
- Create: `docs/research/2026-04-04-ios-observability-spike.md`
- Modify: `TODOS.md`
- Modify: `docs/plans/2026-04-04-003-feat-ios-next-sprints-roadmap-plan.md`

**Approach:**
- Write the observability spike as a real engineering decision memo, not a placeholder note.
- Capture the current architectural question precisely: which signals are available from Network Extension, Clash runtime state, and synthetic probes, and which “per-app” claims are unsupported.
- Record success criteria, kill criteria, App Store/TestFlight compatibility implications, and the fallback product language if only synthetic probes are feasible.
- Update `TODOS.md` so it references the new research artifact rather than remaining the sole source of truth.

**Patterns to follow:**
- Follow the repo’s existing markdown plan style: explicit problem framing, constraints, and downstream implications.
- Keep claims bounded by currently known architecture and platform surfaces rather than aspirational language.

**Test scenarios:**
- Test expectation: none -- this unit is a research/documentation artifact, but it must include explicit feasibility conclusions, constraints, and fallback guidance.

**Verification:**
- The repo contains a durable observability decision document, and `TODOS.md` no longer leaves this question as an unstructured future reminder.

- [ ] **Unit 4: Add regression coverage and copy-alignment safeguards**

**Goal:** Make marketplace evidence and observability language safe to evolve without splitting product truth across surfaces.

**Requirements:** R2, R3, R5, R6

**Dependencies:** Units 1-3

**Files:**
- Modify: `UITests/FirstRunOptimizeFlowTests.swift`
- Modify: `Tests/AppSessionRestoreTests.swift`
- Modify: `Tests/FreshnessRegressionTests.swift`
- Create: `README.md`

**Approach:**
- Extend UI coverage to prove marketplace reachability and evidence consistency from the same import -> optimize -> restore loop already under test.
- Add targeted regression coverage where stale restore and marketplace cards could drift apart.
- Add a small top-level `README.md` section that explains the current evidence model in plain English: Auto Mode, Expert Console, and Marketplace all consume one shared snapshot, and deeper per-app observability remains constrained by the spike result.
- Keep this documentation lightweight and alpha-oriented rather than turning it into launch marketing copy.

**Patterns to follow:**
- Build on the existing first-run and restore tests rather than creating a second parallel UI harness for Marketplace.
- Keep docs aligned with the same trust language already visible in `WhyThisView` and the design/eng review artifacts.

**Test scenarios:**
- Happy path: import -> optimize -> open Marketplace shows evidence consistent with the recommended setup and proof rows already visible in Auto Mode.
- Happy path: relaunch with stored snapshot still renders Marketplace cards without silently changing the active recommendation.
- Edge case: stale restore shows matching stale messaging in Auto Mode and Marketplace after foreground re-entry.
- Error path: empty or degraded projection on launch still renders honest Marketplace fallback content and leaves the app navigable.
- Integration: README and research docs describe the same synthetic-probe constraints reflected by marketplace fallback states.

**Verification:**
- Marketplace and observability language are covered by regression tests and a minimal developer-facing explanation, reducing future drift.

## System-Wide Impact

- **Interaction graph:** Auto Mode remains the home surface, `AppRootView` owns navigation, Marketplace becomes a read-only consumer of shared evidence projection, and the observability spike feeds documentation and future planning rather than runtime behavior.
- **Error propagation:** missing, stale, or partial snapshot data must propagate into explicit projection states and UI copy instead of disappearing behind placeholder cards.
- **State lifecycle risks:** persisted snapshots can age between sessions; marketplace cards must respect the same restore/freshness evaluation as Auto Mode to avoid contradictory evidence.
- **API surface parity:** Auto Mode, Expert Console, `WhyThisView`, and Marketplace should continue describing the same active recommendation and freshness semantics.
- **Integration coverage:** first-run import/optimize, relaunch restore, stale foreground re-entry, and empty-snapshot navigation all need cross-layer proof beyond pure unit tests.
- **Unchanged invariants:** home-first navigation, centralized recommendation policy, binary import validation, shared snapshot truth, and pin-means-no-auto-switch all remain fixed.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Marketplace UI drifts into a second recommendation surface | Keep evidence shaping in `Shared/Engine/EvidenceProjection.swift` and keep Marketplace read-only |
| Projection model bakes UI-specific layout assumptions into Shared | Limit the shared contract to semantic card/section data and leave visual composition to SwiftUI |
| Observability spike remains vague and non-actionable | Require explicit feasible signals, infeasible claims, fallback language, and downstream product implications |
| Marketplace scope grows into commerce or editing work | Keep navigation tertiary and reject any write action in this sprint |

## Documentation / Operational Notes

- `docs/research/2026-04-04-ios-observability-spike.md` should become the canonical answer for future sprint planning around app-awareness claims.
- `README.md` should explain the current alpha trust model and point contributors at the design and roadmap docs, not try to sell the product publicly.

## Sources & References

- Related plan: `docs/plans/2026-04-04-003-feat-ios-next-sprints-roadmap-plan.md`
- Related plan: `docs/plans/2026-04-04-006-feat-ios-sprint-3-trustworthy-automation-plan.md`
- Related checklist: `docs/plans/2026-04-04-007-feat-ios-sprint-3-trustworthy-automation-checklist.md`
- Related code: `App/AutoMode/AutoModeView.swift`
- Related code: `App/AppRootView.swift`
- Related code: `Shared/Engine/RefreshCoordinator.swift`
- Related code: `App/AutoMode/WhyThisView.swift`
- External docs: https://developer.apple.com/documentation/networkextension
- External docs: https://wiki.metacubex.one/en/config/proxy-providers/
