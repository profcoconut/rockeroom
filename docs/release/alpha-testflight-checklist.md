# RockeRoom Alpha TestFlight Checklist

This checklist is for internal alpha validation and evaluator handoff. It is intentionally operational, not marketing.

## Preconditions

- Xcode 17 installed
- iOS 17 simulator available, with `iPhone 17` device runtime
- Current repo generated from `project.yml`
- `RockeRoom` scheme available in `RockeRoom.xcodeproj`

## Local Validation Gate

Run the integrated alpha gate before any TestFlight build or manual evaluator handoff:

```sh
xcodebuild -project RockeRoom.xcodeproj -scheme RockeRoom -destination 'platform=iOS Simulator,name=iPhone 17' test -parallel-testing-enabled NO
```

The serial flag is part of the current alpha gate on purpose. It avoids simulator/bootstrap instability seen in combined runs without reducing coverage.

If the command fails because `CoreSimulatorService` loses the simulator device set or the `iPhone 17` destination disappears, treat that as a host-machine issue and rerun after the simulator service recovers.

## Required Product Checks

- Import a valid Clash subscription link and confirm the app reaches `Recommended setup`
- Relaunch the app and confirm the imported subscription and current truth restore correctly
- Confirm stale restore shows a refresh hint and stale wording before a fresh optimize
- Run optimize again and confirm the stale hint clears and evidence returns to current
- Force a tunnel-start failure path and confirm the app shows recoverable failure messaging
- Relaunch after the failure path and confirm optimize can recover without re-importing
- Open Expert Console, pin a candidate, and confirm Auto Mode does not auto-switch
- Unpin from Expert Console and confirm policy-controlled recommendation resumes
- Open Marketplace and confirm it reflects the same current or stale evidence state shown in Auto Mode

## Release Notes for Evaluators

- Auto Mode is the home surface
- Expert Console is the inspection surface
- Marketplace is read-only and evidence-based
- Pinning blocks auto-switching until the user unpins
- The alpha does not claim private per-app observability beyond the observability memo in `docs/research/2026-04-04-ios-observability-spike.md`

## Before Distribution

- Confirm the local validation gate passed on the current commit
- Confirm no skipped tests remain in the alpha-critical import, restore, stale, pin, and recovery flows
- Confirm README still points to this checklist and the current validation command
- Confirm any known evaluator caveats are written down rather than implied
