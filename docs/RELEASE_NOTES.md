Trellis is an unofficial native iOS client for GitHub. This initial beta includes
Device Flow/PAT authentication, repositories and code editing, issues/PR reviews,
Actions administration, inbox polling, extended REST/GraphQL resources and App Shortcuts.

Requires iOS 26 or later. `Trellis.ipa` is unsigned: import it into KravaSign and
re-sign with your certificate. Verify the accompanying SHA-256 before installation.

Read docs/FEATURES.md for exact native coverage and gaps. Advanced configuration,
Copilot chat/agent sessions, Wiki, Sponsors payments, token management and billing
have embedded web routes. Browser sign-in is separate. No APNs or widget extension.
Background notifications are opportunistic. Actual device signing/installation
and live account permissions require manual verification.

The OAuth client ID can be entered at runtime. A personal access token works without
registering an OAuth App. No client secret, provisioning profile, certificate,
user token or personal account data is bundled.
