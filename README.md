# Trellis

An unofficial native iOS client for GitHub, built with SwiftUI and system Liquid
Glass controls. Requires iOS 26 or later. The original branching icon and app name
do not use GitHub trademarks. Trellis is not affiliated with or endorsed by GitHub.

This is an initial public beta: native API coverage is broad, and advanced settings
also have an embedded browser fallback. Consult [the detailed feature matrix](docs/FEATURES.md)
for implementation limits. A successful build verifies compilation, deterministic
tests and IPA structure; it does not verify your permissions or sideloader certificate.

| Area | What is included |
| --- | --- |
| M1 | PAT and Device Flow sign-in, runtime client ID, profile/contributions, repositories, search |
| M2 | Repository creation options, code/Markdown, file commits/upload, compare, repository management |
| M3 | Issue/PR filters, comments/reactions, metadata, diffs/inline comments, reviews/checks/merge |
| M4 | Actions runs/jobs/logs/control, typed dispatch, artifact sharing, caches, encrypted secrets, variables, environments, runners/settings |
| M5 | Native inbox, read/done/subscription actions, optional background polling and local notifications |
| M6 | Releases, packages, Projects v2, Discussions, gists, security alerts, insights, organizations/teams, Codespaces, public keys |
| M7 | Inbox/repository App Shortcuts, system accessibility controls and bounded API cache |

Widgets, APNs and GitHub Mobile's sign-in approvals are excluded. Wiki, Sponsors
payments, personal-token management, Copilot chat/agent sessions, billing and
Marketplace use the in-app browser. Some API-backed advanced surfaces also use web
for operations not yet represented by the native beta. Browser login is separate
from API authentication.

## Install with KravaSign

1. Open [the latest release](https://github.com/JasperSoosaar25/trellis-ios/releases/latest)
   in Safari and download `Trellis.ipa` to Files.
2. Import the IPA into your KravaSign installation, sign it with your certificate,
   then install it. Alternatively, use the release asset's direct download URL if
   your KravaSign version offers URL import.
3. Open Trellis and paste a personal access token, or configure Device Flow below.
4. Enable background notifications in Trellis Settings if desired. iOS controls the
   refresh schedule, so notifications are not immediate push delivery.

The archive is intentionally unsigned and contains no provisioning profile,
certificate or signing secret. KravaSign must re-sign it. Its exact bundle-ID and
entitlement handling has not been verified on the target device; keep the bundle ID
stable when updating if your signer permits it. A SHA-256 file and verification JSON
accompany each release.

## Device Flow setup

Create an OAuth App in GitHub Settings > Developer settings > OAuth Apps. Set the
homepage to this repository and the callback to any valid URL; enable **Device Flow**.
Set the public Actions repository variable `GH_CLIENT_ID` to its client ID before a
new build, or enter the client ID on Trellis's login screen. No client secret is used.
You can use a PAT immediately without registering an OAuth App.

Basic and optional Administration scope sets are described in [research](docs/RESEARCH.md).
Trellis reports missing classic OAuth scopes. Fine-grained token scopes may be unknown;
choose repository permissions appropriate to the operations you need. Organization
OAuth restrictions and SAML SSO may require approval/authorization.

## Build and validation

On Windows, install Swift and Visual Studio C++/Windows SDK prerequisites, then run:

```powershell
./scripts/test-windows.ps1
```

Only the Foundation-only package is compiled on Windows. iOS builds run on the
`xcode-27` macOS image using Xcode 27.0; manual workflow dispatch offers `macos-26`
with Xcode 26.6 as a fallback. On a Mac with Xcode and XcodeGen:

```sh
bash scripts/build-ios.sh
```

CI tests the package and simulator app, captures the main screens on an iPhone 13
simulator, archives without signing, validates Payload/plist/arm64, and uploads IPA,
checksum, screenshots and diagnostics. Tags matching `v*` publish a Release only
after the build succeeds. Neither device installation nor live account mutations
run in CI. Tests use stubbed responses and clearly labeled fictitious demo content.

See [progress](docs/PROGRESS.md), [decisions](docs/DECISIONS.md), [architecture](docs/PLAN.md),
[manual setup](docs/NEEDS_FROM_USER.md) and [research](docs/RESEARCH.md).

MIT licensed. App-only dependencies: Textual (MIT) and Swift Sodium (ISC). The pure
GitHubKit package has no external dependencies. Bundled notices include transitive
dependency licenses.
