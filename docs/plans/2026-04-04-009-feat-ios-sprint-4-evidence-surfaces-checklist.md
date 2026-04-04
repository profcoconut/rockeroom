# RockeRoom Sprint 4 Checklist

Source plan: `docs/plans/2026-04-04-008-feat-ios-sprint-4-evidence-surfaces-plan.md`

## Goal

Turn the static marketplace placeholder into an honest read-only evidence surface:
- project shared snapshot and recommendation truth into marketplace-ready cards
- add a real Marketplace destination without breaking the home-first navigation model
- keep marketplace empty, stale, and partial states honest
- land the iOS observability spike as an in-repo research artifact
- add regression coverage and lightweight docs so marketplace claims do not drift from Auto Mode truth

## Tracking Checklist

- [x] Create a shared `EvidenceProjection` layer for marketplace cards
- [x] Derive marketplace cards from snapshot, recommendation state, and pin state instead of a second ranking source
- [x] Include active, recommended, freshness, partial, and empty-state semantics in the projection output
- [x] Keep projection tolerant of missing or degraded snapshot/recommendation combinations
- [x] Replace the static Auto Mode marketplace teaser with a state-aware summary
- [x] Add a real Marketplace destination to `AppRootView`
- [x] Keep Marketplace tertiary and reachable only from the Auto Mode teaser
- [x] Create a read-only `MarketplaceView`
- [x] Render honest empty-state marketplace content before the first optimize run
- [x] Render stale and partial evidence badges when snapshot truth is stale or incomplete
- [x] Keep Marketplace aligned with the same active recommendation shown in Auto Mode and Expert Console
- [x] Write the iOS observability spike to `docs/research/2026-04-04-ios-observability-spike.md`
- [x] Record feasible signals, infeasible claims, and synthetic-probe fallback guidance in the spike doc
- [x] Update `TODOS.md` to point at the observability research artifact instead of leaving the question free-floating
- [x] Feed any resulting observability constraint changes back into the roadmap plan
- [x] Add a lightweight `README.md` section explaining the shared-evidence model for the alpha

## Required Tests

- [x] Unit tests for marketplace evidence projection with a current recommended snapshot
- [x] Unit tests for marketplace projection when a pinned candidate is active
- [x] Unit tests for empty-state projection when no snapshot exists
- [x] Unit tests for stale and partial snapshot projection badges
- [x] Unit tests for malformed or incomplete projection inputs degrading safely
- [x] UI flow: import -> optimize -> open Marketplace shows evidence cards
- [x] UI flow: Marketplace empty state is reachable before any optimize run
- [x] UI flow: relaunch with stored snapshot still renders Marketplace evidence
- [x] UI flow: stale restore shows matching stale messaging in Auto Mode and Marketplace
- [x] Integration coverage proving Marketplace, Auto Mode, and Expert Console agree on the active recommendation

## Explicit Non-Goals

- [x] No marketplace write flows, seller onboarding, payments, or user submissions
- [x] No marketplace-only scoring or recommendation engine
- [x] No new background refresh scheduler or hidden measurement loop
- [x] No claim of private per-app observability unless the spike proves it
- [x] No major redesign of Auto Mode or Expert Console beyond the marketplace entry and browse surface

## Open Follow-Up

- [x] Update `docs/plans/2026-04-04-003-feat-ios-next-sprints-roadmap-plan.md` if marketplace contracts or observability conclusions change sprint-5 assumptions
- [x] Capture any new contributor-facing architecture notes in `README.md` if the shared evidence model or observability constraints are easy to misunderstand
