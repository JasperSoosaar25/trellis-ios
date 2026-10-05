# Research — checked 2026-10-05

This document separates API capability from implemented UI. The implementation
matrix is FEATURES.md. Unverified prompt leads are explicitly identified below.

## Official mobile baseline

The [App Store description](https://apps.apple.com/us/app/github/id1477376905)
confirms notification triage, issue/PR reactions and replies, reviews and merging,
labels/assignees/projects, file browsing, and discovery/trending. The
[Mobile documentation](https://docs.github.com/en/get-started/using-github/github-mobile)
additionally lists repository code search, user/repository/organization interaction,
PR file editing, 2FA/sign-in approval, Copilot Chat, and simultaneous accounts across
GitHub.com and enterprise hosts. These are the documented baseline, not a claim
that every github.com operation exists in the official app.

| Feature group | Official evidence / qualification |
| --- | --- |
| Inbox, mentions, focused notifications | [Mobile guide](https://docs.github.com/en/get-started/using-github/github-mobile), [October update](https://github.blog/changelog/2024-10-14-whats-new-in-mobile-october-update/) |
| Issues, comments, reactions, labels, assignees, projects | [App Store](https://apps.apple.com/us/app/github/id1477376905) |
| Sub-issues, Discussions, release reactions, widgets | [February monthly](https://github.blog/changelog/2025-02-28-mobile-monthly-februarys-general-availability-and-more/) confirms these surfaces; mentions an iOS PR widget |
| Review, merge, file/code browse, discover/trending | [App Store](https://apps.apple.com/us/app/github/id1477376905) |
| Repository code search and PR file editing | [Mobile guide](https://docs.github.com/en/get-started/using-github/github-mobile) |
| Copilot chat, task creation and agent tracking | [Agent launch](https://github.blog/changelog/2025-09-24-start-and-track-copilot-coding-agent-tasks-in-github-mobile/) |
| Native agent logs, create PR, stop session | [April 2026 update](https://github.blog/changelog/2026-04-01-github-mobile-stay-in-flow-with-a-refreshed-copilot-tab-and-native-session-logs/) |
| Agent readiness push notification | [Agent launch](https://github.blog/changelog/2025-09-24-start-and-track-copilot-coding-agent-tasks-in-github-mobile/); this does not establish an API usable by third-party clients |
| 2FA, sign-in approvals, multiple accounts | [Mobile guide](https://docs.github.com/en/get-started/using-github/github-mobile); passkey-specific approval lead not independently established |
| Actions workflow lists | Public [Actions API](https://docs.github.com/en/rest/actions/workflows) exists; the consulted Mobile overview does not establish the complete official app Actions feature set |

## Mobile website page taxonomy

These are product/page families, not an assertion that an infinite set of individual
URLs has been crawled. API coverage and web routes cover each family.

| Family | Typical route | Source |
| --- | --- | --- |
| Dashboard/feed/search/explore/trending | /dashboard, /search, /explore, /trending | [Dashboard update](https://github.blog/changelog/2026-10-01-new-dashboard-experience-now-the-default/), [search](https://docs.github.com/en/search-github) |
| Repository home/code/tree/blob/commits/branches/tags/compare | /owner/repo, /tree/ref, /blob/ref/path, /commits, /branches, /tags, /compare | [Repositories](https://docs.github.com/en/repositories) |
| Issues, PRs, reviews, checks | /issues, /pulls, /pull/N/files, /pull/N/checks | [Issues](https://docs.github.com/en/issues), [PRs](https://docs.github.com/en/pull-requests) |
| Actions, runs/jobs/artifacts, environment approvals | /actions, /actions/runs/N | [Actions](https://docs.github.com/en/actions) |
| Projects, Discussions, Wiki | /projects, /discussions, /wiki | [Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects), [Discussions](https://docs.github.com/en/discussions), [Wiki](https://docs.github.com/en/communities/documenting-your-project-with-wikis) |
| Security, advisories, Dependabot/scanning | /security | [Security](https://docs.github.com/en/code-security) |
| Insights, traffic, contributors, pulse | /pulse, /graphs/contributors, /graphs/traffic | [Repository data](https://docs.github.com/en/repositories/viewing-activity-and-data-for-your-repository) |
| Repo/org/user settings; teams/members | /settings, /orgs/name/settings, /settings/profile | [Organizations](https://docs.github.com/en/organizations), [account settings](https://docs.github.com/en/account-and-profile) |
| Releases/assets, Packages | /releases, /user?tab=packages, /orgs/name/packages | [Releases](https://docs.github.com/en/repositories/releasing-projects-on-github), [Packages](https://docs.github.com/en/packages) |
| User/org profiles, stars/followers/contributions | /name, /name?tab=repositories | [Profiles](https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-github-profile) |
| Gists | gist.github.com | [Gists](https://docs.github.com/en/get-started/writing-on-github/editing-and-sharing-content-with-gists) |
| Sponsors | /sponsors | [Sponsors](https://docs.github.com/en/sponsors) |
| Codespaces | /codespaces | [Codespaces](https://docs.github.com/en/codespaces) |
| Marketplace / integrations | /marketplace | [Marketplace](https://docs.github.com/en/apps/github-marketplace) |
| Billing / plans / usage | /settings/billing | [Billing](https://docs.github.com/en/billing) |

## Feature-to-API capability map

Legend: ✅ public API for this operation; 🟡 API has material limits; 🌐 website
required; ❌ unavailable within the chosen sideload/signing constraints.
REST cost below is one primary-limit request per page/operation, unless marked.
Secondary rate-limit points normally differ for reads and writes; GraphQL cost is
query-dependent and measured with `rateLimit { cost remaining resetAt }`. Access
also requires resource roles, SSO and policy approval. Classic OAuth scopes are
listed; fine-grained PATs use endpoint-specific permissions instead.
[REST limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api),
[GraphQL limits](https://docs.github.com/en/graphql/overview/rate-limits-and-query-limits-for-the-graphql-api),
[scopes](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps).

| Feature | Endpoint / GraphQL operation | Classic scopes | Cost | Capability / qualification and source |
| --- | --- | --- | --- | --- |
| Profile/repos/search | GET /user, /user/repos, /search/repositories, /search/issues, /search/code | read:user, repo for private | 1/page; search separate bucket | ✅ [Users](https://docs.github.com/en/rest/users/users), [Search](https://docs.github.com/en/rest/search/search); code search public API has different behavior from website search |
| Contributions | viewer.contributionsCollection.contributionCalendar | read:user, repo for permitted private | GraphQL measured | ✅ [GraphQL reference](https://docs.github.com/en/graphql/reference) |
| Create repo / templates | POST /user/repos, /orgs/{org}/repos, /repos/{template_owner}/{template_repo}/generate; PATCH repo | repo | 1 per call | 🟡 Generation and standard creation are separate; initialize default branch after creation [Repo API](https://docs.github.com/en/rest/repos/repos) |
| Name availability | GET /repos/{owner}/{name} | repo | 1 | 🟡 404 can mean inaccessible, not guaranteed availability; creation is authoritative [Repo API](https://docs.github.com/en/rest/repos/repos) |
| README / code / file commits | GET/PUT/DELETE /repos/{o}/{r}/contents/{path}; GET /git/trees | repo; workflow when writing workflows | 1/page | ✅ Base64 content, expected SHA on updates; larger files limited [Contents](https://docs.github.com/en/rest/repos/contents) |
| Branches/history/compare | /branches, /commits, /compare/{basehead}, /git/refs | repo | 1/page | ✅ [Branches](https://docs.github.com/en/rest/branches), [Commits](https://docs.github.com/en/rest/commits) |
| Fork/star/watch/topics | POST /forks; /user/starred/{o}/{r}; /repos/{o}/{r}/subscription; /topics | repo | 1 | ✅ [Forks](https://docs.github.com/en/rest/repos/forks), [Activity](https://docs.github.com/en/rest/activity), [Repo API](https://docs.github.com/en/rest/repos/repos) |
| Rename/archive/transfer/delete | PATCH/DELETE repo; POST /transfer | repo, delete_repo for delete | 1 | ✅ Transfer is asynchronous and role/policy-limited [Repo API](https://docs.github.com/en/rest/repos/repos) |
| Collaborators/protection/rulesets/webhooks | /collaborators, /branches/{b}/protection, /rulesets, /hooks | repo; admin:repo_hook for dedicated hook scope | 1/page | ✅ Admin role and plan limits [Collaborators](https://docs.github.com/en/rest/collaborators), [Protection](https://docs.github.com/en/rest/branches/branch-protection), [Rules](https://docs.github.com/en/rest/repos/rules), [Hooks](https://docs.github.com/en/rest/repos/webhooks) |
| Issues/filter/comments/metadata/reactions/sub-issues | /issues, /issues/{n}/comments, /labels, /milestones, /assignees, /reactions, /sub_issues | repo | 1/page | ✅ [Issues](https://docs.github.com/en/rest/issues), [Reactions](https://docs.github.com/en/rest/reactions) |
| PR diff/reviews/inline comments/suggestions/checks/merge | /pulls/{n}/files, /reviews, /comments, /merge; /commits/{ref}/check-runs | repo | 1/page | ✅ Suggestions are review-comment Markdown; merge only if policy permits [PRs](https://docs.github.com/en/rest/pulls), [Checks](https://docs.github.com/en/rest/checks) |
| Auto-merge / merge queue | enablePullRequestAutoMerge, enqueuePullRequest / dequeuePullRequest | repo | GraphQL measured | 🟡 Queue must be enabled; policy not bypassable [Mutations](https://docs.github.com/en/graphql/reference/mutations) |
| Workflow lists/run/job/steps | /actions/workflows, /actions/runs, /actions/runs/{id}/jobs | repo | 1/page | ✅ [Workflows](https://docs.github.com/en/rest/actions/workflows), [Runs](https://docs.github.com/en/rest/actions/workflow-runs), [Jobs](https://docs.github.com/en/rest/actions/workflow-jobs) |
| Logs/live logs | /actions/jobs/{id}/logs, /actions/runs/{id}/logs | repo | 1 per poll + redirected download | 🟡 Download endpoints are not an official streaming API; incomplete jobs may return unavailable logs [Jobs](https://docs.github.com/en/rest/actions/workflow-jobs) |
| Rerun/failed/cancel/force-cancel | POST /actions/runs/{id}/rerun, /rerun-failed-jobs, /cancel, /force-cancel | repo | 1 | ✅ [Runs](https://docs.github.com/en/rest/actions/workflow-runs) |
| Typed dispatch | POST /actions/workflows/{id}/dispatches; read YAML contents | repo, workflow for edits | 1 + definition read | 🟡 API takes input values; UI derives types from YAML, defaults may require web for complex YAML [Workflows](https://docs.github.com/en/rest/actions/workflows) |
| Artifacts/caches | /actions/runs/{id}/artifacts, /actions/artifacts/{id}/zip; /actions/caches | repo | 1/page + download | ✅ [Artifacts](https://docs.github.com/en/rest/actions/artifacts), [Cache](https://docs.github.com/en/rest/actions/cache) |
| Repo/env/org secrets | /actions/secrets; /environments/{env}/secrets; /orgs/{org}/actions/secrets and /public-key | repo; admin:org for org | 1/page; encrypt then PUT | ✅ Metadata only; values never readable. Libsodium sealed box required [Secrets](https://docs.github.com/en/rest/actions/secrets) |
| Repo/env/org variables | /actions/variables; /environments/{env}/variables; /orgs/{org}/actions/variables | repo; admin:org for org | 1/page | ✅ [Variables](https://docs.github.com/en/rest/actions/variables) |
| Environments/deployment approvals | /environments; /actions/runs/{id}/pending_deployments | repo | 1/page | ✅ Reviewer/policy restrictions [Environments](https://docs.github.com/en/rest/deployments/environments), [Runs](https://docs.github.com/en/rest/actions/workflow-runs) |
| Self-hosted runners/status/labels/remove/registration | repo/org /actions/runners, /labels, /registration-token | repo; admin:org for org | 1/page | ✅ Registration tokens expire; actual host installation stays outside iOS [Runners](https://docs.github.com/en/rest/actions/self-hosted-runners) |
| Runner groups | /orgs/{org}/actions/runner-groups | admin:org | 1/page | ✅ Organization role/plan apply [Groups](https://docs.github.com/en/rest/actions/self-hosted-runner-groups) |
| Actions settings/permissions/usage | /actions/permissions; /settings/billing/usage and supported billing resources | repo; admin:org/user scopes as endpoint requires | 1 | 🟡 Usage endpoints change with billing platform; website always available [Permissions](https://docs.github.com/en/rest/actions/permissions), [Billing](https://docs.github.com/en/rest/billing) |
| Notification filters/read/done/subscribe/mute | /notifications, /notifications/threads/{id}, /subscription | notifications or repo | 1/page/poll | ✅ Honor X-Poll-Interval and Last-Modified; 304 handling [Notifications](https://docs.github.com/en/rest/activity/notifications) |
| Releases/assets | /repos/{o}/{r}/releases and assets | repo | 1/page/upload | ✅ Asset uploads use uploads.github.com [Releases](https://docs.github.com/en/rest/releases) |
| Packages list/delete/restore | /user/packages, /orgs/{org}/packages, package/version paths | read:packages, write:packages, delete:packages | 1/page | 🟡 Package publishing uses registry protocols, not a generic REST upload [Packages](https://docs.github.com/en/rest/packages/packages) |
| Projects v2 | projectsV2, projectV2, add/update/deleteProjectV2* mutations | read:project / project | GraphQL measured | ✅ GraphQL; custom-field types need distinct mutations [Project guide](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects) |
| Discussions | repository.discussions; createDiscussion/addDiscussionComment/updateDiscussion | repo | GraphQL measured | ✅ [Discussion guide](https://docs.github.com/en/graphql/guides/using-the-graphql-api-for-discussions) |
| Gists/comments/stars/forks | /gists, /gists/{id}/comments, /star, /forks | gist | 1/page | ✅ [Gists](https://docs.github.com/en/rest/gists) |
| Dependabot/code/secret scanning/advisories | /dependabot/alerts, /code-scanning/alerts, /secret-scanning/alerts, /security-advisories | repo, security_events; role/plan | 1/page | ✅ [Dependabot](https://docs.github.com/en/rest/dependabot), [Code](https://docs.github.com/en/rest/code-scanning), [Secrets](https://docs.github.com/en/rest/secret-scanning), [Advisories](https://docs.github.com/en/rest/security-advisories) |
| Insights traffic/contributors/pulse | /traffic/views, /traffic/clones, /stats/contributors; issue/commit time filters | repo | 1/page; stats may 202 | 🟡 Traffic history retention/API permission limits; pulse assembled from activity [Metrics](https://docs.github.com/en/rest/metrics) |
| Orgs/teams/members | /user/orgs, /orgs/{org}/teams, /teams/{slug}/members | read:org, admin:org for writes | 1/page | ✅ [Organizations](https://docs.github.com/en/rest/orgs), [Teams](https://docs.github.com/en/rest/teams) |
| Codespaces/list/start/stop | /user/codespaces, /user/codespaces/{name}/start or /stop | codespace | 1/page | ✅ Running consumes account quota [Codespaces](https://docs.github.com/en/rest/codespaces/codespaces) |
| SSH/GPG/signing keys | /user/keys, /user/gpg_keys, /user/ssh_signing_keys | admin:public_key, admin:gpg_key, admin:ssh_signing_key for CRUD | 1/page | ✅ Public keys only; never generate private keys here [SSH](https://docs.github.com/en/rest/users/keys), [GPG](https://docs.github.com/en/rest/users/gpg-keys), [Signing](https://docs.github.com/en/rest/users/ssh-signing-keys) |
| Sponsors | GraphQL sponsorship information | read:user / applicable permission | GraphQL measured | 🟡 Read data where permitted; payments/onboarding 🌐 [Sponsors API](https://docs.github.com/en/sponsors/integrating-with-github-sponsors) |
| Token management | OAuth authorization revocation endpoints require app client secret; PAT creation UI | n/a | n/a | 🌐 This public client cannot create/manage arbitrary PATs [Authorizations](https://docs.github.com/en/rest/apps/oauth-applications), [PATs](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) |
| Copilot admin/metrics | /orgs/{org}/copilot/billing, metrics endpoints | manage_billing:copilot / endpoint-specific scopes | 1/page | 🟡 Public admin endpoints do not establish public Mobile Chat/session control APIs [Copilot](https://docs.github.com/en/rest/copilot); chat and agent sessions 🌐 |
| Wiki / Marketplace / billing checkout | Matching website routes | n/a | n/a | 🌐 Wiki is a separate Git repository, not a documented Wiki REST CRUD API [Wiki](https://docs.github.com/en/communities/documenting-your-project-with-wikis), [REST overview](https://docs.github.com/en/rest) |
| Mobile 2FA approval / APNs | No third-party GitHub approval API; APNs needs entitlement/provider | n/a | n/a | ❌ Within this single-target unsigned app contract [Mobile](https://docs.github.com/en/get-started/using-github/github-mobile), [APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns) |

## Authentication

[Device flow](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow)
uses POST /login/device/code followed by /login/oauth/access_token with public
client ID and device grant type. Show verification_uri and user_code. Wait at least
interval before polling; authorization_pending continues, slow_down increases the
interval, access_denied ends, expired_token/token_expired restarts. Never embed a
client secret. Device Flow must be enabled on the OAuth App.

Basic scopes: repo, workflow, gist, notifications, read:org, read:user, project,
read:packages, codespace, security_events. Optional Administration adds delete_repo,
admin:org, admin:repo_hook, write:packages, delete:packages, admin:public_key,
admin:gpg_key, admin:ssh_signing_key. These choices follow
[scope definitions](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps).
Read X-OAuth-Scopes and X-Accepted-OAuth-Scopes; a missing header on a fine-grained
token is unknown permission state, not proof of no permissions. Organization
restriction/SSO failures should explain approval requirements using
[OAuth restrictions](https://docs.github.com/en/organizations/managing-oauth-access-to-your-organizations-data/about-oauth-app-access-restrictions).

## SwiftUI and Liquid Glass

Use system controls as the primary visual layer: Apple says existing standard
controls automatically adopt the current appearance in
[adoption guidance](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).
Custom glass is for controls above content; regular and clear variants have different
legibility needs per [HIG materials](https://developer.apple.com/design/human-interface-guidelines/materials).
The [WWDC26 State of the Union](https://developer.apple.com/videos/play/wwdc2026/102/)
confirms the clear-to-tinted system slider and automatic accessibility adaptations.
The exact Settings > Appearance path from the prompt is not established by the
consulted developer sources; no app code depends on that path.

`glassEffect`, GlassEffectContainer, interactive/tinted glass, transitions, glass
buttons, backgroundExtensionEffect and tab minimization are described in
[custom glass guidance](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
and [SwiftUI updates](https://developer.apple.com/documentation/updates/swiftui).
WebView/WebPage are **iOS 26**, not newly introduced in 27, per
[browser sample](https://developer.apple.com/documentation/webkit/building-a-cross-platform-web-browser).
Reorderable containers and toolbar visibility priority/overflow are 27 additions;
State lazy class initialization is a compiler/API migration described in
[SwiftUI updates](https://developer.apple.com/documentation/updates/swiftui) and
[TN3211 announcement](https://developer.apple.com/news/site-updates/?id=06082026c).
Do not use unverified new APIs without compiler evidence; 27-specific code requires
availability and SDK compile guards for the 26 fallback.

Apple's [framework engineer clarification](https://developer.apple.com/forums/thread/838637)
states UIDesignRequiresCompatibility is ignored when built using Xcode 27 SDKs even
with a 26 deployment target. Trellis does not include this opt-out.

## KravaSign / signing

[KravaSign's public site](https://www.kravasign.com/) does not expose a sufficiently
specific contract for preservation of bundle IDs, extensions, embedded frameworks,
or entitlements in the material retrieved. The documentation host and support route
were inaccessible. Therefore the prompt's Files/direct-URL import workflow is a
user-provided operational assumption that must be checked on-device, not a verified
provider guarantee. No community assertion is elevated into a signing guarantee.

Apple's [TN2415](https://developer.apple.com/library/archive/technotes/tn2415/_index.html)
explains that signed entitlements must be compatible with the provisioning profile.
Re-signing can change application identity and capabilities. Default Keychain uses
the newly signed identity; data may not survive certificate/team/bundle-ID changes.
SwiftPM static products minimize framework signing concerns; any embedded dynamic
framework must be re-signed by the sideloader. Trellis omits APNs, App Groups, iCloud,
Associated Domains, special keychain groups, URL callback authentication and extensions.
Widgets require a [widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension),
so they remain excluded under the user's single-target-unless-confirmed constraint.
Local notifications and opportunistic [BGAppRefreshTask](https://developer.apple.com/documentation/backgroundtasks/bgapprefreshtask)
are the chosen delivery path; background scheduling is system-controlled.

## CI / packaging

[Runner README](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md)
lists Xcode 27.0 GA 27A266a with iOS/device/simulator SDK 27.0. The
[announcement](https://github.com/actions/runner-images/issues/14404) still labels
`xcode-27` preview. The latest consulted
[release](https://github.com/actions/runner-images/releases/tag/xcode-27-arm64%2F20260928.0222)
is image 20260928.0222.1. Log actual Xcode and simctl runtimes in every build; select
27.0 explicitly rather than the latest beta. Fallback
[macos-26 inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)
lists 26.6. A simulator SDK does not by itself prove a bootable runtime; CI discovers
installed runtime devices and fails clearly if none is available.

Archive through xcodebuild with signing disabled, copy Products/Applications/Trellis.app
to Payload/Trellis.app and zip. Independently inspect plist, Mach-O architecture and
archive entries; this structural check does not prove installation. Commands derive
from [xcodebuild guidance](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)
and [bundle structures](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/BundleTypes/BundleTypes.html).
No ldid pseudo-signing is necessary to produce the requested unsigned artifact and
no provider evidence establishes a benefit. Download MetalToolchain only if relevant
build diagnostics require it, per [Xcode components](https://developer.apple.com/documentation/xcode/installing-additional-simulator-runtimes).
GitHub's [runner pricing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
distinguishes free standard public-repo runners from paid larger runners; do not use
the xlarge label.

## Library selection and prior art

Versions below are deliberately pinned; true Swift 6/Xcode compatibility is validated
by CI rather than inferred solely from deployment targets.

| Purpose | Decision | License / latest default-branch commit checked |
| --- | --- | --- |
| Markdown, tables, task lists, syntax highlighting | [Textual 0.5.0](https://github.com/gonzalezreal/textual): Swift 6 manifest, iOS 18+; native attributed/structured rendering and Prism highlighting | MIT; [2026-06-15 commit](https://github.com/gonzalezreal/textual/commit/01b51875a5406eefc95f52a058cb059e7bc94dc4); task-list behavior must be visually checked |
| Actions sealed boxes | [Swift Sodium 0.11.0](https://github.com/jedisct1/swift-sodium): app-only, bundled Apple XCFramework, anonymous `box.seal` | ISC; [2026-04-09 commit](https://github.com/jedisct1/swift-sodium/commit/cfd195c76882aa9b997560ca7cb95d72fbf5db00), release 2026-05-04 |
| Standalone highlighting alternative | [Highlightr 2.3.0](https://github.com/raspu/Highlightr), not added because Textual covers code | MIT; [2026-02-13 commit](https://github.com/raspu/Highlightr/commit/da9bb2e4604da001f1d1a1adaa55f6a38509b405) |
| Diff / ANSI logs | Small original Foundation parser and SwiftUI renderer; no package needed | Project MIT; tests cover line positions and SGR sequences |
| Old MarkdownUI | [Maintenance mode](https://github.com/gonzalezreal/swift-markdown-ui); use its successor instead | MIT; intentionally not selected |
| Prior-art client | [SwiftHub](https://github.com/khoren93/SwiftHub): review navigation/API coverage, not code reuse | MIT; [2026-02-15 commit](https://github.com/khoren93/SwiftHub/commit/58d85c58f0d43e406cb78ddbca37e953e6ee0df8) |

The [Swift Windows installation guide](https://www.swift.org/install/windows/)
requires Visual Studio C++ tools and a Windows SDK as well as Swift. Winget selected
Swift 6.4.0 at execution time, superseding the prompt's 6.3.x installation lead.
