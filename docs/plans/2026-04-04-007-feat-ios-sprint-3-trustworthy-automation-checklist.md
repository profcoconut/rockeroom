# RockeRoom Sprint 3 Checklist

Source plan: `docs/plans/2026-04-04-006-feat-ios-sprint-3-trustworthy-automation-plan.md`

## Goal

Turn sprint-2 runtime truth into trustworthy automation:
- persist the latest measured snapshot and manual pin intent
- restore snapshot and pin state on relaunch
- coordinate stale/current refresh behavior honestly
- make Expert Console a real inspect and pin/unpin surface
- replace skipped pin and console UI tests with real regression coverage

## Tracking Checklist

- [ ] Persist the latest `ResultSnapshot` instead of keeping it in-memory only
- [ ] Add durable pin-state storage for manual override intent
- [ ] Restore snapshot and pin state during app launch
- [ ] Keep restored snapshot truth distinct from newly refreshed evidence
- [ ] Add a refresh coordinator for current, stale-usable, and stale-hold states
- [ ] Map foreground re-entry and explicit optimize onto the new refresh coordination path
- [ ] Preserve the last usable snapshot during refresh failure instead of blanking evidence
- [ ] Update Auto Mode stale, partial, and degraded-state messaging to match restored truth
- [ ] Expand Expert Console to show ranked candidates and hold reasons
- [ ] Wire pin and unpin actions from Expert Console back to `AutoModeViewModel`
- [ ] Keep Auto Mode and Expert Console aligned on the same recommendation and pin state
- [ ] Persist pin state across relaunch until the user explicitly unpins
- [ ] Replace the skipped Expert Console navigation UI test
- [ ] Replace the skipped pin/no-auto-switch UI test

## Required Tests

- [ ] Unit tests for snapshot persistence save, load, clear, and corrupted-state fallback
- [ ] Unit tests for pin-state persistence and restore behavior
- [ ] Unit tests for restored snapshot plus pin state re-evaluating into a pinned hold
- [ ] Freshness regression tests for restored current vs stale snapshot behavior
- [ ] Unit tests for refresh coordination state mapping and refresh eligibility
- [ ] App-hosted tests for launch restore with current snapshot, stale snapshot, and no snapshot
- [ ] Unit tests for Expert Console pin and unpin state propagation through `RecommendationPolicy`
- [ ] UI flow: Auto Mode -> Expert Console navigation with shared snapshot evidence visible
- [ ] UI flow: pin from Expert Console -> Auto Mode shows pinned hold summary
- [ ] UI flow: relaunch restores pinned state and stale/current evidence truth
- [ ] UI flow: unpin resumes policy-controlled recommendation behavior without a false auto-switch state

## Explicit Non-Goals

- [ ] No marketplace expansion beyond the existing teaser
- [ ] No observability-spike implementation work
- [ ] No background scheduling or silent background optimize loop
- [ ] No new tunnel runtime primitives beyond consuming sprint-2 restored session truth
- [ ] No major visual redesign outside the Auto Mode and Expert Console surfaces

## Open Follow-Up

- [ ] Feed any snapshot-shape or pin-state contract changes back into `docs/plans/2026-04-04-003-feat-ios-next-sprints-roadmap-plan.md` if they change sprint-4 marketplace assumptions
- [ ] Capture any new app lifecycle or refresh assumptions in repo docs if implementation introduces non-obvious restore behavior
