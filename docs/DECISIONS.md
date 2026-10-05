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
- All API/download sessions use HTTPS; cross-host redirects remove the Authorization
  header. Downloads stream to temporary disk and are removed after sharing.
- API statistics returning 202 are shown as preparing, not as final empty data.
- Third-party licenses are bundled and accessible in Settings > Acknowledgments.
- Initial CI used a raw-string delimiter that collided with Markdown headings in
  demo JSON. Corrected the fixture delimiter; this is independent of live data.
- Markdown task lists are rendered read-only with checked/unchecked glyphs. Editors
  keep the original GFM source; code fences are excluded from glyph substitution.
- Screenshot tests add explicit demo-only dark/large-text overrides. Real sessions
  always follow system appearance and text size.
- Screenshot inspection found the status banner could cover navigation controls.
  Place it in the shell's vertical layout outside the TabView, with a UI assertion.
- Native billing reports cover supported organization products and personal Copilot;
  billing checkout and unsupported report plans use matching browser pages.
- Sponsors exposes native paged sponsorship records. Payment changes stay in browser.
- IPA verification also checks embedded Mach-O signature slots for entitlements;
  a linker-generated ad-hoc signature is compatible with subsequent re-signing.
- Enforce the cache budget on both disk restores and new writes. Apple API response
  buffers stop at 16 MiB; token responses stay in memory. Large log snapshots download
  to temporary disk and only their final 2 MiB enter the native log viewer.
- Notification baseline presence is independent of unread count. Keep recently seen
  IDs first when limiting storage, rather than retaining IDs by lexical order.
- Present comment deletion confirmation from the comment row rather than from a
  nested menu. A fixture UI test opens it and cancels without making a server write.
- Demo mode rejects REST and GraphQL mutations explicitly; it cannot report fake
  successful account changes. Tests cover both paths.
- Repository creation, file errors and comparisons have direct matching browser
  toolbar routes, keeping advanced/unsupported cases reachable.
