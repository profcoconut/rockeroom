# iOS Observability Spike

Date: 2026-04-04

## Question

What can RockeRoom actually observe on iOS when Clash is the execution core, and which product claims are too strong for the platform and extension model?

## Conclusion

For the current alpha architecture, RockeRoom should treat deeper private per-app telemetry as unproven and avoid product language that assumes it exists.

The reliable, supportable signals are the ones already present in the app:
- Clash subscription import and restore state
- tunnel/session status from the extension boundary
- synthetic probe results
- snapshot freshness, partial-state flags, and recommendation policy output

Those signals are enough to support a truthful alpha loop, but not enough to justify claims like "private per-app visibility" or "app-aware ranking based on direct per-app traffic inspection" unless a future platform-specific entitlement or extension path is separately proven.

## Feasible Signals

- Subscription link import success or failure
- Tunnel start, stop, and restore state
- Probe-based ranking and proof payloads
- Snapshot freshness decay and stale-state handling
- Manual pin and auto-switch policy behavior

## Unsupported Claims

- Per-app private telemetry as a default assumption
- Direct observation of arbitrary third-party app traffic for ranking purposes
- Any marketplace or copy language that implies direct app-level inspection when only synthetic probes are available

## Fallback Language

If the spike remains negative, RockeRoom should describe scoring as:
- based on synthetic probes and current tunnel state
- honest about freshness, partial data, and stale evidence
- limited by platform and extension constraints rather than pretending to inspect private per-app traffic

## Implications

- Marketplace evidence should stay projection-based and read-only.
- Auto Mode and Expert Console should continue to share one snapshot and one policy layer.
- `TODOS.md` should stop describing this as an open-ended implementation mystery and instead point at this memo as the current answer.
- Future roadmap work should treat deeper per-app observability as a gated research topic, not a hidden assumption.

## Success Criteria

- The repo contains a durable written answer for what is and is not observable.
- Product copy can be kept honest without qualifying every screen with speculative language.
- Later sprint planning has a concrete fallback if synthetic probes remain the ceiling.

## Sources

- `TODOS.md`
- `docs/plans/2026-04-04-003-feat-ios-next-sprints-roadmap-plan.md`
- `docs/plans/2026-04-04-008-feat-ios-sprint-4-evidence-surfaces-plan.md`
- `App/AutoMode/WhyThisView.swift`
