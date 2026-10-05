# Plan

## Architecture

Trellis is a SwiftUI application with five system tabs: Home, Repositories, Inbox,
Search, and More. NavigationStack routes native resources and persistent SwiftUI
WebView fallbacks. @Observable MainActor session state owns credentials, navigation,
and visible errors; actor-isolated GitHubKit owns networking/cache/rate limits.

| Module | Responsibility |
| --- | --- |
| Packages/GitHubKit | Foundation-only REST/GraphQL transport, JSON models, device flow, pagination, conditional cache, rate limits, workflow inputs, tested stubs |
| App/Core | Default-group Keychain, session, bounded account cache, background refresh, local notifications |
| App/Views | System tabs, loading/empty/offline/error states, native resources, editors, profile and contributions |
| App/Features | Repository creation/content, issues/PR reviews, Actions, administrative resources, extended API surfaces |
| App/Rendering | Textual Markdown/code, native unified diffs and ANSI logs |
| App/Shortcuts | App Intents opening inbox/repositories without shared containers |
| AppTests / AppUITests | Deterministic tests and simulator screen captures |
| scripts / .github | Project generation, testing, unsigned archive, structural validation, checksums, tagged releases |

## Milestones

Each milestone commits independently. Shipping requires a successful CI run;
implementation status and shipping status are distinct in PROGRESS.md.

| Milestone | Native scope | Fallback / limitation |
| --- | --- | --- |
| M1 | Device flow/PAT, shell, profile/contributions, repos/search | Organization restrictions explained; fine-grained scopes may be unknown |
| M2 | Repository creation, code/files, history/compare, management | Advanced rulesets/organization transfer requirements may use web |
| M3 | Issues, comments/reactions, PR diffs/reviews/checks/merge | Rich project and merge-queue policy UX may use web |
| M4 | Workflows/runs/jobs/logs/control/dispatch/artifacts/cache/secrets/variables/environments/runners | Live log completeness and billing availability depend on public API |
| M5 | Native inbox/filter/actions; background polling/local notices | No APNs; polling not guaranteed by iOS |
| M6 | Releases/packages/projects/discussions/gists/security/insights/orgs/teams/codespaces/keys | Wiki/Sponsors purchases/token creation/Copilot chat use web |
| M7 | App Shortcuts, accessible system controls, bounded memory | Widgets excluded until extension signing confirmed; real-device performance unmeasured |

## Validation

- GitHubKit deterministic stub tests on Windows and macOS: auth polling/errors,
  JSON/model parsing, pagination, conditional requests, backoff, account isolation,
  workflow typed inputs and diff parsing.
- App unit tests on an available iOS 27 simulator; UI tests use clearly labeled demo
  content to navigate main screens and save screenshots. Inspect downloaded images.
- Release archive uses CODE_SIGNING_ALLOWED=NO. Verify Payload structure, bundle ID,
  iOS 26 minimum, iPhone/iPad device families, arm64, absence of provisioning profile.
- Upload IPA, SHA-256, verification report and screenshots. Publish only green tag build.
- Scan tracked files and full git history for secret patterns and machine/account data.

## Risks

Runner preview capacity and installed SDK changes; use explicit selection and log SDKs.
Third-party package Swift 6 compatibility must be checked by real CI, not assumed.
OAuth scopes do not override repository role, SSO, organization policy or paid tiers.
API inventory is not the same as native UI completeness: FEATURES.md tracks actual
implementation and always identifies partial screens. Web cookies require separate login.
KravaSign certificate capabilities, expiration and on-device installation are outside
CI verification. Use no special entitlement or embedded app extension.
