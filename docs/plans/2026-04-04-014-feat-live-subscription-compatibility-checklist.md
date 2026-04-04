---
title: feat: live subscription compatibility checklist
type: feat
status: completed
date: 2026-04-04
origin: docs/plans/2026-04-04-013-feat-live-subscription-compatibility-plan.md
---

# feat: live subscription compatibility checklist

## Goal

Execute the live subscription compatibility plan so RockeRoom can import the validated base64 `vless://` subscription shape, explain failures honestly, and prove the flow with simulator-backed validation.

## Checklist

- [x] Capture a sanitized representative `vless://` subscription fixture from the validated live payload
- [x] Add characterization tests proving the current importer sees a URI feed rather than Clash YAML
- [x] Add importer parsing support for base64 URI subscription feeds, starting with `vless://`
- [x] Preserve parsed URI details in `ClashProxy.metadata` while populating name, type, server, and port
- [x] Ignore metadata-only feed lines that are not actual proxies
- [x] Add or update importer tests for:
  - accepted `vless://` feed
  - malformed/unsupported URI lines
  - mixed feed with metadata and valid proxy lines
- [x] Improve user-facing import failure messaging for fetched-but-unsupported content
- [x] Tighten setup-screen copy so supported subscription formats are stated honestly
- [x] Add simulator-backed validation for the real-format import flow without using demo fixtures
- [x] Re-run the full serialized Xcode test gate
- [x] Re-run live validation against the real payload shape and confirm the importer outcome
- [x] Update the plan file status when implementation is complete
