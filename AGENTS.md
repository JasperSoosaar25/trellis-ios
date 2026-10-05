# Trellis

Read docs/PLAN.md and docs/PROGRESS.md before work and after compaction.
Current milestone: M1–M7 beta integration verified; final regressions and release validation.
Pure package: `swift test --package-path Packages/GitHubKit` (Windows/macOS).
iOS builds run only on macOS: `xcodegen generate`, then `scripts/build-ios.sh`.
Use Swift 6, strict concurrency, system SwiftUI controls, no signing secrets.
Keep tokens in the app's default Keychain group; never cache or log them.
Record actual coverage in docs/FEATURES.md; web fallbacks must be reachable.
Never claim CI green without a run URL and `gh run view` conclusion.
