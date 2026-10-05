# Decisions and assumptions

2026-10-05

- Name: Trellis. Original geometric branching icon; no GitHub marks.
- Deployment target iOS 26.0; use Swift 6 language mode, compatible package manifest.
- Primary runner `xcode-27`, explicitly select /Applications/Xcode_27.0.app.
  Research confirms GA 27A266a. Manual workflow supports `macos-26` fallback.
- Build only on macOS; Windows compiles/tests Foundation-only GitHubKit.
- Existing local Git credential was available; authenticated gh through its keyring.
  Credentials stay outside the repository. Git commits use a project bot identity.
- Winget's current Swift is 6.4.0, newer than the prompt's 6.3 lead. Use the current
  official toolchain and keep source in Swift 6 language mode.
- Single app target plus test targets. No widget extension until KravaSign extension
  re-signing can be established from authoritative documentation or device evidence.
- Native list/detail/editor infrastructure covers API-backed resources. Complex
  configuration surfaces receive explicit browser links and honest partial status.
- Device-flow scopes have Basic and Administration choices. Administration requests
  powerful scopes only on the user's selection; PAT permissions remain the user's
  choice. No client secret and no registered OAuth callback scheme.
- Native API and embedded browser sessions are separate. Use WebKit's persistent
  website store; never inject an API token as a browser cookie.
- Textual 0.5.0 renders Markdown and highlighted code; Sodium 0.11.0 encrypts Actions
  secrets. Both are app-only dependencies. Native diff and ANSI rendering need no library.
- Disk cache is per-account, bounded, excluded from backup, and cleared on logout.
  Destructive UI actions always require a concrete confirmation inside the app.
- Demo fixtures for UI tests and screenshots contain invented project/user names.
  They are explicitly labeled as demo and never substituted for live API responses.
- Background refresh is opportunistic, not guaranteed; observe notification polling
  headers and do not promise APNs-like delivery.
