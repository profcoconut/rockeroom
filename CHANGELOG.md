# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0.0] - 2026-04-04

### Added
- Added a setup-first v1 shell with dedicated `Home`, `Expert Console`, and `Marketplace` tabs so first-run users land on subscription import before seeing the control surface.
- Added live subscription compatibility for base64 VLESS-style URI feeds, including fixture-backed importer coverage for real provider payloads.
- Added a launch-driven live E2E workflow for simulator validation, including scenario contracts, XCTest coverage, and contributor docs for true live-provider replay.

### Changed
- Reframed Home around the real benchmark loop with recommendation state, measured summary metrics, stale refresh hints, and clearer benchmark copy.
- Updated the shared Xcode scheme so simulator launch targets `RockeRoom.app` directly, which unblocks `XcodeBuildMCP` build-and-run flows.
- Marked the product reset, live subscription compatibility, and live E2E implementation plans complete and linked the new workflow from repo instructions.

## [0.0.1.0] - 2026-04-04

### Added
- Added a TestFlight-focused alpha release checklist and a documented serialized simulator gate for RockeRoom contributors.

### Changed
- Hardened the app restore path so UI tests can inject deterministic time and verify stale evidence and recovery behavior honestly.
- Expanded Auto Mode and Expert Console regression coverage for stale restore, tunnel-start recovery, and pin and unpin flows.
- Updated the sprint roadmap and hardening artifacts to reflect the current alpha gate and release assumptions.

### Fixed
- Fixed startup wiring so the app clock injection path stays on the main actor and compiles cleanly under Swift 6 isolation.
- Fixed stale-restore UI assertions to check the real user-facing stale state instead of brittle test-only assumptions.
