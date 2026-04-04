# TODOS

## Investigate deeper iOS per-app observability

What:
Run a formal feasibility spike for deeper iOS per-app observability beyond synthetic probes.

Why:
RockeRoom's product promise leans on app-experience-aware ranking, but Apple platform limits and Clash client/platform limits suggest true per-app visibility may be constrained or unavailable.

Pros:
- Prevents the implementation plan from quietly depending on a capability that may not exist
- Forces explicit success criteria and kill criteria before architecture hardens around the wrong assumption
- Clarifies fallback behavior if observability stays limited to synthetic probes

Cons:
- Adds up-front investigation work
- May end with "not feasible" and require product-language changes

Context:
See `docs/research/2026-04-04-ios-observability-spike.md` for the current answer.
Current answer: do not assume private per-app telemetry; keep product claims synthetic-probe-safe unless a future platform path is proven.

Start from `NetworkExtension` constraints, Clash Apple client/platform limits, and the current decision to use Clash as the execution core. Determine what data can actually be observed on iOS, what entitlements or extension types are required, and whether any deeper measurement is App Store / TestFlight compatible. If not, define the exact synthetic-probe fallback and how the product should describe its scoring honestly.

Depends on / blocked by:
Depends on the iOS architecture spike. Blocks any implementation that assumes true per-app private telemetry exists.
