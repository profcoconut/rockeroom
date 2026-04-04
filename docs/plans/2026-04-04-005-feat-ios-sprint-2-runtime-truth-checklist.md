# RockeRoom Sprint 2 Checklist

Source plan: `docs/plans/2026-04-04-004-feat-ios-sprint-2-runtime-truth-plan.md`

## Goal

Turn the alpha foundation into a truthful runtime loop for iOS:
- persist the accepted Clash subscription link and normalized config
- replace the in-memory tunnel stub with a real session lifecycle boundary
- restore subscription and tunnel state on app relaunch
- prove the first real import -> optimize -> restore trust path end to end

## Tracking Checklist

- [ ] Add durable stored-subscription model and repository
- [ ] Persist the original Clash subscription link plus accepted normalized `SubscriptionConfig`
- [ ] Keep failed re-imports from overwriting the last valid stored subscription
- [ ] Update Auto Mode import flow to load and surface persisted subscription state
- [ ] Add tunnel-session model and store
- [ ] Replace the default in-memory `ClashAdapter` path with a real tunnel control/status seam
- [ ] Configure the packet-tunnel startup path around serialized `SubscriptionConfig`
- [ ] Persist tunnel requested/runtime state for restore and honest UI messaging
- [ ] Restore stored subscription and tunnel session truth during app launch
- [ ] Update Auto Mode states for ready, starting, running, and failed tunnel lifecycle cases
- [ ] Keep Expert Console aligned with restored runtime truth without expanding its scope
- [ ] Replace the skipped first-run optimize placeholder with a real runtime-truth flow

## Required Tests

- [ ] Unit tests for subscription repository save/load behavior
- [ ] Unit tests for failed import preserving the last accepted subscription
- [ ] Unit tests for tunnel session store persistence and restore behavior
- [ ] Unit tests for `ClashAdapter` start/stop/status transitions
- [ ] Unit tests for deterministic provider missing-configuration failure
- [ ] Integration tests for app launch restoring stored subscription state
- [ ] Integration tests for adapter status matching restored tunnel-session metadata
- [ ] UI flow: valid subscription link -> optimize -> recommendation-ready Auto Mode state
- [ ] UI flow: relaunch restores subscription and runtime state without re-entry
- [ ] UI flow: malformed or unreachable subscription retry preserves prior valid state
- [ ] UI flow: tunnel-start failure shows degraded but recoverable state

## Explicit Non-Goals

- [ ] No snapshot persistence beyond the current optimize session
- [ ] No refresh coordinator or background refresh policy
- [ ] No marketplace expansion
- [ ] No Expert Console feature expansion beyond restored-state alignment
- [ ] No deeper observability claims than synthetic probes support today

## Open Follow-Up

- [ ] Feed sprint-2 persistence and runtime decisions back into `docs/plans/2026-04-04-003-feat-ios-next-sprints-roadmap-plan.md` if they change sprint-3 assumptions
- [ ] Capture any required tunnel-manager setup or entitlement notes in repo docs during implementation
