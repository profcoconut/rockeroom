# RockeRoom Sprint 5 Checklist

Source plan: `docs/plans/2026-04-04-010-feat-ios-sprint-5-alpha-hardening-plan.md`

## Goal

Turn the current feature-complete alpha into a stable release candidate:
- make the integrated `RockeRoom` scheme test run reliable enough to be the alpha gate
- deepen degraded, stale, retry, and recovery regression coverage
- keep Auto Mode, Expert Console, and Marketplace aligned under failure and relaunch conditions
- add the minimal TestFlight release checklist and validation docs

## Tracking Checklist

- [x] Characterize the current combined `xcodebuild ... test` bootstrap/harness failure
- [x] Tighten test isolation so full-suite runs do not depend on leftover simulator or app state
- [x] Keep the integrated `RockeRoom` scheme as the real alpha validation gate
- [x] Deepen `FirstRunOptimizeFlowTests` for degraded, retry, and stale/relaunch scenarios
- [x] Deepen `ManualPinFlowTests` for unpin and post-failure recovery behavior
- [x] Add or extend shared/app-hosted tests for tunnel-start failure and repeated failure/recovery behavior
- [x] Verify stale restore and explicit refresh keep Auto Mode and Marketplace aligned
- [x] Verify pinned and unpinned flows keep Auto Mode and Expert Console aligned
- [x] Tighten failure and degraded-state copy only where the current UI feels ambiguous or accidental
- [x] Keep badge and state vocabulary consistent across Auto Mode, Expert Console, and Marketplace
- [x] Create `docs/release/alpha-testflight-checklist.md`
- [x] Update `README.md` to point contributors to the release checklist and final alpha validation path
- [x] Feed any sprint-5 validation or release assumptions back into the roadmap doc if needed

## Required Tests

- [x] Integrated scheme run: `RockeRoom` test suite completes reliably
- [x] UI flow: stale restore -> explicit optimize refreshes current evidence cleanly
- [x] UI flow: pin -> unpin resumes policy-controlled recommendation behavior
- [x] UI flow: tunnel-start failure remains recoverable and preserves stored subscription truth
- [x] Unit/app-hosted tests for repeated tunnel-start failure not corrupting persisted session state
- [x] Unit/app-hosted tests for stale/degraded evidence staying aligned across recommendation and marketplace projection
- [x] Integration coverage proving Auto Mode, Expert Console, and Marketplace still agree on the active setup after recovery paths

## Explicit Non-Goals

- [ ] No new end-user product features
- [ ] No new marketplace write flows, payments, or seller concepts
- [ ] No deeper per-app telemetry claims beyond the observability memo
- [ ] No major UI redesign outside targeted failure/recovery polish
- [ ] No replacement of the Clash execution core or shared policy architecture

## Open Follow-Up

- [x] Update `docs/plans/2026-04-04-003-feat-ios-next-sprints-roadmap-plan.md` if sprint-5 hardening changes the final alpha exit criteria
- [x] Capture any non-obvious simulator/test-gate assumptions in repo docs if the combined-suite fix depends on them

## Current Gate Note

- The product-facing regressions are green under the serialized gate command.
- The integrated scheme gate completed successfully under the serialized command.
- Current alpha gate command: `xcodebuild -project RockeRoom.xcodeproj -scheme RockeRoom -destination 'platform=iOS Simulator,name=iPhone 17' test -parallel-testing-enabled NO`
