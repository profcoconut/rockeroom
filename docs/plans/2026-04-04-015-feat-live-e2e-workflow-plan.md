---
title: feat: live e2e workflow
type: feat
status: completed
date: 2026-04-04
origin: docs/plans/2026-04-04-013-feat-live-subscription-compatibility-plan.md
---

# feat: live e2e workflow

## Overview

RockeRoom now imports the validated live `vless://` subscription shape, but the end-to-end validation story is still fragmented. The current repo can prove parser correctness and simulator-backed UI flows through XCUITest, yet plugin-driven simulator validation is incomplete because the shared scheme still launches `PacketTunnelExtension` instead of `RockeRoom.app`, and this session's MCP surface exposes screenshot/UI inspection but not tap/type controls.

The result is a gap between "tests pass" and "a realistic live user journey can be replayed and verified repeatedly." This plan closes that gap by making live E2E validation first-class: fix the app launch surface for MCP, add a launch-driven in-app automation harness for critical user journeys, and codify a repeatable simulator workflow that approximates real user experience as closely as the available tool surface allows.

## Problem Frame

The user explicitly wants a full live E2E testing workflow that simulates most of manual testing and the real user experience. The codebase already carries simulator validation requirements in `AGENTS.md`, and the live subscription compatibility work proved the provider URL shape, but the actual workflow is still weak in three places:

- MCP one-shot build/run currently targets the extension bundle instead of the app
- iOS MCP inspection works, but interactive controls such as text entry are not exposed in this session
- the automated UI suite still depends heavily on direct XCUITest tapping rather than a reusable live-scenario harness that MCP launches can drive

See origin: `docs/plans/2026-04-04-013-feat-live-subscription-compatibility-plan.md`

## Requirements Trace

- R1. The shared `RockeRoom` scheme must launch the main app cleanly so MCP-driven simulator workflows do not require manual bundle-path workarounds.
- R2. The app must support a launch-driven live E2E automation mode that can exercise realistic import/benchmark/navigation flows without relying on unavailable MCP tap/type controls.
- R3. The workflow must cover the highest-signal user journeys: live import, benchmark, recommendation display, expert-console inspection, manual pin/unpin, stale restore, and failure recovery.
- R4. The workflow must use the validated live provider shape or a faithful captured fixture when deterministic automation is required.
- R5. The repo must contain a durable checklist/workflow document describing how to run the live E2E pass with XcodeBuildMCP plus what evidence to inspect.

## Scope Boundaries

- No attempt to build a general-purpose UI automation framework for arbitrary future screens
- No requirement to depend on true live network availability inside every automated test
- No expansion into full runtime execution compatibility for every proxy URI scheme
- No Marketplace feature work beyond validating its current placeholder state

## Context & Research

### Relevant Code and Patterns

- `App/RockeRoomApp.swift` centralizes startup and environment-driven wiring
- `App/AppRootView.swift` owns setup-vs-shell routing
- `App/AutoMode/AutoModeViewModel.swift` already supports environment-driven fetcher/tunnel substitutions and live-format fixture injection
- `UITests/FirstRunOptimizeFlowTests.swift` and `UITests/ManualPinFlowTests.swift` are the existing behavioral UI workflow tests
- `RockeRoom.xcodeproj/xcshareddata/xcschemes/RockeRoom.xcscheme` is currently misconfigured to launch `PacketTunnelExtension.appex`

### Institutional Learnings

- `AGENTS.md` requires simulator validation and live E2E/manual testing for real external URLs
- `docs/plans/2026-04-04-013-feat-live-subscription-compatibility-plan.md` established that the validated provider returns base64 `vless://` feed content and that deterministic fixture-backed simulator validation is acceptable when live network is not stable enough for the test suite

### External References

- XcodeBuildMCP plugin guidance expects scheme/run actions to target the main app and relies on session defaults for bundle ID and simulator launch flow

## Key Technical Decisions

- Use app-side launch automation rather than depending on unavailable MCP tap/type controls: this keeps the workflow usable in inspection-only MCP sessions.
- Keep deterministic CI/UI tests fixture-backed, but add a launch mode that can ingest a real URL when running manual or MCP-assisted live validation.
- Fix the shared Xcode scheme now instead of preserving the extension-first setup: plugin-driven iOS validation is otherwise permanently brittle.
- Model live E2E scenarios as a small set of named flows rather than free-form script commands: easier to test, review, and keep aligned with product behavior.

## Open Questions

### Resolved During Planning

- Should the workflow depend entirely on MCP interaction? No. The current MCP surface is inconsistent across sessions, so the app must carry a fallback automation harness.
- Should live provider traffic be required inside automated XCTest? No. Deterministic fixture-backed automation remains the default, with optional real-URL validation layered on top.

### Deferred to Implementation

- Exact scenario naming and environment variable keys for the automation harness
- Whether the automation harness should live in `RockeRoomApp.swift` or a dedicated `App/Automation/` module
- Whether one combined "journey runner" or multiple focused scenarios produce clearer assertions and screenshots

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```text
MCP launch / XCUITest launch
  -> launch environment selects scenario
  -> app bootstraps normal view model stack
  -> scenario runner observes app state transitions
  -> runner triggers import / benchmark / tab selection / pin-unpin actions
  -> UI settles on a verifiable screen state
  -> XCUITest or MCP snapshot/screenshot/log capture verifies outcome
```

## Implementation Units

- [ ] **Unit 1: Fix the app launch surface for MCP**

**Goal:** Ensure the shared scheme and plugin workflow launch `RockeRoom.app` rather than `PacketTunnelExtension.appex`.

**Requirements:** R1

**Dependencies:** None

**Files:**
- Modify: `RockeRoom.xcodeproj/xcshareddata/xcschemes/RockeRoom.xcscheme`
- Modify: `project.yml`

**Approach:**
- Change macro expansion, launch action, and profile action to target `RockeRoom.app`
- Preserve test target coverage while removing extension-first run behavior
- Regenerate the project if the scheme template in `project.yml` also needs alignment

**Patterns to follow:**
- Existing generated scheme structure in `RockeRoom.xcodeproj/xcshareddata/xcschemes/RockeRoom.xcscheme`

**Test scenarios:**
- Happy path: MCP `build_run_sim` launches the app without trying to install `PacketTunnelExtension.appex`
- Integration: `get_sim_app_path` resolves the app bundle relevant to launch workflows rather than only the extension bundle

**Verification:**
- XcodeBuildMCP one-shot build/run no longer fails on missing `PacketTunnelExtension.app`

- [ ] **Unit 2: Add launch-driven live E2E scenario automation**

**Goal:** Let the app replay critical user journeys from launch environment alone so MCP inspection tools can verify realistic flows without manual taps.

**Requirements:** R2, R3, R4

**Dependencies:** Unit 1

**Files:**
- Create: `App/Automation/LiveE2EScenario.swift`
- Create: `App/Automation/LiveE2ERunner.swift`
- Modify: `App/RockeRoomApp.swift`
- Modify: `App/AppRootView.swift`
- Modify: `App/Shell/MainTabView.swift`
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Test: `Tests/LiveE2EScenarioTests.swift`

**Approach:**
- Add a small scenario parser fed by launch environment
- Create named flows for:
  - live import to Home
  - import plus benchmark
  - benchmark plus Expert Console inspection
  - pin/unpin loop
  - stale restore refresh
  - tunnel failure recovery
- Keep runner behavior state-aware and idempotent so repeated scene activation does not replay actions incorrectly

**Execution note:** Add characterization coverage around scenario parsing and idempotent replay before wiring the full runner.

**Patterns to follow:**
- Environment-driven wiring in `App/RockeRoomApp.swift`
- State transitions in `App/AutoMode/AutoModeViewModel.swift`

**Test scenarios:**
- Happy path: a live-import scenario auto-imports a supplied link and lands in `Home`
- Happy path: a benchmark scenario reaches a measured current setup and recommendation state
- Edge case: unknown scenario name is ignored without corrupting normal app launch
- Edge case: scenario actions do not replay indefinitely after foreground changes
- Error path: invalid live URL scenario stops on setup error state rather than forcing the shell
- Integration: pin/unpin scenario updates both `Home` and `Expert Console` surfaces through the normal view-model path
- Integration: stale restore scenario restores persisted snapshot state, shows refresh hint, then clears it after rerun

**Verification:**
- Launching the app with a scenario environment reliably drives the intended screen state without manual interaction

- [ ] **Unit 3: Expand the automated live E2E suite**

**Goal:** Cover the highest-signal real-user flows with deterministic UI tests and scenario-backed assertions.

**Requirements:** R3, R4

**Dependencies:** Unit 2

**Files:**
- Modify: `UITests/FirstRunOptimizeFlowTests.swift`
- Modify: `UITests/ManualPinFlowTests.swift`
- Create: `UITests/LiveE2EWorkflowTests.swift`
- Test: `Tests/Fixtures/live-vless-subscription.txt`

**Approach:**
- Keep current manual-tap UI tests where they are already stable
- Add scenario-backed UI tests for flows that previously required manual interaction or repeated tap choreography
- Use the captured live `vless://` fixture for deterministic automation coverage
- Assert on user-visible state, not only internal titles, so tests reflect actual experience

**Patterns to follow:**
- Existing storage-suite based UI test isolation in `UITests/FirstRunOptimizeFlowTests.swift`
- Existing fixture-backed live import path in `UITests/FirstRunOptimizeFlowTests.swift`

**Test scenarios:**
- Happy path: live-format import plus benchmark shows a measured current setup in `Home`
- Happy path: Expert Console opens with ranked candidates after scenario-driven benchmark
- Happy path: manual pin then unpin changes the current setup and policy state as expected
- Error path: tunnel failure scenario surfaces recoverable failure text and later recovery
- Integration: stale restore workflow crosses relaunch boundaries and refreshes evidence

**Verification:**
- The serialized UI suite can replay most of the manual checklist through automation with no live tapping required

- [ ] **Unit 4: Add the MCP-facing live E2E workflow guide**

**Goal:** Document how to run the full live E2E pass with XcodeBuildMCP, including deterministic and true-live modes.

**Requirements:** R5

**Dependencies:** Units 1-3

**Files:**
- Create: `docs/testing/live-e2e-workflow.md`
- Modify: `AGENTS.md`

**Approach:**
- Document:
  - scheme prerequisites
  - deterministic fixture-backed scenario runs
  - optional real-URL launch mode
  - MCP commands for build/run, screenshot, UI snapshot, and logs
  - what visual and textual evidence to inspect per flow
- Make the distinction explicit between deterministic regression coverage and true live provider validation

**Patterns to follow:**
- Existing repo workflow notes in `AGENTS.md`

**Test scenarios:**
- Test expectation: none -- documentation and workflow guidance only

**Verification:**
- A contributor can run the live E2E workflow from the doc without rediscovering environment variables or MCP limitations

## System-Wide Impact

- **Interaction graph:** app startup now includes optional scenario automation on top of the normal import/benchmark shell
- **Error propagation:** scenario runner must never swallow import or tunnel failures; it should drive the app into the same visible failure states a user would see
- **State lifecycle risks:** replaying startup actions across scene activations can duplicate imports, benchmarks, or pin operations if not guarded
- **API surface parity:** XCUITest launch environments and MCP launch environments must target the same scenario contract
- **Integration coverage:** the workflow needs both XCTest assertions and MCP screen/log capture because either one alone misses regressions
- **Unchanged invariants:** normal user launches without a scenario environment must remain unchanged

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Scenario automation leaks into normal user behavior | Gate everything behind explicit launch environment and add negative tests |
| MCP build/run remains brittle even after scheme changes | Verify with XcodeBuildMCP during implementation, not only through XCTest |
| Scenario runner becomes a second app architecture | Keep scenarios narrow, state-based, and built on existing view-model methods rather than parallel control paths |
| Real provider availability is unstable | Separate deterministic fixture-backed regression coverage from optional true-live validation |

## Documentation / Operational Notes

- Keep the workflow doc explicit about which checks are deterministic regression gates versus best-effort live provider validation
- If MCP interactive controls appear in future sessions, the workflow doc should still remain valid because it is launch/scenario based rather than tap-script based

## Sources & References

- **Origin document:** `docs/plans/2026-04-04-013-feat-live-subscription-compatibility-plan.md`
- Related code: `App/RockeRoomApp.swift`
- Related code: `App/AutoMode/AutoModeViewModel.swift`
- Related code: `UITests/FirstRunOptimizeFlowTests.swift`
- Related code: `RockeRoom.xcodeproj/xcshareddata/xcschemes/RockeRoom.xcscheme`
