---
title: feat: Detail iOS sprint 2 runtime truth
type: feat
status: active
date: 2026-04-04
---

# feat: Detail iOS sprint 2 runtime truth

## Overview

This plan deepens sprint 2 from `docs/plans/2026-04-04-003-feat-ios-next-sprints-roadmap-plan.md` into an implementation-ready document. Sprint 2 is the point where RockeRoom stops behaving like a convincing demo and starts behaving like a real Clash-backed iOS product: imported subscriptions persist, the app can restore prior state, and the packet-tunnel boundary becomes a real session lifecycle instead of an in-memory stub.

The sprint should end with one truthful first-run loop:
- import a Clash subscription link
- persist the accepted subscription and current tunnel session metadata
- configure and start the packet-tunnel path through the real app-to-extension boundary
- restore import and tunnel state on relaunch
- keep Auto Mode honest when import or tunnel startup fails

## Problem Frame

Sprint 1 established the architecture and UI shell, but the runtime truth is still missing. `App/AutoMode/AutoModeViewModel.swift` still constructs `ClashSubscriptionImporter` with `LocalDevelopmentSubscriptionFetcher` and `ProbeRunner` with `DemoProbeExecutor`. `Shared/Engine/ClashAdapter.swift` still defaults to `InMemoryClashEngine`, and `Extension/PacketTunnelProvider.swift` only proves that a serialized `SubscriptionConfig` can be decoded, not that the app owns a durable tunnel session lifecycle.

That leaves three trust gaps:
- accepted subscriptions are not durable enough to survive real app lifecycle behavior
- tunnel state is not managed through a persisted `NETunnelProviderManager`-style boundary
- the first-run optimize flow still cannot prove that import, start, restore, and recovery work together

Sprint 2 should close those gaps without pulling in later-sprint scope like snapshot persistence, marketplace evidence, or richer Expert Console behavior.

## Requirements Trace

- R1. Persist accepted Clash subscription link metadata and normalized `SubscriptionConfig` so the app can restore it after relaunch.
- R2. Keep strict binary import validation: accepted subscriptions become durable state, rejected subscriptions do not mutate the active session.
- R3. Introduce a real app-owned tunnel session lifecycle that can configure, start, stop, and inspect the packet-tunnel boundary through shared models.
- R4. Replace the in-memory-only `ClashAdapter` default path with a runtime seam that can represent extension-managed startup and status.
- R5. Restore imported subscription and tunnel session state on app launch without forcing the user to re-enter the subscription link.
- R6. Keep Auto Mode honest on tunnel-start failure, unreachable subscription links, and invalid subscription payloads.
- R7. Unskip the first meaningful first-run UI flow so sprint 2 proves import -> optimize -> restore behavior end to end.
- R8. Preserve sprint-1 invariants: home-first Auto Mode, centralized recommendation policy, shared models, and no partial-import ambiguity.

## Scope Boundaries

- No snapshot persistence beyond the current optimize session
- No refresh coordinator or background refresh policy
- No Expert Console completion beyond consuming restored state where already wired
- No marketplace expansion
- No deeper observability claims than synthetic probes can support today
- No custom tunnel engine replacing Clash or the packet-tunnel extension shape

## Context & Research

### Relevant Code and Patterns

- `App/AutoMode/AutoModeViewModel.swift` is the main orchestration seam. It currently owns import state, optimize state, and pin state, which makes it the right place to integrate restored subscription and session truth before later sprints split refresh concerns further.
- `App/AppRootView.swift` already coordinates Auto Mode and Expert Console entry, so launch-time restore behavior should be introduced here or in an adjacent app-scoped composition layer rather than buried in view code.
- `Shared/Engine/ClashSubscriptionImporter.swift` already enforces the accepted/rejected trust boundary and should remain the only parser/normalizer for subscription payloads.
- `Shared/Domain/SubscriptionConfig.swift` is already `Codable`, which matches the existing extension handoff contract in `Extension/PacketTunnelProvider.swift`.
- `Shared/Engine/ClashAdapter.swift` already defines the right protocol seam (`ClashControlling`, `ClashEngine`) but its default engine is still purely in-memory.
- `UITests/FirstRunOptimizeFlowTests.swift` already contains the deliberately skipped first-run automation placeholder and should be completed rather than replaced.

### Institutional Learnings

- There is still no `docs/solutions/` knowledge base, so the best local source of truth is the sprint-1 code plus the approved roadmap and review artifacts.
- Prior review decisions remain fixed for this sprint: binary import acceptance, centralized policy, shared result model, and no silent auto-switch while pinned.

### External References

- Apple `NEPacketTunnelProvider.startTunnel(options:completionHandler:)` lifecycle:
  - https://developer.apple.com/documentation/networkextension/nepackettunnelprovider/starttunnel%28options%3Acompletionhandler%3A%29
- Apple `NETunnelProviderManager` persistence/configuration surface:
  - https://developer.apple.com/documentation/networkextension/netunnelprovidermanager
- Clash-compatible provider config references already used by the importer:
  - https://wiki.metacubex.one/en/config/proxy-providers/
  - https://wiki.metacubex.one/en/config/rule-providers/content/

## Key Technical Decisions

- **Persist both the source link and the accepted normalized config:** the user-facing recovery path needs the original link, while runtime startup and restore should depend on the validated config rather than reparsing on every launch.
- **Keep the extension contract serialized around `SubscriptionConfig`:** the app and extension should continue sharing one normalized config type, not drift into parallel DTOs.
- **Represent tunnel lifecycle as app-owned session state plus adapter-owned runtime control:** persistence belongs in a repository/store layer, while start/stop/status belong behind `ClashAdapter`.
- **Restore state before the user interacts with Auto Mode:** the home screen should open already knowing whether a subscription exists and whether a prior tunnel session is restorable.
- **Treat failed imports and failed tunnel starts differently:** invalid subscription input should not mutate active state, while tunnel-start failure should preserve the last valid config but surface degraded runtime state.

## Open Questions

### Resolved During Planning

- **Sprint shape:** sprint 2 stays focused on runtime truth, not snapshot persistence or Expert Console completion.
- **Persistence boundary:** subscription persistence and tunnel session persistence should be separate concerns so a valid subscription can survive a failed runtime start.
- **Restore behavior:** app launch should restore the last accepted subscription/config eagerly, but runtime start remains explicit through user optimize action unless an existing running session is already active.
- **Failure behavior:** unreachable subscription links during re-import must not overwrite the last accepted config.

### Deferred to Implementation

- **Concrete storage mechanism:** whether the repositories use `UserDefaults`, file-backed JSON, app group storage, or another Apple-friendly persistence layer can be finalized while wiring app/extension access.
- **Exact `NETunnelProviderManager` wrapper shape:** the plan requires a wrapper around the manager lifecycle, but the final helper names and file split can be decided during implementation.
- **How much session metadata is persisted beyond config identity and state:** the plan needs enough metadata to restore honest UI state, but fine-grained telemetry belongs to later sprints.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```text
SubscriptionImportView
  -> AutoModeViewModel.importSubscriptionLink(link)
      -> ClashSubscriptionImporter
          -> accepted SubscriptionConfig
              -> SubscriptionRepository.save(link, config)
              -> Auto Mode becomes ready
          -> rejected failure
              -> active persisted config unchanged
              -> UI shows recoverable rejection

AutoModeViewModel.optimize()
  -> SubscriptionRepository.currentConfig()
  -> TunnelSessionStore.prepare(config)
  -> ClashAdapter.start(config)
      -> app-side tunnel manager configures provider
      -> PacketTunnelProvider decodes same SubscriptionConfig
  -> adapter.status()
  -> ProbeRunner.run(...)
  -> in-memory snapshot + recommendation update

App launch
  -> restore SubscriptionRepository current config
  -> restore TunnelSessionStore current session metadata
  -> query ClashAdapter.status()
  -> seed Auto Mode UI with truthful ready/running/degraded state
```

## Implementation Units

- [ ] **Unit 1: Persist accepted Clash subscription state**

**Goal:** Create the durable subscription state layer so accepted links/configs survive relaunch and rejected imports do not corrupt active state.

**Requirements:** R1, R2, R5, R6, R8

**Dependencies:** Existing sprint-1 importer and shared domain model

**Files:**
- Create: `Shared/Engine/SubscriptionRepository.swift`
- Create: `Shared/Domain/StoredSubscription.swift`
- Modify: `Shared/Engine/ClashSubscriptionImporter.swift`
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Modify: `App/Import/SubscriptionImportView.swift`
- Test: `Tests/ClashSubscriptionImporterTests.swift`
- Test: `Tests/SubscriptionRepositoryTests.swift`

**Approach:**
- Add a repository that stores the original Clash subscription link plus the last accepted normalized `SubscriptionConfig`.
- Keep the importer responsible only for validation and normalization; persistence happens after `.accepted` is returned.
- Ensure failed re-imports leave the last accepted stored subscription untouched so the active product state does not regress on transient network or malformed-input retries.
- Update Auto Mode import handling to load and surface persisted state rather than treating every app launch as a blank first run.

**Execution note:** Start with characterization-style tests around “failed import does not replace existing accepted config” before changing `AutoModeViewModel` import flow.

**Patterns to follow:**
- Reuse `SubscriptionConfig` as the only accepted normalized runtime model.
- Mirror the explicit accepted/rejected result handling already present in `ClashSubscriptionImporter`.

**Test scenarios:**
- Happy path: valid Clash subscription link imports successfully and persists both link and normalized config.
- Happy path: app relaunch can load the previously stored subscription without re-fetching user input.
- Edge case: re-importing the same valid link updates the stored config and fetched timestamp deterministically.
- Error path: malformed subscription content is rejected and leaves the previous stored subscription intact.
- Error path: unreachable subscription URL returns a retryable failure and does not clear active stored state.
- Integration: `AutoModeViewModel` initialized with stored subscription state renders “ready to optimize” instead of blank import state.

**Verification:**
- A previously accepted subscription survives app relaunch, and rejected imports no longer wipe usable state.

- [ ] **Unit 2: Replace the in-memory adapter with a real tunnel-session control boundary**

**Goal:** Make `ClashAdapter` represent real tunnel lifecycle control and status instead of an in-memory success stub.

**Requirements:** R3, R4, R6, R8

**Dependencies:** Unit 1

**Files:**
- Create: `Shared/Engine/TunnelSessionStore.swift`
- Create: `Shared/Domain/TunnelSession.swift`
- Modify: `Shared/Engine/ClashAdapter.swift`
- Modify: `Extension/PacketTunnelProvider.swift`
- Test: `Tests/ClashAdapterTests.swift`
- Test: `Tests/TunnelSessionStoreTests.swift`

**Approach:**
- Introduce a persisted tunnel-session store that tracks the active config identity, last requested action, and latest known runtime state needed for restore and honest UI messaging.
- Add a real runtime seam behind `ClashAdapter` that can configure/start/stop/query the packet-tunnel lifecycle through the app-side manager surface rather than returning `.running` immediately.
- Keep `PacketTunnelProvider` consuming the same serialized `SubscriptionConfig`, but strengthen its error reporting so app-side startup failures can be surfaced cleanly.
- Avoid coupling session persistence to probe execution; sprint 2 is only about runtime start/stop/status truth.

**Technical design:** *(directional guidance, not implementation specification)*

```text
TunnelSession
  - configurationID
  - requestedState
  - runtimeState
  - updatedAt

ClashAdapter.start(config)
  -> persist "starting" session metadata
  -> configure tunnel manager with serialized SubscriptionConfig
  -> request tunnel start
  -> read resulting status
  -> persist running/failed state
```

**Patterns to follow:**
- Preserve the protocol-based seam already defined by `ClashControlling` and `ClashEngine`.
- Reuse the existing `SubscriptionConfig` JSON handoff contract already consumed in `PacketTunnelProvider`.

**Test scenarios:**
- Happy path: starting with a valid config persists a starting session and resolves to running status with the matching configuration ID.
- Happy path: stopping the adapter transitions persisted session state to stopped without losing the last config identity.
- Edge case: querying status with no prior session returns a truthful stopped/empty state.
- Error path: tunnel configuration or startup failure persists failed status with a user-displayable message.
- Error path: provider startup without serialized config still returns a deterministic missing-configuration failure.
- Integration: adapter status after start matches the session metadata restored on the next app launch.

**Verification:**
- `ClashAdapter` no longer behaves like an unconditional in-memory success stub and can report durable runtime truth.

- [ ] **Unit 3: Restore subscription and tunnel truth into the app shell**

**Goal:** Make app launch and Auto Mode consume restored subscription/session state before the user acts.

**Requirements:** R1, R3, R5, R6, R8

**Dependencies:** Units 1-2

**Files:**
- Modify: `App/RockeRoomApp.swift`
- Modify: `App/AppRootView.swift`
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Modify: `App/AutoMode/AutoModeView.swift`
- Modify: `App/ExpertConsole/ExpertConsoleViewModel.swift`
- Test: `Tests/AutoModeViewModelTests.swift`
- Test: `Tests/AppSessionRestoreTests.swift`

**Approach:**
- Introduce a launch-time restore path that loads the stored subscription and latest tunnel session metadata before rendering the main Auto Mode state.
- Keep this restore path in app composition code or an app-scoped bootstrap layer rather than putting persistence reads directly into SwiftUI views.
- Update Auto Mode copy/state mapping so the screen can distinguish between “no subscription imported,” “subscription ready,” “tunnel starting,” “tunnel running,” and “tunnel failed.”
- Keep Expert Console read-only in this sprint, but feed it restored snapshot/session context when opened so it does not contradict Auto Mode.

**Patterns to follow:**
- Follow the current `AppRootView` role as the coordination point between Auto Mode and Expert Console.
- Keep view models consuming shared engine outputs rather than owning separate persistence or runtime logic.

**Test scenarios:**
- Happy path: launch with stored subscription and running session seeds Auto Mode with ready/running state without manual re-import.
- Happy path: launch with stored subscription but stopped session shows ready-to-optimize state rather than pretending the tunnel is active.
- Edge case: launch with stored subscription and failed last session shows recoverable degraded state plus a valid retry path.
- Error path: missing or corrupted persisted session metadata falls back to safe stopped state without crashing or wiping the stored subscription.
- Integration: opening Expert Console after launch reflects the same restored state seen in Auto Mode.

**Verification:**
- The app opens into a truthful restored state instead of forgetting accepted configuration and runtime status between launches.

- [ ] **Unit 4: Prove the first real trust loop with UI and integration coverage**

**Goal:** Replace the sprint-1 placeholder test with a real first-run import/optimize/restore regression suite for sprint 2.

**Requirements:** R6, R7, R8

**Dependencies:** Units 1-3

**Files:**
- Modify: `UITests/FirstRunOptimizeFlowTests.swift`
- Modify: `Tests/ClashAdapterTests.swift`
- Modify: `Tests/ClashSubscriptionImporterTests.swift`
- Create: `Tests/SubscriptionRestoreIntegrationTests.swift`
- Create: `UITests/SubscriptionRecoveryFlowTests.swift`

**Approach:**
- Convert the skipped first-run UI test into an executable flow that covers successful import, optimize, and post-launch restoration.
- Add integration tests for the trust-sensitive boundaries that unit tests alone will miss: failed re-import preserving prior state, tunnel-start failure surfacing degraded state, and restore after a prior accepted session.
- Keep UI assertions centered on honest user-visible states rather than internal implementation details.

**Execution note:** Implement this unit test-first against the restored-state and runtime APIs from Units 1-3; do not treat UI automation as a final cleanup task.

**Patterns to follow:**
- Extend the existing UI test file rather than replacing it with parallel duplicates for the same flow.
- Preserve the product-language constraints from the design review: calm Auto Mode, explicit failures, no fake certainty.

**Test scenarios:**
- Happy path: first run imports a valid subscription link, optimizes successfully, and shows a recommendation-ready Auto Mode state.
- Happy path: relaunch after a successful import/optimize path restores subscription and tunnel readiness without re-entering the link.
- Edge case: retrying import after a malformed subscription leaves the prior valid subscription active and reaches success after correction.
- Error path: tunnel-start failure shows a clear degraded message while preserving the stored subscription for retry.
- Integration: the UI restore path after relaunch matches the persisted repository/session state from shared-engine integration tests.

**Verification:**
- Sprint 2 has one unskipped end-to-end trust loop proving import, startup, restore, and recovery behavior together.

## System-Wide Impact

- **Interaction graph:** import UI, Auto Mode orchestration, shared importer, subscription repository, tunnel session store, adapter control, and packet-tunnel provider all participate in the sprint-2 path.
- **Error propagation:** fetch failures, parse failures, tunnel configuration failures, and startup failures must surface as distinct recoverable UI states without silently clearing good persisted state.
- **State lifecycle risks:** subscription state and tunnel session state can drift if configuration identity is not shared consistently across stores and adapter status responses.
- **API surface parity:** app and extension must continue consuming the same serialized `SubscriptionConfig`; any contract drift here will break startup and restore.
- **Integration coverage:** relaunch restore, failed re-import preservation, and adapter-start/session-store parity require cross-layer tests beyond unit coverage.
- **Unchanged invariants:** recommendation policy remains centralized, pin behavior remains unchanged, and sprint 2 does not introduce marketplace or observability-scope expansion.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Apple tunnel-manager lifecycle introduces more async state complexity than the current app shell assumes | Isolate the runtime lifecycle behind `ClashAdapter` and `TunnelSessionStore` so SwiftUI surfaces consume normalized status rather than raw manager events |
| Persisted subscription and session state drift apart after partial failures | Store config identity in both repositories and add restore integration tests that prove failed re-imports and failed starts do not corrupt active state |
| UI restore logic becomes tightly coupled to persistence implementation | Keep restore in app composition/view-model seams and test against normalized repository/session outputs instead of storage details |
| Sprint 2 grows into snapshot persistence or refresh work | Keep snapshot persistence explicitly out of scope and treat probe execution as session-local until sprint 3 |

## Documentation / Operational Notes

- Update the roadmap plan if sprint 2 implementation discovers a necessary storage or manager-wrapper split that changes sprint 3 assumptions.
- If tunnel-manager setup requires additional entitlements, capabilities, or local development notes, capture them in a top-level `README.md` or a focused setup doc during implementation rather than leaving them implicit.

## Sources & References

- Existing sprint roadmap: `docs/plans/2026-04-04-003-feat-ios-next-sprints-roadmap-plan.md`
- Existing sprint-1 plan: `docs/plans/2026-04-04-001-feat-ios-alpha-foundation-plan.md`
- Existing sprint-1 checklist: `docs/plans/2026-04-04-002-feat-ios-alpha-foundation-checklist.md`
- Current Auto Mode seam: `App/AutoMode/AutoModeViewModel.swift`
- Current app shell seam: `App/AppRootView.swift`
- Current import flow: `App/Import/SubscriptionImportView.swift`
- Current adapter seam: `Shared/Engine/ClashAdapter.swift`
- Current provider boundary: `Extension/PacketTunnelProvider.swift`
- Current first-run UI gap: `UITests/FirstRunOptimizeFlowTests.swift`
- Constraint backlog: `TODOS.md`
