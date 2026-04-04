# RockeRoom

RockeRoom is an alpha iOS app that uses Clash as the execution core and keeps recommendation truth in one shared snapshot/policy layer.

## Current Model

- Auto Mode is the home surface.
- Expert Console is the inspect surface.
- Marketplace is read-only and evidence-based.
- Manual pin means no auto-switch until the user unpins.

## Evidence Model

All user-facing evidence comes from the same shared snapshot and recommendation output. That keeps Auto Mode, Expert Console, and Marketplace aligned on the current setup, freshness, and partial-data state.

## Observability Constraint

The current alpha does not claim private per-app telemetry. The observability spike documents the current platform limit and the fallback language to use when synthetic probes are the best available signal.

## Development

The project is generated from `project.yml`. Use Xcode 17 / iOS 17 with the `RockeRoom` scheme.

## Alpha Validation

Use the integrated `RockeRoom` scheme as the alpha gate. The stable command is:

```sh
xcodebuild -project RockeRoom.xcodeproj -scheme RockeRoom -destination 'platform=iOS Simulator,name=iPhone 17' test -parallel-testing-enabled NO
```

For TestFlight and evaluator handoff steps, see `docs/release/alpha-testflight-checklist.md`.
