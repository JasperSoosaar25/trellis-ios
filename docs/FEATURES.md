# Implementation coverage

✅ native implementation; 🟡 partial native implementation with a reachable browser
route; 🌐 embedded browser; ❌ excluded under the API/signing contract.
These describe the beta's actual UI, not merely endpoint existence. See PROGRESS.md
for exact CI evidence. No live account mutations or on-device signing are tested by CI.
Every entry that is not ✅ states the gap explicitly.

| Milestone | Feature | Status | Implementation / limitation |
| --- | --- | --- | --- |
| M1 | Device Flow sign-in | ✅ | User code/link, interval, slow_down, expiry, cancellation; runtime client ID |
| M1 | Pasted PAT sign-in | ✅ | Verify /user and store in default-group Keychain |
| M1 | Permission visibility | ✅ | Missing normalized OAuth scopes; unknown fine-grained permissions explained |
| M1 | Organization restriction errors | ✅ | Role, OAuth approval and SSO guidance in forbidden errors |
| M1 | Native tab shell | ✅ | Five system tabs, NavigationStack, search role and minimize-on-scroll |
| M1 | Profile/contribution calendar | ✅ | REST profile plus GraphQL calendar; retry on unavailable data |
| M1 | Repository list | ✅ | Pagination, conditional/offline cache, local filtering |
| M1 | Repository/issue/user/code search | 🟡 | Native REST search; website code-search semantics and richer filters use browser |
| M1 | Multiple simultaneous accounts | 🌐 | Native beta has one active token; switch by sign-out/sign-in, browser for other sessions |
| M2 | Create repository owner/name/description/visibility | 🟡 | Personal/org picker; org permission enforced by API, availability 404 is inconclusive, internal requires enterprise |
| M2 | Template repository creation | 🟡 | Typed owner/template and branch-copy option; async template initialization and internal visibility may need browser |
| M2 | README/gitignore/license/default branch | 🟡 | All options represented; default-branch rename requires an initial commit; template files are not overwritten |
| M2 | Repository home/README | ✅ | Native metadata, Textual Markdown/tables and read-only task-state glyphs |
| M2 | Code browser and branch picker | 🟡 | Native directories/files and first 100 branches; submodules, symlinks and complete branch-management UI use web |
| M2 | File highlighting/Markdown | 🟡 | Textual code rendering; binary/large files use browser |
| M2 | Commit history/compare | 🟡 | Native history and unified file patches; rich per-commit graphs and huge compares use web |
| M2 | File create/edit/delete commits | ✅ | Base64 commits, selected branch, loaded SHA detects conflicts |
| M2 | Upload from Files | 🟡 | Native upload/commit up to 8 MiB; overwrite and larger uploads use web |
| M2 | Fork/star/watch/mute | ✅ | Native confirmed API actions |
| M2 | Topics/rename/archive/transfer/delete | ✅ | Native editors and concrete destructive confirmations; API policy may reject |
| M2 | Collaborators | 🟡 | Native list/add with permission choice; removal and invitations use settings browser |
| M2 | Branch protection | 🟡 | Native existing-policy editor; new policy and full graphical configuration use web |
| M2 | Rulesets | 🟡 | Native list/create/update/delete with structured options; full condition editor and inherited details use web |
| M2 | Webhooks | 🟡 | Native configuration CRUD; delivery inspection/redelivery use browser |
| M3 | Issues/PR filters | 🟡 | Native state, labels, assignee, milestone and sort search; unusual qualifiers use search/browser |
| M3 | Create/edit/close/reopen/lock issues | ✅ | Native form and actions |
| M3 | Labels/milestones/assignees | 🟡 | Apply metadata; create/list labels and milestones; their management and clearing milestone use web |
| M3 | Sub-issues | 🟡 | Native list/add; removal, cross-repository selection and reordering use web |
| M3 | Comments/Markdown/reactions | 🟡 | Reply/edit/delete own issue comments and add reactions; reaction removal and refreshed comment preview use browser/refresh |
| M3 | PR creation | ✅ | Head/base, title, Markdown and draft form |
| M3 | PR diff/inline review/suggestions | 🟡 | Line numbers and individual inline comments/suggestion fences; draft batch reviews, threaded replies and huge/binary patches use web |
| M3 | Review submission/request reviewers | ✅ | Comment/approve/request changes and user/team reviewer request |
| M3 | Checks | 🟡 | Native check-run records; commit statuses and complete check annotations use browser |
| M3 | Merge methods | ✅ | Merge/squash/rebase; expected head SHA and server policy enforcement |
| M3 | Auto-merge/merge queue | 🟡 | Native enable/disable/enqueue/dequeue; queue ordering/policy UI uses browser |
| M4 | Workflow list/runs/jobs/steps | ✅ | Native navigation and paged run/job lists |
| M4 | Workflow enable/disable | ✅ | Native confirmed actions |
| M4 | Logs/ANSI/search/copy/share | 🟡 | Download snapshots and 30-second polling, bounded displayed tail; no public streaming guarantee, advanced ANSI unsupported |
| M4 | Rerun all/failed/cancel/force-cancel | ✅ | Native confirmed run controls |
| M4 | Typed workflow_dispatch | 🟡 | Standard block YAML boolean/choice/number/string/environment inputs; complex YAML explicitly routed to browser |
| M4 | Artifacts download/share | ✅ | Stream to temporary disk, strip authorization on external redirects, system share sheet |
| M4 | Actions caches | ✅ | Native list/delete |
| M4 | Repo/environment/org secrets | 🟡 | Native encrypted create/update/delete and metadata; org selected-repository management uses IDs/web |
| M4 | Repo/environment/org variables | 🟡 | Native CRUD; org selected-repository management uses structured IDs/web |
| M4 | Environments/deployment approvals | 🟡 | Native environment CRUD and pending approvals with ID input; full protection/branch-policy selection uses browser |
| M4 | Self-hosted runners | 🟡 | Native status/busy/list/remove and expiring registration tokens; pagination beyond first 100 uses web |
| M4 | Runner labels/groups | 🟡 | Native labels and group configuration; repository/group membership graphical editing uses web |
| M4 | Actions/workflow permissions | 🟡 | Native common settings; selected-actions/selected-org-repository policies use web |
| M4 | Actions usage | 🟡 | Native organization usage by month on enhanced billing platform; personal Actions usage and unsupported billing plans use browser |
| M4 | Workflow YAML creation/editing | ✅ | File editor and YAML-highlighted viewer |
| M5 | Inbox/read and participation/reason filters | ✅ | Native list and filter controls; API poll interval observed |
| M5 | Mark read/done/all read | ✅ | Native thread actions and all-read confirmation |
| M5 | Subscribe/mute | ✅ | Native thread subscription actions |
| M5 | Background/local notifications | 🟡 | Opt-in BGAppRefreshTask and private count previews; iOS schedules opportunistically, not immediate delivery |
| M5 | APNs push | ❌ | No APNs entitlement/provider under the specified sideload contract |
| M6 | Releases | 🟡 | Native release CRUD/notes; binary asset upload/download and generated-notes customization use release browser |
| M6 | Packages | 🟡 | Native registry list/version/delete/package restore; publishing and version restore UI use browser |
| M6 | Projects v2 | 🟡 | Native projects/items/drafts/settings and text/number/date/single-select field updates; boards, iterations, complex fields, searching item IDs use browser |
| M6 | Discussions | 🟡 | Native list/create/read/reply and category IDs; nested replies, answers, edit/delete/reactions and beyond first 100 comments use browser |
| M6 | Gists | 🟡 | Native list/create/update/delete with file objects; comments/stars/forks and richer file editing use gist browser |
| M6 | Dependabot/code/secret alerts | 🟡 | Native list/details/update state/reason; advanced filters/locations and complete remediation UI use web |
| M6 | Security advisories | 🟡 | Native list/details; draft advisory creation/editing use web |
| M6 | Insights | 🟡 | Native traffic/clones/referrers/contributors data; pulse and charts use web; pending statistics not final data |
| M6 | Organizations/teams | 🟡 | Native repos/members/teams CRUD and Actions settings; team membership/repo management use org web pages |
| M6 | Codespaces | ✅ | Native list/start/stop/delete with quota warning on start |
| M6 | Sponsors | 🟡 | Native paged sponsorship list, status and tier; payments, changes and onboarding use browser |
| M6 | SSH/GPG/signing public keys | ✅ | Native list/add/delete; private keys never stored |
| M6 | Personal token management | 🌐 | PAT creation and arbitrary token administration need GitHub settings |
| M6 | Copilot administration | 🟡 | Native seat list; requires additional billing/admin permissions; settings link for complete controls |
| M6 | Copilot chat/agent sessions | 🌐 | No verified third-party public API matching Mobile's chat/session controls |
| M6 | Wiki | 🌐 | Separate Git repository; no Wiki REST CRUD API |
| M6 | Marketplace/billing/all settings | 🌐 | Native browser links to matching product pages |
| M7 | Home-screen widgets | ❌ | Extension re-signing not established; single-target requirement takes precedence |
| M7 | App Shortcuts | ✅ | Open Inbox or Repositories with App Intents |
| M7 | Dynamic Type/VoiceOver/system appearance | 🟡 | Standard controls, semantic diff/graph labels and no custom blur; real-device accessibility audit remains |
| M7 | iPhone 13 performance | 🟡 | 32 MiB disk/memory cache bounds, lazy diffs and 2 MiB displayed logs; no on-device memory/scroll measurements yet |
| M7 | Mobile 2FA/passkey approvals | ❌ | GitHub first-party approval flow has no verified third-party public API |

Feature totals count table rows exactly once; they are not a claim to count every
individual endpoint or website control. The initial release remains a beta.
