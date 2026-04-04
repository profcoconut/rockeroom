# Changelog

All notable changes to this project will be documented in this file.

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
