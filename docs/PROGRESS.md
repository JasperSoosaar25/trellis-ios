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
- Current: validate final privacy/accessibility changes and screenshot corrections,
  then publish a verified beta IPA through the tag workflow.
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
Final changes still require their own green run before tagging. No Release published yet.
