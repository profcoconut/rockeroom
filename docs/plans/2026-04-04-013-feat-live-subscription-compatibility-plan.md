---
title: feat: live subscription compatibility
type: feat
status: completed
date: 2026-04-04
---

# feat: live subscription compatibility

## Overview

Live validation against `https://liangxin.xyz/api/v1/liangxin?OwO=c03c31babaa7f4dd1f9f45f79aecb2a2` shows that RockeRoom’s current import path is too narrow for real-world subscription feeds. The URL responds successfully to a normal GET, but the payload is a base64-encoded list of `vless://...` share links rather than Clash YAML. The current importer only accepts HTTP(S) links whose response text can be parsed as Clash-style YAML with `proxies:` or `proxy-providers:` content.

This means the redesigned flow works for the demo path but fails on a realistic subscription source. The app currently rejects that payload as malformed content and gives the user no useful explanation of why.

## Concrete Findings

- The live URL is reachable via GET and returns content, so the primary failure is not network connectivity.
- `curl -I` receives a Cloudflare challenge, but `curl -L` GET succeeds. The importer uses GET via `URLSession`, so HEAD-specific failure is not the main blocker.
- The response body is base64 text that decodes to multiple `vless://` URIs plus metadata lines like remaining traffic and expiry.
- `ClashSubscriptionImporter.importSubscription(from:)` accepts the fetch, then calls `importSubscription(from:data:)`, which only routes into `SubscriptionTextParser.parse` after choosing either raw or base64-decoded text.
- `SubscriptionTextParser.parse` only knows how to extract proxies from Clash-like YAML key/value structures. It has no parser for URI subscription formats such as `vless://`, `vmess://`, `trojan://`, or `ss://`.
- The setup screen copy currently implies “paste a subscription link” without clarifying which subscription families are actually supported.

## Problem Frame

RockeRoom is currently positioned as a proxy client, but its import support is still prototype-grade. A user can provide a valid subscription URL and still hit a generic parse failure because the importer recognizes only one serialization shape. That creates a bad trust story:
- the user believes the link is valid
- the network request succeeds
- the app still fails with a vague content error

This is exactly the kind of live E2E gap that demo-driven UI testing will miss.

## Scope

- Add compatibility for base64-encoded URI subscription feeds, starting with `vless://` and the existing proxy families already represented in `ClashProxy.type`
- Improve import failure messaging so unsupported but fetched content is explained clearly
- Add live-payload characterization tests using captured fixture data from the validated URL format
- Re-run simulator-backed import flow against a real non-demo payload

## Non-Goals

- Full support for every Clash/sing-box serialization nuance in one pass
- Building a full proxy-group/rule translator for remote configs
- Marketplace or benchmark changes unrelated to import compatibility

## Implementation Units

- [x] **Unit 1: Characterize the live payload format**

**Goal:** Lock in the exact shape of the real subscription payload so compatibility work is grounded in evidence, not guesses.

**Files:**
- Create: `Tests/Fixtures/live-vless-subscription.txt`
- Create: `Tests/ClashSubscriptionImporterLiveFormatTests.swift`

**Approach:**
- Save a sanitized representative fixture derived from the live payload format.
- Add characterization tests proving:
  - the response is base64-decoded successfully
  - the decoded text is a URI list, not Clash YAML
  - the current importer rejects it today for format reasons, not network reasons

**Verification:**
- A failing or characterization test captures the current incompatibility precisely.

- [x] **Unit 2: Add URI subscription parsing**

**Goal:** Teach the importer to parse base64-encoded URI feed lines into `ClashProxy` models.

**Files:**
- Modify: `Shared/Engine/ClashSubscriptionImporter.swift`
- Modify: `Shared/Domain/SubscriptionConfig.swift`
- Modify: `Tests/ClashSubscriptionImporterTests.swift`
- Modify: `Tests/ClashSubscriptionImporterLiveFormatTests.swift`

**Approach:**
- Introduce a second parsing branch after base64 decode:
  - if decoded text looks like Clash YAML, keep current behavior
  - else if it looks like URI feed content, parse one URI per line
- Start with `vless://` support because that is the live failing case.
- Preserve enough URI components in `ClashProxy.metadata` so the tunnel layer can evolve later without reparsing raw text.
- If additional common schemes (`vmess://`, `trojan://`, `ss://`) are cheap to support in the same parser shape, include them behind tests.

**Verification:**
- The live fixture imports into a non-empty `SubscriptionConfig`.

- [x] **Unit 3: Make import failures honest**

**Goal:** Replace generic parse failure messaging with actionable user-facing explanations.

**Files:**
- Modify: `Shared/Domain/SubscriptionImportResult.swift`
- Modify: `App/Home/SetupHomeView.swift`
- Modify: `App/AutoMode/AutoModeViewModel.swift`
- Modify: `UITests/FirstRunOptimizeFlowTests.swift`

**Approach:**
- Differentiate:
  - invalid URL
  - fetch failure
  - fetched-but-unsupported subscription format
  - fetched-but-empty payload
- Update setup copy so the screen names the supported subscription styles explicitly until compatibility broadens further.

**Verification:**
- When import fails, the user can tell whether the problem is network, link validity, or unsupported format.

- [x] **Unit 4: Validate the real flow in simulator**

**Goal:** Prove the app can import a realistic subscription source outside the demo path.

**Files:**
- Modify: `UITests/FirstRunOptimizeFlowTests.swift`
- Create: `UITests/LiveImportFlowTests.swift`
- Modify: `AGENTS.md`

**Approach:**
- Add a non-demo UI path that injects a real-format fixture or controlled live URL for simulator testing.
- Run the simulator-backed flow through import, landing on `Home`, and benchmark readiness.
- Keep AGENTS guidance explicit that real URLs require live E2E/manual validation, not only demo fixtures.

**Verification:**
- A simulator-backed test or controlled manual validation proves the live subscription shape gets past import and into the main shell.

## Risks

- `ClashProxy` may not currently carry enough structure for full `vless://` runtime execution; import compatibility may land before execution compatibility is complete.
- Some providers mix metadata lines with share links; the URI parser must ignore non-proxy lines cleanly.
- Real subscription feeds may include percent-encoded names and non-ASCII labels; parsing and display need normalization.

## Recommended Order

1. Characterize the live payload in tests.
2. Add URI feed parsing for `vless://` first.
3. Improve user-facing failure messages.
4. Re-run simulator and live validation with the real format.
