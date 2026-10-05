# Progress

## 2026-10-05

- Read mission; created local repository and public remote.
- Verified runner image, device flow, public API inventory, SwiftUI APIs and libraries.
- Phase 0 research and architecture plan completed before app code.
- GitHub CLI installed and authenticated using existing local Git credentials.
- Installed GitHub CLI, Swift 6.4 and Visual Studio C++/Windows SDK prerequisites.
- Foundation-only GitHubKit: 14 stubbed tests passed on this Windows PC.
- Implemented native shell, profile/search, repositories/files, issues/PRs,
  Actions/admin resources, inbox, extended GraphQL/REST features and App Shortcuts.
- First simulator/archive run failed on a demo JSON raw-string delimiter; corrected.
- Swift syntax parsing passes on Windows (no iOS compilation attempted).
- Initial implementation passed full integration on Xcode 27 / iOS 27 simulator.
- Current: M1–M7 initial beta, with the documented coverage limits below.
  Distribution uses the gated tag workflow. Current main status is available in
  [Actions](https://github.com/JasperSoosaar25/trellis-ios/actions/workflows/build-ios.yml?query=branch%3Amain).
- Follow-up run: [37353819991](https://github.com/JasperSoosaar25/trellis-ios/actions/runs/37353819991), conclusion **success** (queried with gh run view).
- Added README, row-by-row actual coverage, release notes and bundled license notices.
- Windows package now has 16 passing tests, including mutation invalidation and
  account-cache isolation. All 16 passed again at 21:24 local.
- Downloaded and inspected login, Home, repositories, repository, Actions, inbox,
  Search, More and dark-mode screenshots. Found a demo-banner/navigation overlap;
  corrected container layout and added a UI regression assertion.
- Added native Sponsors records and organization billing reports from verified APIs.
- Downloaded IPA passed Payload/plist/arm64 and SHA-256 checks on Windows too.

## Evidence

CI: [first run](https://github.com/JasperSoosaar25/trellis-ios/actions/runs/37352353053)
failed for commit 7605a87: demo fixture delimiter. Its 14 macOS package tests passed.
Windows: scripts/test-windows.ps1 passed all 14 Swift Testing tests at 20:49 local.
Green integration: [37353819991](https://github.com/JasperSoosaar25/trellis-ios/actions/runs/37353819991)
for aa86333: 14 macOS package tests, 3 app unit tests, 2 UI tests, simulator screenshots,
Release archive and IPA verification passed. Bundle dev.trellis.client, minimum
iOS 26.0, families 1/2, arm64, no provisioning profile or extension; 5.74 MiB IPA.
Follow-up integration: [37357009903](https://github.com/JasperSoosaar25/trellis-ios/actions/runs/37357009903)
for 5ff3056, conclusion **success**, queried with gh run view. All 17 macOS package
tests, 3 app unit tests and 3 UI tests passed. Dark and accessibility-size screenshots
were inspected; repository/Actions navigation controls no longer overlap the banner.
The IPA also has no embedded signing entitlements and includes bundled license notices.
Release distribution is through the gated tag workflow; published artifacts appear
on [Releases](https://github.com/JasperSoosaar25/trellis-ios/releases).

Final resource audit: 17 Windows package tests pass, including loading 40 persisted
pages without exceeding the 32 MiB memory budget. Cache restores now share eviction
rules with writes. Apple API responses stop at 16 MiB while reading into memory;
OAuth response tokens never go through a temporary download file. Large Actions logs
stream to disk and read only a 2 MiB tail. An empty notification baseline correctly
allows the first later notification, and recent IDs take priority in the bound.

Final confirmation/demo regressions add a unit check for REST and GraphQL write
rejection, and a UI check that opens and cancels comment deletion. Matching creation,
file and comparison browser routes are reachable from their toolbars. Windows tests
passed all 17 again at 21:45 local. Coverage: 27 native, 42 partial, 5 browser, 3
excluded rows. See FEATURES.md for precise beta gaps, and NEEDS_FROM_USER.md for
installation, authentication and actual-device verification.

Confirmation regression: [37361465225](https://github.com/JasperSoosaar25/trellis-ios/actions/runs/37361465225)
for a9ff761 concluded **failure**. All 17 package tests and 4 app unit tests passed;
three UI tests passed. The fourth opened the deletion confirmation successfully,
then failed because the system popover did not expose a Cancel button. The test now
uses Cancel when present or dismisses outside the popover, and verifies both its
disappearance and the unchanged comment. Failure screenshots are exported before
the build script exits. This check remains enabled in main and tagged release CI.

## Final code validation and distribution handoff

[37364416747](https://github.com/JasperSoosaar25/trellis-ios/actions/runs/37364416747)
for 9c8f24f concluded **success** at 19:55 UTC. The conclusion was independently
queried through the GitHub connection after local CLI access became unavailable.
All 17 macOS package tests passed; simulator app/UI tests, screenshot export,
Release archive and IPA verification succeeded with the confirmation check enabled.
The earlier 17 Windows tests cover the same unchanged package sources.

Verified IPA: dev.trellis.client, minimum iOS 26.0, device families 1/2, arm64,
49 ZIP entries, no provisioning profile, extension or embedded signing entitlement.
SHA-256: `08170a0cd12e2de5fd57bb7211f74242978b2f72dd4bd87d87521df19c68b9f8`.
Artifacts: Trellis-unsigned (11368117719) and Trellis-screenshots-and-tests
(11368177941). Earlier downloaded screenshots and IPA were inspected and checked
on Windows as recorded above; the final artifacts could not be downloaded in the
resumed restricted session.

**Distribution remains pending.** A repository Releases query returned no releases.
The resumed session's network cannot connect to github.com:443, so it cannot push
the release tag. The Windows setup helper initially returned error 1223 after its
popup was closed; local commands later recovered, but network access remains blocked.
The GitHub connection can read CI results but has no tag/release publishing tool.
RUN_ON_MY_PC.md contains the exact commands to push this documentation and v1.0.0
from normal PowerShell. The existing tag workflow tests and verifies its own IPA
before publishing. No signing secrets or user credentials are required.
