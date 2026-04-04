# RockeRoom Sprint 1 Checklist

Source plan: `docs/plans/2026-04-04-001-feat-ios-alpha-foundation-plan.md`

## Goal

Ship the first iOS alpha foundation for RockeRoom:
- accept a Clash subscription link
- fetch and validate provider data
- run probes
- score and recommend the best setup
- show trust-first Auto Mode UI
- expose an Expert Console shell

## Tracking Checklist

- [ ] Create the iOS app target, packet-tunnel extension target, shared module layout, unit-test target, and UI-test target
- [ ] Define the canonical internal provider model and import result states
- [ ] Build Clash subscription link import flow
- [ ] Fetch subscription content and reject invalid or unsupported responses deterministically
- [ ] Normalize accepted subscription data into the canonical internal model
- [ ] Add Clash adapter boundary and packet-tunnel startup path
- [ ] Add probe runner with bounded concurrency and early-stop behavior
- [ ] Add shared result snapshot store with freshness metadata
- [ ] Add centralized recommendation policy
- [ ] Add confidence, freshness, and stale-data handling
- [ ] Enforce pin means no auto-switch
- [ ] Build Auto Mode home screen
- [ ] Show 2-3 inline proof deltas plus "Why this?" drilldown
- [ ] Build Expert Console shell from the shared snapshot
- [ ] Add marketplace teaser as read-only evidence surface

## Required Tests

- [ ] Unit tests for Clash subscription import accept/reject behavior
- [ ] Unit tests for canonical model normalization
- [ ] Unit tests for probe runner partial-failure behavior
- [ ] Unit tests for recommendation policy, including insignificant delta and low-confidence hold behavior
- [ ] Dedicated freshness regression suite
- [ ] Unit tests for pinning policy
- [ ] UI tests for Auto Mode honesty states
- [ ] UI tests for Expert Console uncertainty states
- [ ] E2E flow: valid subscription link -> optimize -> recommendation -> proof
- [ ] E2E flow: invalid subscription link -> recovery path
- [ ] E2E flow: manual pin -> better option found -> no auto-switch

## Explicit Non-Goals

- [ ] No seller onboarding
- [ ] No payments or strategy publishing
- [ ] No cross-platform clients
- [ ] No deep private per-app telemetry beyond what the observability spike proves feasible

## Open Follow-Up

- [ ] Run the observability spike from `TODOS.md` before depending on deeper app-level measurement claims
