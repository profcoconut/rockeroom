# Live E2E Workflow

RockeRoom now supports a launch-driven live E2E workflow so simulator validation can replay most of the manual checklist even when the current XcodeBuildMCP surface does not expose `tap` or `type_text`.

## What This Covers

- importing a subscription from a live URL or deterministic fixture
- running the benchmark loop
- opening `Home`, `Expert Console`, and `Marketplace`
- pinning and unpinning from the normal recommendation path
- stale restore and refresh
- tunnel failure and recovery

## Scenario Contract

The app reads these launch environment keys:

- `ROCKEROOM_LIVE_E2E_SCENARIO`
- `ROCKEROOM_LIVE_E2E_LINK`

Supported scenarios:

- `import-home`
- `benchmark-home`
- `expert-console`
- `pin-stable`
- `pin-unpin-home`
- `marketplace`
- `stale-hint`
- `stale-refresh`
- `tunnel-failure`
- `tunnel-recovery`

The runner is state-aware. It uses the normal view-model methods for import, benchmark, tab selection, and pinning rather than bypassing product code.

## Deterministic Regression Mode

Use this when you want stable regression coverage with the captured live-format fixture.

Launch environment:

```text
ROCKEROOM_RESET_STORAGE=1
ROCKEROOM_STORAGE_SUITE=live-e2e-deterministic
ROCKEROOM_USE_DEMO_FETCHER=1
ROCKEROOM_USE_DEMO_TUNNEL=1
ROCKEROOM_LIVE_E2E_SCENARIO=expert-console
ROCKEROOM_LIVE_E2E_LINK=https://example.com/live-e2e
ROCKEROOM_DEMO_SUBSCRIPTION_PAYLOAD_B64=<base64 of Tests/Fixtures/live-vless-subscription.txt>
```

Recommended XCTest coverage:

- `UITests/LiveE2EWorkflowTests.swift`
- `UITests/FirstRunOptimizeFlowTests.swift`
- `UITests/ManualPinFlowTests.swift`

## True Live Import Mode

Use this when the flow depends on a real provider URL and you need live E2E validation.

Launch environment:

```text
ROCKEROOM_RESET_STORAGE=1
ROCKEROOM_STORAGE_SUITE=live-e2e-live-provider
ROCKEROOM_USE_DEMO_TUNNEL=1
ROCKEROOM_LIVE_E2E_SCENARIO=benchmark-home
ROCKEROOM_LIVE_E2E_LINK=https://liangxin.xyz/api/v1/liangxin?OwO=c03c31babaa7f4dd1f9f45f79aecb2a2
```

Notes:

- omit `ROCKEROOM_USE_DEMO_FETCHER` so the app performs the real fetch
- keep `ROCKEROOM_USE_DEMO_TUNNEL=1` unless you are explicitly validating the system tunnel path
- this validates real provider compatibility while keeping simulator execution deterministic enough to inspect

## XcodeBuildMCP Workflow

1. Set session defaults for the project, scheme, and simulator.
2. Use `build_run_sim` when the scheme is healthy.
3. If you need explicit control, use `build_sim`, `install_app_sim`, and `launch_app_sim`.
4. Capture evidence with `snapshot_ui`, `screenshot`, and log capture tools.

Checks to inspect per flow:

- `import-home`: setup screen disappears and `Home` tab shell appears
- `benchmark-home`: recommendation card shows measured state and populated metrics
- `expert-console`: ranked candidates render and control state is visible
- `pin-unpin-home`: app returns to `Home` with no pinned banner and recommendation restored
- `stale-hint`: refresh hint is visible after relaunch with old evidence
- `stale-refresh`: refresh hint clears after rerunning the benchmark
- `tunnel-failure`: recoverable failure text is visible on `Home`
- `tunnel-recovery`: benchmark succeeds on the next launch and tunnel state returns to running

## Limitations

- This workflow does not pretend to be true free-form UI automation. It is a launch-driven replay path for the most important user journeys.
- When XcodeBuildMCP exposes full interaction tools in a future session, this workflow still remains useful because it gives a deterministic fallback and a shared scenario contract for both MCP and XCTest.
